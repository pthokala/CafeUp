import AppKit
import SwiftUI

@MainActor
struct StatusBarMenuBuilder {
    let viewModel: MenuBarViewModel
    let updaterService: UpdaterService
    let pickApplication: () -> PickedApplication?
    let openSettings: () -> Void
    let dismissMenu: () -> Void

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if viewModel.isManualSessionActive {
            menu.addItem(activeSessionItem())
            menu.addItem(.separator())
        } else if viewModel.isTriggerActive {
            for item in triggerOnlyItems() { menu.addItem(item) }
            menu.addItem(.separator())
        }

        menu.addItem(sectionHeader("Start New Session:"))
        let sessionItems: [NSMenuItem] = [
            ClosureMenuItem(title: "Indefinitely", keyEquivalent: "i") { [viewModel] in
                viewModel.startIndefinite()
            },
            submenu(title: "Minutes", buildItems: minutePresetItems),
            submenu(title: "Hours", buildItems: hourPresetItems),
            submenu(title: "Other Time/Until", buildItems: otherTimeItems),
            submenu(title: "While App is Running", buildItems: appRunningItems),
            ClosureMenuItem(title: "While File is Downloading…", keyEquivalent: "f") { [viewModel] in
                viewModel.startWhileDownloading()
            },
        ]
        // Indented under the header, like the detail rows in the active-session panel.
        for item in sessionItems {
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())

