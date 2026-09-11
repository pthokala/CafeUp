# CafeUp test plan

## Functionality inventory

| # | Feature | Layer | Test file | Status |
|---|---|---|---|---|
| 1 | Indefinite session start/stop | Core | `SessionEngineTests` | ✅ unit |
| 2 | Timed session start with auto-stop | Core | `SessionEngineTests` | ✅ unit |
| 3 | Session policy update preserves end date | Core | `SessionEngineTests` | ✅ unit |
| 4 | Failed reacquire preserves existing session | Core | `SessionEngineTests` | ✅ unit |
| 5 | Initial start failure surfaces error | Core | `SessionEngineTests` | ✅ unit |
| 6 | `updatePolicy` on idle engine is no-op | Core | `SessionEngineTests` | ✅ unit |
| 7 | `stop` releases assertion and cancels schedule | Core | `SessionEngineTests` | ✅ unit |
| 8 | Trigger evaluation against world state | Domain | `TriggerEvaluationTests` | ✅ unit |
| 9 | Multiple conditions require all (AND semantics) | Domain | `TriggerEvaluationTests` | ✅ unit |
| 10 | Disabled trigger is never satisfied | Domain | `TriggerEvaluationTests` | ✅ unit |
| 11 | Empty conditions = never satisfied | Domain | `TriggerEvaluationTests` | ✅ unit |
| 12 | `TriggerCondition` case-sensitive matching | Domain | `TriggerEvaluationTests` | ✅ unit |
| 13 | `TriggerCondition` Codable roundtrip | Domain | `TriggerEvaluationTests` | ✅ unit |
| 14 | Engine pulls initial snapshot on start | Core | `TriggerEngineTests` | ✅ unit |
| 15 | Identical emit doesn't reacquire | Core | `TriggerEngineTests` | ✅ unit |
| 16 | Trigger upsert persists + reevaluates | Core | `TriggerEngineTests` | ✅ unit |
| 17 | Trigger remove releases assertion | Core | `TriggerEngineTests` | ✅ unit |
| 18 | `setEnabled` toggle drives activation | Core | `TriggerEngineTests` | ✅ unit |
| 19 | Strictest policy wins with multiple active | Core | `TriggerEngineTests` | ✅ unit |
| 19a | Failed trigger assertion isn't reported active; retried on next change | Core | `TriggerEngineTests` | ✅ unit |
| 19b | Policy change acquires the new assertion before releasing the old | Core | `TriggerEngineTests` | ✅ unit |
| 20 | `UserDefaultsTriggerStore` load empty | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 21 | Save / load roundtrip | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 22 | Persistence across instances | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 23 | Save overwrites previous data | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 24 | Corrupted data returns empty, raw bytes backed up | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 24a | Unreadable entry skipped, others load, entry written back on save | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 25 | Save empty array persists empty | Services | `UserDefaultsTriggerStoreTests` | ✅ unit |
| 26 | `TriggerDraft` empty init | Features | `TriggerDraftTests` | ✅ unit |
| 27 | `TriggerDraft` init from `Trigger` | Features | `TriggerDraftTests` | ✅ unit |
| 28 | `TriggerDraft` validation (blank, whitespace, empty conditions) | Features | `TriggerDraftTests` | ✅ unit |
| 29 | `TriggerDraft` → `Trigger` roundtrip | Features | `TriggerDraftTests` | ✅ unit |
| 30 | `MenuBarViewModel.startIndefinite` | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 31 | `MenuBarViewModel.start(duration:)` | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 32 | `MenuBarViewModel.stop` | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 33 | `policy.didSet` while idle is no-op | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 34 | `policy.didSet` while active updates engine | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 35 | `policy.didSet` same-value is no-op | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 36 | Start failure captures error in `lastError` | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 37 | Successful retry clears `lastError` | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 38 | Trigger activation propagates to VM | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 39 | `isActive` OR of manual + trigger | ViewModels | `MenuBarViewModelTests` | ✅ unit |
| 40 | `TriggersViewModel.save` add | ViewModels | `TriggersViewModelTests` | ✅ unit |
| 41 | `TriggersViewModel.save` update | ViewModels | `TriggersViewModelTests` | ✅ unit |
| 42 | `TriggersViewModel.remove` | ViewModels | `TriggersViewModelTests` | ✅ unit |
| 43 | `TriggersViewModel.toggle` | ViewModels | `TriggersViewModelTests` | ✅ unit |
| 44 | `TriggersViewModel.pickApplication` | ViewModels | `TriggersViewModelTests` | ✅ unit |
| 45 | `RemainingFormatter` under-hour | Features | `RemainingFormatterTests` | ✅ unit |
| 46 | `RemainingFormatter` over-hour | Features | `RemainingFormatterTests` | ✅ unit |
| 47 | `RemainingFormatter` negative/zero clamped | Features | `RemainingFormatterTests` | ✅ unit |
| 48 | `SessionPreset.standard` durations | Features | `SessionPresetTests` | ✅ unit |
| 49 | `SessionPreset` unique labels and ids | Features | `SessionPresetTests` | ✅ unit |
| 50 | `Session` model fields | Domain | `SessionTests` | ✅ unit |
| 51 | `SessionMode.duration` accessor | Domain | `SessionTests` | ✅ unit |
| 52 | `WorldState.empty` / equality | Domain | `WorldStateTests` | ✅ unit |

