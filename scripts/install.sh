#!/usr/bin/env bash
# install.sh — install CafeUp on this Mac and wire it up for AI agents.
#
# Idempotent. Safe to re-run. Does the following, in order:
#   1. Pre-flight checks (macOS version, not running as root, deps for chosen mode).
#   2. Acquires a CafeUp.app bundle from one of three sources:
#        a) --from <path-to-.app|.zip|.dmg>     (explicit artifact)
#        b) --from-release <vX.Y.Z|latest>       (download from GitHub Releases)
#        c) repo-root auto-detect → xcodebuild   (build from source)
#   3. Validates the bundle is actually CafeUp (CFBundleIdentifier check).
#   4. Installs to /Applications (graceful stop+quit existing first, timestamped backup).
#   5. Strips Gatekeeper quarantine; runs spctl --assess (warns if ad-hoc).
#   6. Symlinks the bundled `cafeup` CLI into $PATH.
#   7. Ensures ~/AGENTS.md exists and contains a CafeUp entry.
#   8. (Opt-in) wires Claude Code's user-level CLAUDE.md to read ~/AGENTS.md.
#   9. Verifies the install end-to-end via `cafeup status --json`.
#
# Usage:
#   scripts/install.sh                          # auto (build from repo if in one)
#   scripts/install.sh --from ~/Downloads/CafeUp.zip
#   scripts/install.sh --from-release latest
#   scripts/install.sh --from-release v0.2.1 --sha256 <hex>
#   scripts/install.sh --uninstall              # reverse (keeps AGENTS.md)
#   scripts/install.sh --uninstall --purge      # reverse + strip AGENTS.md entry
#   scripts/install.sh --dry-run                # show what would happen
#   scripts/install.sh --help
#
# Exit codes:
#   0   success
#   64  usage error (EX_USAGE)
#   65  bad input / artifact (EX_DATAERR)
#   69  service unavailable (network)
#   70  internal error (EX_SOFTWARE)
#   77  permission denied (EX_NOPERM)
#   78  configuration error (e.g. macOS too old)

set -euo pipefail

# ============================================================================
# Constants
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
readonly REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

readonly APP_NAME="CafeUp"
readonly APP_BUNDLE_NAME="CafeUp.app"
readonly APPS_DIR="/Applications"
readonly APP_INSTALLED="${APPS_DIR}/${APP_BUNDLE_NAME}"

readonly CLI_NAME="cafeup"
readonly CLI_INSIDE_APP_REL="Contents/Resources/cafeup"

readonly AGENTS_FILE="${HOME}/AGENTS.md"
readonly CLAUDE_DIR="${HOME}/.claude"
readonly CLAUDE_USER_FILE="${CLAUDE_DIR}/CLAUDE.md"

readonly MIN_MACOS_MAJOR=14
readonly DEFAULT_RELEASE_OWNER="pthokala"
readonly DEFAULT_RELEASE_REPO="CafeUp"
readonly EXPECTED_BUNDLE_ID_GLOB="*CafeUp*"

# Marker used to find our entry in AGENTS.md so we don't duplicate on re-run.
readonly AGENTS_HEADING="## CafeUp"
# Marker used to find our line in CLAUDE.md.
readonly CLAUDE_REFERENCE_MARKER="See \`~/AGENTS.md\`"

# ============================================================================
# Mutable state — set by parse_args()
# ============================================================================

DRY_RUN=0
ACTION="install"           # install | uninstall
FROM_PATH=""               # explicit --from artifact
FROM_RELEASE=""            # explicit --from-release version
EXPECTED_SHA256=""         # --sha256 pin (with --from-release)
WIRE_CLAUDE=0
PURGE=0
SKIP_BUILD=0
REQUIRE_SIGNED=0           # --require-signed → fail on ad-hoc

# Set by acquire_source_bundle().
SOURCE_BUNDLE=""

# Set by cleanup paths.
WORK_DIR=""
MOUNTED_DMG_MOUNT_POINT=""

# ============================================================================
# Logging
# ============================================================================

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_DIM=''; C_BOLD=''; C_RESET=''
fi

info() { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*" >&2; }
ok()   { printf '%s ✓ %s %s\n' "$C_GREEN"  "$C_RESET" "$*" >&2; }
warn() { printf '%s!! %s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%sERR%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }
dim()  { printf '%s%s%s\n'     "$C_DIM"    "$*"       "$C_RESET" >&2; }

die() {
  # die <message> [exit_code]
  local msg="$1"
  local code="${2:-70}"
  err "$msg"
  exit "$code"
}

# ============================================================================
# Cleanup / traps
# ============================================================================

cleanup() {
  local exit_code=$?
  if [ -n "$MOUNTED_DMG_MOUNT_POINT" ] && [ -d "$MOUNTED_DMG_MOUNT_POINT" ]; then
    hdiutil detach "$MOUNTED_DMG_MOUNT_POINT" -quiet 2>/dev/null || \
      hdiutil detach "$MOUNTED_DMG_MOUNT_POINT" -force -quiet 2>/dev/null || true
  fi
  if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR" 2>/dev/null || true
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

ensure_workdir() {
  if [ -z "$WORK_DIR" ]; then
    WORK_DIR="$(mktemp -d -t cafeup-install.XXXXXXXX)"
  fi
}

# ============================================================================
# Dry-run wrappers
# ============================================================================
# Convention: anything with side-effects on the system goes through one of
# these. Read-only commands (test, grep, plutil read, etc.) run directly.

run() {
  # Run a single command, respecting DRY_RUN.
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] $*"
  else
    "$@"
  fi
}

write_file_atomic() {
  # write_file_atomic <path>   (reads stdin → atomic write to path)
  local target="$1"
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] write $target"
    cat >/dev/null
    return 0
  fi
  local dir
  dir="$(dirname "$target")"
  [ -d "$dir" ] || mkdir -p "$dir"
  local tmp
  tmp="$(mktemp "${target}.XXXXXX")"
  if ! cat >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$target"
}

append_to_file() {
  # append_to_file <path>      (reads stdin → append)
  local target="$1"
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] append to $target"
    cat >/dev/null
    return 0
  fi
  local dir
  dir="$(dirname "$target")"
  [ -d "$dir" ] || mkdir -p "$dir"
  cat >>"$target"
}

# ============================================================================
# Pre-flight
# ============================================================================

preflight_check() {
  info "Pre-flight checks…"

  # 1. Refuse to run as root. The script uses sudo only where it must (Intel
  #    /usr/local/bin symlink). Running the whole thing as root would litter
  #    root-owned files in $HOME.
  if [ "$(id -u)" = "0" ]; then
    die "Don't run this script as root. It will sudo only where strictly needed." 77
  fi

  # 2. Must be macOS.
  if [ "$(uname -s)" != "Darwin" ]; then
    die "$APP_NAME is a macOS app. This script only runs on macOS." 78
  fi

  # 3. Minimum macOS version.
  local macos_version macos_major
  macos_version="$(sw_vers -productVersion)"
  macos_major="${macos_version%%.*}"
  if [ "$macos_major" -lt "$MIN_MACOS_MAJOR" ]; then
    die "$APP_NAME needs macOS $MIN_MACOS_MAJOR or later (you have $macos_version)." 78
  fi

  # 4. Architecture sanity (informational; the binary is universal so this
  #    rarely matters in practice — but worth surfacing if it ever does).
  local arch
  arch="$(uname -m)"
  case "$arch" in
    arm64|x86_64) ;;
    *) warn "Unrecognized arch '$arch' — proceeding, but YMMV." ;;
  esac

  # 5. /Applications must be writable (this is universally true on macOS
  #    unless someone's chmod'd it, but check anyway for a useful error).
  if [ ! -w "$APPS_DIR" ]; then
    die "/Applications is not writable by $(whoami). Fix perms and re-run." 77
  fi

  ok "Pre-flight passed (macOS $macos_version, $arch)."
}

preflight_for_install_mode() {
  # Additional checks specific to the source mode chosen.
  case "$ACTION" in
    install)
      if [ -n "$FROM_PATH" ]; then
        [ -e "$FROM_PATH" ] || die "--from path does not exist: $FROM_PATH" 65
      elif [ -n "$FROM_RELEASE" ]; then
        command -v curl >/dev/null 2>&1 || die "curl is required for --from-release." 78
      elif [ -f "$REPO_ROOT/project.yml" ] && [ "$SKIP_BUILD" = "0" ]; then
        command -v xcodegen >/dev/null 2>&1 || \
          die "xcodegen not found. Install: brew install xcodegen (or pass --from)." 78
        command -v xcodebuild >/dev/null 2>&1 || \
          die "xcodebuild not found. Install Xcode (or run xcode-select --install)." 78
      else
        die "No source specified. Use --from, --from-release, or run from inside the repo." 64
      fi
      ;;
  esac
}