        menu.addItem(submenu(title: "Quick Settings", buildItems: quickSettingsItems))
        menu.addItem(ClosureMenuItem(title: "Settings…", keyEquivalent: ",", handler: openSettings))

        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(title: "About CafeUp") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(checkForUpdatesItem())
        menu.addItem(submenu(title: "Feedback & Support", buildItems: feedbackItems))

        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(title: "Quit CafeUp", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })

        return menu
    }

    // MARK: - Active session (custom NSHostingView)

    private func activeSessionItem() -> NSMenuItem {
        // ⌘X is handled by StatusBarController: NSMenu ignores key equivalents on
        // view-backed items. The panel only draws the hint.
        hostedMenuItem(ActiveSessionPanel(viewModel: viewModel, onEnd: { [viewModel, dismissMenu] in
            viewModel.stop()
            dismissMenu()
        }))
    }

    private func triggerOnlyItems() -> [NSMenuItem] {
        let header = sectionHeader("Current Session Details:")
        let count = viewModel.activeTriggerCount
        let suffix = count == 1 ? "trigger" : "triggers"
        let status = disabledLine("Awake — \(count) \(suffix) active")
        let mode = disabledLine("Triggered Activation")
        return [header, status, mode]
    }

    // MARK: - Submenus

    private func submenu(title: String, buildItems: @escaping () -> [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let child = NSMenu(title: title)
        child.autoenablesItems = false
        let delegate = LazyMenuDelegate(builder: buildItems)
        child.delegate = delegate
        objc_setAssociatedObject(parent, &lazyMenuDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        for item in buildItems() { child.addItem(item) }
        parent.submenu = child
        return parent
    }

    private func minutePresetItems() -> [NSMenuItem] {
        presetItems(SessionPreset.minutePresetGroups)
    }

    private func hourPresetItems() -> [NSMenuItem] {
        presetItems(SessionPreset.hourPresetGroups)
    }

    /// One item per preset, with a separator between groups.
    private func presetItems(_ groups: [[SessionPreset]]) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        for (index, group) in groups.enumerated() {
            if index > 0 { items.append(.separator()) }
            for preset in group {
                items.append(ClosureMenuItem(title: preset.label) { [viewModel] in
                    viewModel.start(duration: preset.duration)
                })
            }
        }
        return items
    }

    private func otherTimeItems() -> [NSMenuItem] {
        [hostedMenuItem(OtherTimePanel(
            onStartFor: { [viewModel, dismissMenu] duration in
                viewModel.start(duration: duration)
                dismissMenu()
            },
            onStartUntil: { [viewModel, dismissMenu] end in
                viewModel.startUntil(end)
                dismissMenu()
            }
        ))]
    }

    private func appRunningItems() -> [NSMenuItem] {
        [hostedMenuItem(AppPickerPanel(
            onSelect: { [viewModel, dismissMenu] bundleIdentifier in
                viewModel.startWhileAppRunning(bundleIdentifier: bundleIdentifier)
                dismissMenu()
            },
            onChooseOther: { [viewModel, pickApplication, dismissMenu] in
                dismissMenu()
                // Run the open panel once the menu has finished closing.
                DispatchQueue.main.async {
                    if let picked = pickApplication() {
                        viewModel.startWhileAppRunning(bundleIdentifier: picked.bundleIdentifier)
                    }
                }
            },
            onCancel: dismissMenu
        ))]
    }

    private func quickSettingsItems() -> [NSMenuItem] {
        let target = QuickSettingsToggleTarget(viewModel: viewModel)

        let displayItem = NSMenuItem(
            title: "Allow display sleep",
            action: #selector(QuickSettingsToggleTarget.toggleAllowDisplaySleep),
            keyEquivalent: ""
        )
        displayItem.state = viewModel.policy.allowDisplaySleep ? .on : .off
        displayItem.target = target

        let lidItem = NSMenuItem(
            title: "Allow system sleep when display is closed",
            action: #selector(QuickSettingsToggleTarget.toggleAllowLidClosedSleep),
            keyEquivalent: ""
        )
        lidItem.state = viewModel.policy.allowSystemSleepWhenLidClosed ? .on : .off
        lidItem.target = target
        lidItem.toolTip = WakePolicy.lidClosedAwakeNote

        // Menu items hold their target weakly; keep it alive for as long as the items are.
        objc_setAssociatedObject(displayItem, &quickToggleTargetKey, target, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(lidItem, &quickToggleTargetKey, target, .OBJC_ASSOCIATION_RETAIN)
        return [displayItem, lidItem, disabledLine(WakePolicy.lidClosedAwakeNote)]
    }

    private func checkForUpdatesItem() -> NSMenuItem {
        let item = ClosureMenuItem(title: "Check for Updates…") { [updaterService] in
            updaterService.checkForUpdates()
        }
        item.isEnabled = updaterService.canCheckForUpdates
        return item
    }

    private func feedbackItems() -> [NSMenuItem] {
        [
            ClosureMenuItem(title: "Report an Issue") {
                if let url = URL(string: "https://github.com/pthokala/CafeUp/issues/new") {
                    NSWorkspace.shared.open(url)
                }
            },
            ClosureMenuItem(title: "Project Page") {
                if let url = URL(string: "https://github.com/pthokala/CafeUp") {
                    NSWorkspace.shared.open(url)
                }
            },
        ]
    }

    // MARK: - Helpers

    /// Custom medium-weight section header so it matches the weight of "Current Session Details:"
    /// in the active-session panel, instead of NSMenu's default small secondary-gray.
    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        let label = HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)   // matches NSMenu item inset & ActiveSessionPanel inset
        .padding(.top, 3)
        .padding(.bottom, 2)
        .frame(width: ActiveSessionPanel.width, alignment: .leading)

        let host = NSHostingView(rootView: label)
        host.translatesAutoresizingMaskIntoConstraints = true
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        item.view = host
        item.isEnabled = false
        return item
    }

    private func disabledLine(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

// MARK: - Target wrappers

@MainActor
private final class QuickSettingsToggleTarget: NSObject {
    private let viewModel: MenuBarViewModel
    init(viewModel: MenuBarViewModel) { self.viewModel = viewModel }
    @objc func toggleAllowDisplaySleep() {
        viewModel.policy.allowDisplaySleep.toggle()
    }
    @objc func toggleAllowLidClosedSleep() {
        viewModel.policy.allowSystemSleepWhenLidClosed.toggle()
    }
}

/// Rebuilds a submenu's contents each time it's about to open, so dynamic lists
/// like running applications stay fresh.
@MainActor
private final class LazyMenuDelegate: NSObject, NSMenuDelegate {
    private let builder: () -> [NSMenuItem]
    init(builder: @escaping () -> [NSMenuItem]) { self.builder = builder }
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        let boxed = NSMenuBox(menu)
        MainActor.assumeIsolated {
            let menu = boxed.menu
            menu.removeAllItems()
            for item in builder() { menu.addItem(item) }
        }
    }
}

private struct NSMenuBox: @unchecked Sendable {
    let menu: NSMenu
    init(_ menu: NSMenu) { self.menu = menu }
}

private nonisolated(unsafe) var lazyMenuDelegateKey: UInt8 = 0
private nonisolated(unsafe) var quickToggleTargetKey: UInt8 = 0
