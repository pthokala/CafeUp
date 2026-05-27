# CafeUp

A native macOS menu-bar app that keeps your Mac awake — modeled after [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704). One click in the menu bar starts a session; the system (and optionally the display) stays awake until you tell it to stop, the timer runs out, the app you tied it to quits, or your downloads finish.

---

## Features

### Starting a session
- **Indefinitely** (⌘I) — stays on until you stop it.
- **Minutes presets** — 5, 10, 15, 20, 30, 45 min.
- **Hours presets** — 1, 2, 3, 4, 5, 6, 8, 12 h.
- **Custom Duration…** — pick any hours + minutes.
- **End at Time…** — keep awake until a specific clock time today (auto-rolls to tomorrow if the time has passed).
- **While App is Running** — pick from running apps or browse for any `.app`; CafeUp ends the session when that app terminates.
- **While File is Downloading…** (⌘F) — polls `~/Downloads` for partial files (`.download`, `.crdownload`, `.part`, `.partial`) and stays awake until they finish.

### Wake-behavior toggles (per active session)
- **Allow display sleep** — releases the display assertion so the screen can go dark.
- **Allow system sleep when display is closed** — releases the clamshell assertion, letting the Mac sleep when the lid is closed.
- **Allow screen saver after 45m of inactivity** — releases the display assertion automatically once the user has been idle ≥ 45 minutes, then reacquires it when the user returns.

### Triggers (automatic activation)
Define rules in **Settings → Triggers** that activate sessions automatically:
- **App is running** — keeps awake while a specific bundle ID is in `runningApplications`.
- **Schedule** — keeps awake on chosen weekdays within a time range.
- **On AC power** — keeps awake only when plugged in.
- **Battery ≥ N%** — keeps awake only when battery is above threshold.

Triggers combine with AND semantics; multiple active triggers use the strictest wake policy.

### Shortcuts & Siri
Two built-in App Intents, usable from the Shortcuts app, Spotlight, or Siri:
- **Start CafeUp Session** — optional duration parameter (1–1440 minutes); omit for indefinite. Phrases: *"Start a CafeUp session"*, *"Keep my Mac awake with CafeUp"*.
- **Stop CafeUp Session** — *"Stop CafeUp session"*, *"Let my Mac sleep with CafeUp"*.

### Scripting & agents

CafeUp exposes two zero-overhead surfaces so other programs (CLI scripts, AI
agents, automation tools) can control it without polling, daemons, or extra
sockets.

**URL scheme** — every command works as a `cafeup://…` URL dispatched via
`open`:

```
cafeup://start                                          # indefinite
cafeup://start?minutes=30                               # timed (1–1440)
cafeup://stop
cafeup://policy?display=true&lidClosed=false&screensaver=true
```

The app launches itself if it isn't already running. URL dispatch is
fire-and-forget and uses LaunchServices — no listening sockets, no extra
processes.

**`cafeup` CLI** — a small shell wrapper bundled inside the app. Install once:

```bash
sudo ln -sf "/Applications/CafeUp.app/Contents/Resources/cafeup" /usr/local/bin/cafeup
```

Then:

```
cafeup start [--minutes N]                  # omit --minutes for indefinite
cafeup stop
cafeup policy [--display=BOOL] [--lid-closed=BOOL] [--screensaver=BOOL]
cafeup status [--json]                      # read current state
```

`BOOL` accepts `true|false|yes|no|1|0` (case-insensitive).

**Status JSON** — CafeUp writes its current state to
`~/Library/Application Support/CafeUp/status.json` whenever the session or
policy changes (no polling, no rewrites between changes):

```json
{
  "active": true,
  "mode": "timed",
  "startedAt": "2026-05-28T10:00:00Z",
  "endsAt":    "2026-05-28T10:30:00Z",
  "policy": {
    "allowDisplaySleep": false,
    "allowSystemSleepWhenLidClosed": true,
    "allowScreenSaverAfter45Min": false
  },
  "updatedAt": "2026-05-28T10:00:00Z"
}
```

Agents compute live remaining time as `endsAt − now` themselves; the file
doesn't need a second-by-second rewrite.

### Appearance
13 menu-bar icon styles (Coffee Cup, Steaming Cup, Mug, Takeout Cup, Coffee Bean, Divided Disc, Divided Circle, Dot, Circle, Pill, Bolt, Eye, Sun). Active and idle variants render distinctly.