# ============================================================================
# Source acquisition
# ============================================================================

acquire_source_bundle() {
  # Sets SOURCE_BUNDLE to a path to a CafeUp.app directory we can install from.
  if [ -n "$FROM_PATH" ]; then
    acquire_from_path "$FROM_PATH"
  elif [ -n "$FROM_RELEASE" ]; then
    acquire_from_release "$FROM_RELEASE"
  else
    acquire_from_source_build
  fi

  [ -d "$SOURCE_BUNDLE" ] || die "Internal error: source bundle path missing after acquisition." 70
  validate_bundle "$SOURCE_BUNDLE"
}

acquire_from_path() {
  local path="$1"
  info "Using artifact: $path"

  case "$path" in
    *.app|*.app/)
      SOURCE_BUNDLE="${path%/}"
      ;;
    *.zip)
      ensure_workdir
      info "Unzipping…"
      # Acquisition I/O is tempdir-only — execute even in dry-run so the rest
      # of the pipeline has a real bundle to inspect.
      unzip -qq "$path" -d "$WORK_DIR/extracted"
      SOURCE_BUNDLE="$(find "$WORK_DIR/extracted" -maxdepth 3 -name "$APP_BUNDLE_NAME" -type d | head -1)"
      [ -n "$SOURCE_BUNDLE" ] || die "No $APP_BUNDLE_NAME found inside zip." 65
      ;;
    *.dmg)
      ensure_workdir
      info "Mounting DMG…"
      MOUNTED_DMG_MOUNT_POINT="$WORK_DIR/mnt"
      mkdir -p "$MOUNTED_DMG_MOUNT_POINT"
      hdiutil attach "$path" -mountpoint "$MOUNTED_DMG_MOUNT_POINT" -nobrowse -quiet
      local src_app
      src_app="$(find "$MOUNTED_DMG_MOUNT_POINT" -maxdepth 2 -name "$APP_BUNDLE_NAME" -type d | head -1)"
      [ -n "$src_app" ] || die "No $APP_BUNDLE_NAME found inside DMG." 65
      # Copy the app out of the DMG so we can unmount cleanly.
      mkdir -p "$WORK_DIR/extracted"
      ditto "$src_app" "$WORK_DIR/extracted/$APP_BUNDLE_NAME"
      SOURCE_BUNDLE="$WORK_DIR/extracted/$APP_BUNDLE_NAME"
      ;;
    *)
      die "Unsupported artifact type: $path (expected .app, .zip, or .dmg)." 65
      ;;
  esac
}

acquire_from_release() {
  local version="$1"
  ensure_workdir
  info "Resolving release $version from github.com/$DEFAULT_RELEASE_OWNER/$DEFAULT_RELEASE_REPO…"

  local api_url
  if [ "$version" = "latest" ]; then
    api_url="https://api.github.com/repos/$DEFAULT_RELEASE_OWNER/$DEFAULT_RELEASE_REPO/releases/latest"
  else
    api_url="https://api.github.com/repos/$DEFAULT_RELEASE_OWNER/$DEFAULT_RELEASE_REPO/releases/tags/$version"
  fi

  local meta
  meta="$(curl -fsSL --retry 3 --retry-delay 2 "$api_url" 2>/dev/null)" || \
    die "Could not reach GitHub for $version. Network down or version doesn't exist." 69

  # Find the first .zip asset's download URL. Avoids jq dependency.
  local download_url
  download_url="$(printf '%s\n' "$meta" \
    | grep -E '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+\.zip"' \
    | head -1 | sed -E 's/.*"(https:[^"]+)".*/\1/')"
  [ -n "$download_url" ] || die "No .zip asset found on release $version." 65

  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] would download: $download_url"
    dim "[dry-run] (pass --from <local-zip> for a full dry-run of the install steps)"
    exit 0
  fi

  local dl="$WORK_DIR/release.zip"
  info "Downloading $(basename "$download_url")…"
  curl -fsSL --retry 3 --retry-delay 2 -o "$dl" "$download_url" || \
    die "Download failed." 69

  if [ -n "$EXPECTED_SHA256" ]; then
    info "Verifying SHA256…"
    local actual
    actual="$(shasum -a 256 "$dl" | awk '{print $1}')"
    if [ "$actual" != "$EXPECTED_SHA256" ]; then
      die "SHA256 mismatch. expected=$EXPECTED_SHA256 actual=$actual" 65
    fi
    ok "SHA256 matches."
  else
    warn "No --sha256 provided. Skipping content-hash verification."
  fi

  # TODO(security): EdDSA-verify with the Sparkle public key once that key is
  # committed to the repo (e.g. at Sources/Resources/sparkle-ed-public.pem).
  # `sparkle verify <file> <sig>` or open-source equivalent. Until then we
  # rely on (a) HTTPS to github.com, (b) optional SHA256 pin, (c) spctl
  # --assess after install.

  acquire_from_path "$dl"
}

