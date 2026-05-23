#!/usr/bin/env bash
# release.sh — cut a signed, notarized, EdDSA-signed release of CafeUp.
#
# Usage:
#   scripts/release.sh 0.2.1
#
# Preconditions:
#   - Clean working tree on `main`, version in project.yml matches the arg.
#   - Apple Developer ID Application certificate in your login keychain.
#   - `xcrun notarytool` keychain profile named "cafeup-notary" exists. Create with:
#       xcrun notarytool store-credentials cafeup-notary \
#         --key /path/to/AuthKey_XXXXXXXXXX.p8 \
#         --key-id XXXXXXXXXX \
#         --issuer YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY
#   - Sparkle EdDSA private key in your login keychain (set up once via `generate_keys`).
#   - `gh` CLI authenticated against the CafeUp repo.
#
# Outputs:
#   - build/CafeUp-<version>.zip (signed, notarized, stapled)
#   - An appcast `<item>` block printed to stdout, ready to paste into docs/appcast.xml
#   - A GitHub Release at v<version> with the zip attached

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version> (e.g. 0.2.1)" >&2
  exit 64
fi

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/CafeUp-$VERSION.xcarchive"
EXPORT_DIR="$BUILD_DIR/export-$VERSION"
EXPORT_OPTIONS="$BUILD_DIR/exportOptions-$VERSION.plist"
ZIP_PATH="$BUILD_DIR/CafeUp-$VERSION.zip"

# --- Preflight ---------------------------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  echo "✗ Working tree is dirty — commit or stash before releasing." >&2
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "✗ Must release from main (currently on $CURRENT_BRANCH)." >&2
  exit 1
fi

PROJECT_VERSION=$(awk '/MARKETING_VERSION:/ {gsub(/"/, "", $2); print $2}' project.yml)
if [[ "$PROJECT_VERSION" != "$VERSION" ]]; then
  echo "✗ project.yml MARKETING_VERSION is $PROJECT_VERSION but you passed $VERSION." >&2
  exit 1
fi

if ! security find-identity -p codesigning -v | grep -q "Developer ID Application"; then
  echo "✗ No 'Developer ID Application' certificate found in keychain." >&2
  echo "  Local Debug builds work without one, but releases need a real signing cert." >&2
  exit 1
fi

SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name sign_update -type f 2>/dev/null | head -1)
if [[ -z "$SIGN_UPDATE" ]]; then
  echo "✗ Sparkle's sign_update tool not found. Run 'xcodebuild -resolvePackageDependencies' first." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH"

# --- Archive -----------------------------------------------------------------

echo "→ Archiving CafeUp $VERSION…"
xcodebuild -project CafeUp.xcodeproj -scheme CafeUp -configuration Release \
  -archivePath "$ARCHIVE_PATH" archive >/dev/null

# --- Export ------------------------------------------------------------------

cat >"$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

echo "→ Exporting Developer-ID-signed .app…"
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" >/dev/null

APP_PATH="$EXPORT_DIR/CafeUp.app"

# --- Sanity-check the embedded Sparkle is still validly signed ---------------

echo "→ Verifying codesign…"
codesign --verify --strict --verbose=2 "$APP_PATH" >/dev/null
codesign --verify --strict --verbose=2 "$APP_PATH/Contents/Frameworks/Sparkle.framework" >/dev/null

# --- Archive + Notarize + Staple --------------------------------------------

echo "→ Zipping for notarization…"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "→ Submitting to Apple notary (this can take a few minutes)…"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile cafeup-notary --wait

echo "→ Stapling notarization ticket to the .app…"
xcrun stapler staple "$APP_PATH"

echo "→ Re-zipping the stapled .app for distribution…"
rm "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# --- EdDSA signature for Sparkle --------------------------------------------

echo "→ EdDSA-signing the zip with Sparkle's sign_update…"
SIGN_OUTPUT=$("$SIGN_UPDATE" "$ZIP_PATH")
ZIP_LENGTH=$(stat -f%z "$ZIP_PATH")

# --- Appcast item ------------------------------------------------------------

PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
BUILD_NUMBER=$(awk '/CURRENT_PROJECT_VERSION:/ {gsub(/"/, "", $2); print $2}' project.yml)
RELEASE_URL="https://github.com/pthokala/CafeUp/releases/download/v$VERSION/CafeUp-$VERSION.zip"

echo
echo "================ Appcast item ================"
cat <<EOF
    <item>
      <title>Version $VERSION</title>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>$PUB_DATE</pubDate>
      <description><![CDATA[
        <!-- Paste release notes (HTML) here, then commit docs/appcast.xml -->
      ]]></description>
      <enclosure url="$RELEASE_URL" length="$ZIP_LENGTH" type="application/octet-stream" $SIGN_OUTPUT/>
    </item>
EOF
echo "=============================================="
echo
echo "Paste the above into docs/appcast.xml inside the <channel>…</channel> block."
echo

# --- GitHub Release ----------------------------------------------------------

if [[ -f RELEASE_NOTES.md ]]; then
  echo "→ Creating GitHub Release v$VERSION…"
  gh release create "v$VERSION" "$ZIP_PATH" --title "CafeUp $VERSION" --notes-file RELEASE_NOTES.md
else
  echo "→ Skipping GitHub Release (no RELEASE_NOTES.md). Run manually:"
  echo "    gh release create v$VERSION $ZIP_PATH --title 'CafeUp $VERSION' --notes 'Your notes here'"
fi

echo
echo "✓ Done. Next steps:"
echo "   1. Paste the appcast <item> block into docs/appcast.xml"
echo "   2. git commit + push docs/appcast.xml"
echo "   3. Verify https://pthokala.github.io/CafeUp/appcast.xml serves the new item"