### Updates
CafeUp does **not** check for updates automatically. To check, either:
- Click **Check for Updates…** in the menu bar (under *About CafeUp*), or
- Open **Settings → General → Updates** and click *Check for Updates Now*.

If a new version is available, [Sparkle](https://sparkle-project.org) downloads it, verifies its EdDSA signature + Apple Developer ID, and installs it on relaunch. The current version is shown in **About CafeUp** and in the Updates section.

### Settings window (⌘,)
Three tabs: **General** (default wake behavior + updates), **Triggers** (CRUD), **Appearance** (icon picker).

---

## Build & run

Requirements: macOS 14+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/pthokala/CafeUp.git && cd CafeUp
xcodegen generate
open CafeUp.xcodeproj
# ⌘R to run, or:
xcodebuild -scheme CafeUp -configuration Debug build
```

The app installs as a menu-bar-only app (`LSUIElement: true`); look for the cup icon in your menu bar.

---

## Testing

```bash
xcodebuild -scheme CafeUp -configuration Debug test
```

180+ unit tests cover the session engine, trigger engine, view models, wake-policy persistence, downloads monitor, idle observer, and live-ticker logic. See [TESTING.md](./TESTING.md) for the per-test matrix.

---

## Architecture (one-screen overview)

```
┌──────────────────────────────────────────────────┐
│  CafeUpApp  ←  AppDelegate  ←  CompositionRoot   │  Composition
└──────────────────────────────────────────────────┘
                       │
   ┌───────────────────┼───────────────────┐
   ▼                   ▼                   ▼
┌────────────┐  ┌──────────────┐  ┌───────────────┐
│MenuBarVM   │  │TriggersVM    │  │AppearanceVM   │   ViewModels
└────────────┘  └──────────────┘  └───────────────┘
   │                   │                   │
   ▼                   ▼                   │
┌────────────┐  ┌──────────────┐           │
│SessionEng. │  │TriggerEngine │           │           Engines
└────────────┘  └──────────────┘           │
   │                   │                   │
   ▼                   ▼                   ▼
┌──────────────────────────────────────────────┐
│  IOKit assertions  ·  NSWorkspace observer   │   Services
│  Downloads monitor ·  Idle observer          │
│  Power observer    ·  Trigger store          │
└──────────────────────────────────────────────┘
```

Full layer breakdown, domain model, persistence format, and IOKit mapping in [SPECS.md](./SPECS.md).

---

## File layout

```
Sources/
  App/            CafeUpApp, AppDelegate, CompositionRoot, WindowID, intents
  Core/           SessionEngine, TriggerEngine
  Domain/         Session, Trigger, WakePolicy, WorldState, value types
  Services/       PowerAssertionService, AppActivityObserver,
                  AppLifetimeWatcher, DownloadsMonitor, UserIdleObserver,
                  ScheduleObserver, PowerObserver, TriggerStore,
                  Scheduler, Clock, Logger, IconStylePreferenceStore
  Features/
    MenuBar/      StatusBarController, MenuBarView, ActiveSessionPanel,
                  CustomDurationView, EndAtTimeView, MenuBarIcon,
                  MenuBarViewModel, SessionPresets, RemainingFormatter
    Triggers/     TriggersView, TriggerEditorView, TriggerDraft,
                  TriggersViewModel, AppPicker
    Appearance/   IconPickerView, AppearanceViewModel, glyphs
    Settings/     SettingsView
  Resources/      Info.plist, entitlements
Tests/            ~180 unit tests + fakes for every protocol service
```

---

## Releasing (maintainers)

Releases are EdDSA-signed and notarized; users get them via Sparkle.

```bash
# Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION in project.yml, then:
git tag v0.2.1 && git push origin v0.2.1
```

The `release` GitHub Actions workflow builds, signs, notarizes, staples, EdDSA-signs, uploads the zip to a GitHub Release, and commits the appcast entry to `main`. See [SPECS § 20](./SPECS.md#20-update-system) for the full release pipeline and the secrets required.

For a local release (without CI), run `scripts/release.sh 0.2.1` — same flow, single machine.

## Status

Active development. Visual parity with Amphetamine for the active-session panel and main menu is the current focus.

---

## Credits

UI and feature set inspired by [Amphetamine](https://roaringapps.com/app/amphetamine) by William Gustafson. CafeUp is an independent reimplementation, not affiliated.