acquire_from_source_build() {
  info "Building $APP_NAME from source ($REPO_ROOT)…"
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] xcodegen generate; xcodebuild -scheme $APP_NAME -configuration Release"
    dim "[dry-run] (pass --from <built-.app> for a full dry-run of the install steps)"
    exit 0
  fi
  (
    cd "$REPO_ROOT"
    xcodegen generate
    xcodebuild \
      -scheme "$APP_NAME" \
      -configuration Release \
      -derivedDataPath "$REPO_ROOT/build/install-derived" \
      build >/dev/null
  ) || die "Build failed. Re-run with --from after fixing the build, or pass --skip-build." 70

  # Locate the built .app via the same DerivedData path we asked for.
  local built_app="$REPO_ROOT/build/install-derived/Build/Products/Release/$APP_BUNDLE_NAME"
  if [ ! -d "$built_app" ]; then
    # Fall back to asking xcodebuild where it put things.
    local products_dir
    products_dir="$(cd "$REPO_ROOT" && xcodebuild \
      -scheme "$APP_NAME" \
      -configuration Release \
      -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR =/ {print $2; exit}' \
      | sed 's/^ *//;s/ *$//')"
    built_app="$products_dir/$APP_BUNDLE_NAME"
  fi
  [ -d "$built_app" ] || die "Couldn't find built $APP_BUNDLE_NAME after xcodebuild." 70
  SOURCE_BUNDLE="$built_app"
  ok "Built: $SOURCE_BUNDLE"
}

validate_bundle() {
  # Defense against `--from /some/random.app`: make sure what we're about to
  # ship to /Applications actually looks like CafeUp.
  local bundle="$1"
  local plist="$bundle/Contents/Info.plist"
  [ -f "$plist" ] || die "Bundle has no Info.plist: $bundle" 65

  local bundle_id
  bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist" 2>/dev/null || echo "")"
  case "$bundle_id" in
    $EXPECTED_BUNDLE_ID_GLOB) : ;;
    *) die "Refusing to install: CFBundleIdentifier '$bundle_id' doesn't look like CafeUp." 65 ;;
  esac

  # Best-effort: make sure the CLI we're going to symlink is actually inside.
  if [ ! -e "$bundle/$CLI_INSIDE_APP_REL" ]; then
    warn "Bundle has no $CLI_INSIDE_APP_REL — CLI symlink step will be skipped."
  fi
}

# ============================================================================
# App install
# ============================================================================

stop_running_session() {
  # If the previous install left a running session, end it cleanly so we
  # don't leak IOKit assertions when we replace the binary.
  if command -v "$CLI_NAME" >/dev/null 2>&1; then
    if "$CLI_NAME" status --json 2>/dev/null | grep -q '"active"[[:space:]]*:[[:space:]]*true'; then
      info "Stopping active $APP_NAME session before reinstall…"
      run "$CLI_NAME" stop || true
    fi
  fi
}