## Coverage that requires manual verification

These can't be unit-tested because they depend on real system state, real Apple framework behavior, or live UI rendering. Verify by hand after non-trivial changes.

### Real IOKit power assertion
- [ ] After starting an indefinite session, run `pmset -g assertions | grep CafeUp` in Terminal. Should show an assertion with reason "CafeUp keeping Mac awake".
- [ ] Stop the session. The assertion should disappear from `pmset -g assertions`.
- [ ] Toggle "Prevent display sleep". The assertion type should switch between `PreventUserIdleSystemSleep` and `PreventUserIdleDisplaySleep`.

### Real NSWorkspace observation
- [ ] Create a trigger for an app you have installed (e.g. Safari).
- [ ] With the app running, open CafeUp. Trigger row should show a green dot.
- [ ] Quit Safari. Green dot should turn gray within ~1 second.
- [ ] Run `pmset -g assertions` while trigger active — should show assertion with reason "CafeUp trigger keeping Mac awake".

### Live timer ticking
- [ ] Choose **Minutes › 5 Minutes**, then open the menu. Under *Current Session Details:* it should read `05m 00s remaining (h:mm AM)`.
- [ ] Keep the menu open. The countdown ticks once per second: `04m 59s → 04m 58s …`.
- [ ] Close the menu and reopen it about 30 seconds later. It should read roughly `04m 30s remaining`.
- [ ] Wait until 0 — the session auto-stops and the icon switches to its idle variant.

### Persistence across launches
- [ ] Create a trigger.
- [ ] Quit CafeUp.
- [ ] Relaunch. The trigger should appear in **Settings → Triggers**.

### Menu and window behavior
- [ ] Launch CafeUp. Only the menu-bar icon appears — no window opens on launch.
- [ ] Click the menu-bar icon. The menu opens.
- [ ] Click outside the menu (or press Esc). The menu closes.
- [ ] Choose **Settings…** — the Settings window opens; its **Triggers** tab lists your triggers.
- [ ] Choose **Other Time/Until › Custom Duration…** and **End at Time…** right after a fresh launch — each opens its window.
- [ ] Click **Quit CafeUp** or press ⌘Q — app terminates.

### Cold-launch URL commands
- [ ] Quit CafeUp, then run `cafeup start --minutes 30`. CafeUp launches and the 30-minute session is running (`cafeup status` reports it).

### Console.app logs (diagnosis aid)
- [ ] Open Console.app, filter subsystem `com.pardhu.CafeUp`.
- [ ] Start a session — should see `category=session` log: `Session started: mode=… policy=… startedAt=… endsAt=…`.
- [ ] Activate a trigger — should see `category=triggers` log: `Trigger assertion acquired (systemAndDisplay)`.

## Why these aren't unit-tested

| Behavior | Why no unit test |
|---|---|
| `IOPMAssertionCreateWithName` returns success/failure | Real IOKit; mocked behind `PowerAssertionService` protocol. The protocol contract is unit-tested with `FakePowerAssertionService`. Actual kernel behavior verified manually with `pmset`. |
| `NSWorkspace` launch/terminate notifications | Real AppKit framework; mocked behind `AppActivityObserver` protocol. Live notification delivery verified manually. |
| SwiftUI rendering in `MenuBarExtra` popover | SwiftUI views are pure functions of state; testing rendering is best done via Previews and visual inspection. ViewModel state changes are unit-tested; the view trivially binds to them. |
| `TimelineView` periodic ticking | SwiftUI internal; cannot reliably observe in tests. |
| `NSOpenPanel.runModal()` blocking event loop | AppKit modal; mocked behind `AppPicker` protocol. |
| Live menu bar interaction | XCUITest support for `MenuBarExtra` is unreliable. Manual verification preferred. |

## Running the tests

```bash
cd /Users/pardhu/Projects/CafeUp
xcodebuild -project CafeUp.xcodeproj -scheme CafeUp -destination 'platform=macOS' test
```

Or in Xcode: ⌘U.