quit_running_app() {
  # Graceful first (osascript), then a polite pkill if the app refuses.
  pgrep -xq "$APP_NAME" 2>/dev/null || return 0

  info "Quitting running $APP_NAME…"
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] osascript quit; pkill fallback if needed"
    return 0
  fi

  osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
  # Give it up to ~3 seconds to exit gracefully.
  local waited=0
  while pgrep -xq "$APP_NAME" 2>/dev/null && [ "$waited" -lt 6 ]; do
    sleep 0.5
    waited=$((waited + 1))
  done
  if pgrep -xq "$APP_NAME" 2>/dev/null; then
    warn "$APP_NAME didn't quit after osascript; sending TERM."
    pkill -TERM -x "$APP_NAME" || true
    sleep 1
  fi
  if pgrep -xq "$APP_NAME" 2>/dev/null; then
    die "$APP_NAME is still running and refuses to quit. Quit it manually and re-run." 70
  fi
}

backup_existing_app() {
  if [ -e "$APP_INSTALLED" ]; then
    local stamp suffix backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="${APP_INSTALLED}.bak-${stamp}"
    # Collision-proof: if the backup path somehow already exists (re-running
    # within the same second is unlikely but cheap to guard against), append
    # a counter.
    suffix=2
    while [ -e "$backup" ]; do
      backup="${APP_INSTALLED}.bak-${stamp}-${suffix}"
      suffix=$((suffix + 1))
    done
    info "Backing up existing install → $backup"
    run mv "$APP_INSTALLED" "$backup"
  fi
}

copy_app() {
  info "Installing → $APP_INSTALLED"
  # ditto preserves extended attributes (code signature, quarantine, etc.)
  # better than cp -R.
  run ditto "$SOURCE_BUNDLE" "$APP_INSTALLED"
}

clear_quarantine() {
  # Strip the quarantine xattr so Gatekeeper doesn't prompt on first launch.
  # Only meaningful if the .app came from a download; safe no-op otherwise.
  if xattr -p com.apple.quarantine "$APP_INSTALLED" >/dev/null 2>&1; then
    info "Clearing Gatekeeper quarantine attribute…"
    run xattr -dr com.apple.quarantine "$APP_INSTALLED"
  fi
}

verify_codesign() {
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] codesign --verify; spctl --assess"
    return 0
  fi
  if ! command -v codesign >/dev/null 2>&1; then
    warn "codesign not available — skipping signature check."
    return 0
  fi
  if codesign --verify --deep --strict "$APP_INSTALLED" 2>/dev/null; then
    ok "Code signature is valid."
  else
    warn "Code signature failed strict verification (the bundle may be ad-hoc signed)."
    if [ "$REQUIRE_SIGNED" = "1" ]; then
      die "--require-signed was passed and signature check failed." 65
    fi
  fi

  # spctl assesses Gatekeeper acceptance (Developer ID + notarization).
  if command -v spctl >/dev/null 2>&1; then
    if spctl --assess --type execute "$APP_INSTALLED" 2>/dev/null; then
      ok "Gatekeeper will accept this build."
    else
      warn "Gatekeeper will NOT accept this build (ad-hoc signed). First launch needs right-click → Open."
    fi
  fi
}

install_app() {
  stop_running_session
  quit_running_app
  backup_existing_app
  copy_app
  clear_quarantine
  verify_codesign
  ok "App installed at $APP_INSTALLED"
}

# ============================================================================
# CLI symlink
# ============================================================================

detect_path_target() {
  # Echo the directory where we should put the cafeup symlink. Considerations,
  # in priority order:
  #   1. Active Homebrew prefix (covers both /opt/homebrew and /usr/local
  #      depending on arch).
  #   2. /opt/homebrew/bin (Apple Silicon default even without `brew` on PATH).
  #   3. /usr/local/bin (Intel / system default — may need sudo).
  #   4. ~/.local/bin (no sudo ever — but may not be on PATH).
  local candidate=""

  if command -v brew >/dev/null 2>&1; then
    local brew_prefix
    brew_prefix="$(brew --prefix 2>/dev/null || true)"
    if [ -n "$brew_prefix" ] && [ -d "$brew_prefix/bin" ] && [ -w "$brew_prefix/bin" ]; then
      candidate="$brew_prefix/bin"
    fi
  fi

  if [ -z "$candidate" ] && [ -d /opt/homebrew/bin ] && [ -w /opt/homebrew/bin ]; then
    candidate="/opt/homebrew/bin"
  fi

  if [ -z "$candidate" ] && [ -d /usr/local/bin ]; then
    # /usr/local/bin may be writable (some setups) or need sudo (default).
    candidate="/usr/local/bin"
  fi

  if [ -z "$candidate" ]; then
    candidate="$HOME/.local/bin"
    [ -d "$candidate" ] || mkdir -p "$candidate"
  fi

  printf '%s\n' "$candidate"
}

install_cli_symlink() {
  local target_dir target_link source_cli
  source_cli="$APP_INSTALLED/$CLI_INSIDE_APP_REL"

  if [ ! -e "$source_cli" ]; then
    warn "CLI not present inside app bundle; skipping symlink step."
    return 0
  fi

  target_dir="$(detect_path_target)"
  target_link="$target_dir/$CLI_NAME"

  info "Installing CLI symlink → $target_link"

  # If something occupies the target, decide what to do safely.
  if [ -L "$target_link" ]; then
    local existing
    existing="$(readlink "$target_link")"
    if [ "$existing" = "$source_cli" ]; then
      ok "Symlink already correct."
      verify_cli_on_path "$target_dir"
      return 0
    fi
    info "Replacing existing symlink (was → $existing)."
    run rm -f "$target_link"
  elif [ -e "$target_link" ]; then
    die "$target_link exists and is not a symlink. Refusing to overwrite. Remove it and re-run." 77
  fi

  # The link command itself, possibly via sudo if dir isn't writable.
  if [ -w "$target_dir" ]; then
    run ln -s "$source_cli" "$target_link"
  else
    warn "Target dir $target_dir is not writable; using sudo for the symlink."
    if [ "$DRY_RUN" = "1" ]; then
      dim "[dry-run] sudo ln -s $source_cli $target_link"
    else
      sudo ln -s "$source_cli" "$target_link" || die "sudo ln failed." 77
    fi
  fi

  ok "Symlinked $CLI_NAME → $source_cli"
  verify_cli_on_path "$target_dir"
}

verify_cli_on_path() {
  local target_dir="$1"
  # If we're in dry-run we likely didn't actually create anything; skip.
  [ "$DRY_RUN" = "1" ] && return 0
  if ! command -v "$CLI_NAME" >/dev/null 2>&1; then
    warn "$target_dir is not on \$PATH. Add this to your shell rc:"
    warn "  export PATH=\"$target_dir:\$PATH\""
  fi
}

# ============================================================================
# AGENTS.md
# ============================================================================

ensure_agents_md() {
  if [ ! -e "$AGENTS_FILE" ]; then
    info "Creating $AGENTS_FILE"
    write_file_atomic "$AGENTS_FILE" <<'EOF'
# AGENTS.md

Agent-neutral context. Any AI coding agent (Claude Code, local Qwen, Codex,
Cursor, etc.) configured to read this file gets the same shared knowledge
about user-specific tools and conventions.

---
EOF
  fi
}

append_cafeup_to_agents() {
  ensure_agents_md

  # Idempotent: only append if our heading isn't already present.
  if grep -Fq "$AGENTS_HEADING" "$AGENTS_FILE" 2>/dev/null; then
    ok "AGENTS.md already lists $APP_NAME."
    return 0
  fi

  info "Appending $APP_NAME entry to $AGENTS_FILE"
  append_to_file "$AGENTS_FILE" <<'EOF'

## CafeUp
Keep Mac awake. CLI: `cafeup start --minutes N` / `cafeup stop` / `cafeup status --json`.
EOF
}

# ============================================================================
# Agent wiring (opt-in)
# ============================================================================

wire_claude_code() {
  # Idempotent: only adds the reference line if it isn't already there.
  if [ -f "$CLAUDE_USER_FILE" ] && grep -Fq "$CLAUDE_REFERENCE_MARKER" "$CLAUDE_USER_FILE"; then
    ok "Claude Code is already wired to read ~/AGENTS.md."
    return 0
  fi

  info "Wiring Claude Code → $CLAUDE_USER_FILE"
  if [ ! -e "$CLAUDE_USER_FILE" ]; then
    write_file_atomic "$CLAUDE_USER_FILE" <<'EOF'
# User-level instructions for Claude Code

See `~/AGENTS.md` for shared, agent-neutral tool context (CafeUp and any other
user-installed CLIs whose existence/usage Claude should know about without
per-project setup).
EOF
  else
    append_to_file "$CLAUDE_USER_FILE" <<'EOF'

See `~/AGENTS.md` for shared, agent-neutral tool context.
EOF
  fi
}

# ============================================================================
# Verification + summary
# ============================================================================

verify_install() {
  [ "$DRY_RUN" = "1" ] && return 0
  info "Verifying install…"
  if ! command -v "$CLI_NAME" >/dev/null 2>&1; then
    warn "Verification: \`$CLI_NAME\` is not on \$PATH yet — open a new shell or fix PATH as noted above."
    return 0
  fi
  if ! "$CLI_NAME" status --json >/dev/null 2>&1; then
    warn "Verification: \`$CLI_NAME status\` returned an error. The app may need a first launch."
    return 0
  fi
  ok "\`$CLI_NAME status --json\` succeeded."
}

print_summary() {
  local version=""
  if [ -f "$APP_INSTALLED/Contents/Info.plist" ]; then
    version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
              "$APP_INSTALLED/Contents/Info.plist" 2>/dev/null || true)"
  fi

  printf '\n%sInstalled %s%s%s\n' "$C_BOLD" "$APP_NAME" "${version:+ $version}" "$C_RESET" >&2

  if [ "$WIRE_CLAUDE" = "0" ]; then
    printf '\n%sNext (optional):%s wire your agents to read ~/AGENTS.md.\n' "$C_DIM" "$C_RESET" >&2
    printf '  Claude Code:   re-run with %s--wire-claude%s, or add to %s~/.claude/CLAUDE.md%s:\n' \
      "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET" >&2
    printf '    See `~/AGENTS.md` for shared tool context.\n' >&2
    printf '  Other agents:  point their user-level instructions file at ~/AGENTS.md the same way.\n' >&2
  fi
}

# ============================================================================
# Uninstall
# ============================================================================

uninstall_all() {
  info "Uninstalling $APP_NAME…"

  stop_running_session
  quit_running_app

  if [ -e "$APP_INSTALLED" ]; then
    info "Removing $APP_INSTALLED"
    run rm -rf "$APP_INSTALLED"
  else
    dim "$APP_INSTALLED not present."
  fi

  # Find and remove any cafeup symlink that points into a CafeUp.app.
  # Be conservative: only remove symlinks (never a real file someone else
  # might have put there).
  local search_dirs="/opt/homebrew/bin /usr/local/bin $HOME/.local/bin $HOME/bin"
  local d link tgt
  for d in $search_dirs; do
    link="$d/$CLI_NAME"
    [ -L "$link" ] || continue
    tgt="$(readlink "$link" 2>/dev/null || true)"
    case "$tgt" in
      */CafeUp.app/*)
        info "Removing CLI symlink $link"
        if [ -w "$d" ]; then
          run rm -f "$link"
        else
          if [ "$DRY_RUN" = "1" ]; then
            dim "[dry-run] sudo rm -f $link"
          else
            sudo rm -f "$link" || warn "Couldn't remove $link"
          fi
        fi
        ;;
    esac
  done

  if [ "$PURGE" = "1" ]; then
    info "--purge: stripping CafeUp entries from AGENTS.md / CLAUDE.md"
    purge_agents_md
    purge_claude_md
  else
    dim "AGENTS.md / CLAUDE.md left untouched (pass --purge to strip CafeUp references)."
  fi

  ok "Uninstall complete."
}

purge_agents_md() {
  [ -f "$AGENTS_FILE" ] || return 0
  # Remove the "## CafeUp" heading and everything until the next H2 or EOF.
  # awk pass: skip lines from the heading through the line before the next "## "
  # (but include that next line so we don't lose subsequent sections).
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] strip CafeUp section from $AGENTS_FILE"
    return 0
  fi
  local tmp
  tmp="$(mktemp "${AGENTS_FILE}.XXXXXX")"
  awk '
    BEGIN { skip = 0 }
    /^## CafeUp([[:space:]]|$)/ { skip = 1; next }
    skip && /^## / { skip = 0 }
    !skip { print }
  ' "$AGENTS_FILE" >"$tmp"
  mv "$tmp" "$AGENTS_FILE"
}

purge_claude_md() {
  [ -f "$CLAUDE_USER_FILE" ] || return 0
  if [ "$DRY_RUN" = "1" ]; then
    dim "[dry-run] strip AGENTS.md reference from $CLAUDE_USER_FILE"
    return 0
  fi
  local tmp
  tmp="$(mktemp "${CLAUDE_USER_FILE}.XXXXXX")"
  grep -vF "$CLAUDE_REFERENCE_MARKER" "$CLAUDE_USER_FILE" >"$tmp" || true
  mv "$tmp" "$CLAUDE_USER_FILE"
}

# ============================================================================
# Arg parsing
# ============================================================================

print_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Installs $APP_NAME.app into /Applications, symlinks the bundled \`$CLI_NAME\`
CLI onto \$PATH, and ensures ~/AGENTS.md lists it so AI coding agents can
discover and control it with no per-agent configuration.

Source modes (pick one, or omit and run from inside the repo to build):
  --from <path>          Install from a local .app, .zip, or .dmg.
  --from-release <ver>   Download from github.com/$DEFAULT_RELEASE_OWNER/$DEFAULT_RELEASE_REPO releases.
                         Use 'latest' or a tag like 'v0.2.1'.
  --sha256 <hex>         Pin expected SHA256 of the downloaded zip (use with --from-release).

Optional:
  --wire-claude          Also add a reference line to ~/.claude/CLAUDE.md
                         so Claude Code reads ~/AGENTS.md at session start.
  --require-signed       Fail if codesign --verify --strict fails.
  --skip-build           Don't build from source even if running from the repo.
  --dry-run              Show every action without performing it.
  --uninstall            Reverse the install (keeps AGENTS.md by default).
  --purge                With --uninstall: also strip CafeUp references from
                         ~/AGENTS.md and ~/.claude/CLAUDE.md.
  --help, -h             This help.

Examples:
  $SCRIPT_NAME                                 # build & install from this repo
  $SCRIPT_NAME --from ~/Downloads/CafeUp.zip   # install a downloaded zip
  $SCRIPT_NAME --from-release latest --wire-claude
  $SCRIPT_NAME --uninstall
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --from)            FROM_PATH="${2:-}";    [ -n "$FROM_PATH" ] || die "--from needs a value" 64;    shift 2 ;;
      --from-release)    FROM_RELEASE="${2:-}"; [ -n "$FROM_RELEASE" ] || die "--from-release needs a value" 64; shift 2 ;;
      --sha256)          EXPECTED_SHA256="${2:-}"; [ -n "$EXPECTED_SHA256" ] || die "--sha256 needs a value" 64; shift 2 ;;
      --wire-claude)     WIRE_CLAUDE=1; shift ;;
      --require-signed)  REQUIRE_SIGNED=1; shift ;;
      --skip-build)      SKIP_BUILD=1; shift ;;
      --dry-run)         DRY_RUN=1; shift ;;
      --uninstall)       ACTION="uninstall"; shift ;;
      --purge)           PURGE=1; shift ;;
      --help|-h)         print_help; exit 0 ;;
      --)                shift; break ;;
      -*)                die "Unknown option: $1 (try --help)" 64 ;;
      *)                 die "Unexpected positional arg: $1 (try --help)" 64 ;;
    esac
  done

  # Mutex: at most one source mode.
  local modes=0
  [ -n "$FROM_PATH" ]    && modes=$((modes + 1))
  [ -n "$FROM_RELEASE" ] && modes=$((modes + 1))
  if [ "$modes" -gt 1 ]; then
    die "--from and --from-release are mutually exclusive." 64
  fi

  # --sha256 only meaningful with --from-release.
  if [ -n "$EXPECTED_SHA256" ] && [ -z "$FROM_RELEASE" ]; then
    die "--sha256 only applies with --from-release." 64
  fi

  # --purge only meaningful with --uninstall.
  if [ "$PURGE" = "1" ] && [ "$ACTION" != "uninstall" ]; then
    die "--purge only applies with --uninstall." 64
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  parse_args "$@"
  preflight_check

  if [ "$ACTION" = "uninstall" ]; then
    uninstall_all
    return 0
  fi

  preflight_for_install_mode
  acquire_source_bundle
  install_app
  install_cli_symlink
  append_cafeup_to_agents
  if [ "$WIRE_CLAUDE" = "1" ]; then
    wire_claude_code
  fi
  verify_install
  print_summary
}

main "$@"
