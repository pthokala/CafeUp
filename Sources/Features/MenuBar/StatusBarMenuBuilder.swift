import AppKit
import SwiftUI

@MainActor
struct StatusBarMenuBuilder {
    let viewModel: MenuBarViewModel
    let updaterService: UpdaterService
    let pickApplication: () -> PickedApplication?
    let openSettings: () -> Void
    let openCustomDuration: () -> Void
    let openEndAtTime: () -> Void

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if viewModel.isManualSessionActive {
            menu.addItem(activeSessionItem())
            // No native separator — the panel's bottom hairline serves as the boundary.
        } else if viewModel.isTriggerActive {
            for item in triggerOnlyItems() { menu.addItem(item) }
            menu.addItem(.separator())
        }

        menu.addItem(sectionHeader("Start New Session:"))
        menu.addItem(ClosureMenuItem(title: "Indefinitely", keyEquivalent: "i") { [viewModel] in
            viewModel.startIndefinite()
        })
        menu.addItem(submenu(title: "Minutes", buildItems: minutePresetItems))
        menu.addItem(submenu(title: "Hours", buildItems: hourPresetItems))
        menu.addItem(submenu(title: "Other Time/Until", buildItems: otherTimeItems))
        menu.addItem(submenu(title: "While App is Running", buildItems: appRunningItems))
        menu.addItem(ClosureMenuItem(title: "While File is Downloading…", keyEquivalent: "f") { [viewModel] in
            viewModel.startWhileDownloading()
        })

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
        let item = NSMenuItem()
        let panel = ActiveSessionPanel(viewModel: viewModel, onEnd: { [viewModel] in
            viewModel.stop()
        })
        let host = NSHostingView(rootView: panel)
        host.translatesAutoresizingMaskIntoConstraints = true
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        item.view = host
        return item
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
        SessionPreset.minutePresets.map { preset in
            ClosureMenuItem(title: preset.label) { [viewModel] in
                viewModel.start(duration: preset.duration)
            }
        }
    }

    private func hourPresetItems() -> [NSMenuItem] {
        SessionPreset.hourPresets.map { preset in
            ClosureMenuItem(title: preset.label) { [viewModel] in
                viewModel.start(duration: preset.duration)
            }
        }
    }

    private func otherTimeItems() -> [NSMenuItem] {
        [
            ClosureMenuItem(title: "Custom Duration…", handler: openCustomDuration),
            ClosureMenuItem(title: "End at Time…", handler: openEndAtTime),
        ]
    }

    private func appRunningItems() -> [NSMenuItem] {
        let apps = RunningApplicationsSnapshot.currentRegularApps()
        var items: [NSMenuItem] = []
        if apps.isEmpty {
            items.append(disabledLine("No other apps running"))
        } else {
            for entry in apps.prefix(15) {
                items.append(ClosureMenuItem(title: entry.name) { [viewModel] in
                    viewModel.startWhileAppRunning(bundleIdentifier: entry.id)
                })
            }
        }
        items.append(.separator())
        items.append(ClosureMenuItem(title: "Choose Application…") { [viewModel, pickApplication] in
            if let picked = pickApplication() {
                viewModel.startWhileAppRunning(bundleIdentifier: picked.bundleIdentifier)
            }
        })
        return items
    }

    private func quickSettingsItems() -> [NSMenuItem] {
        let item = NSMenuItem(
            title: "Allow display sleep",
            action: #selector(QuickSettingsToggleTarget.toggleAllowDisplaySleep),
            keyEquivalent: ""
        )
        item.state = viewModel.policy.allowDisplaySleep ? .on : .off
        let target = QuickSettingsToggleTarget(viewModel: viewModel)
        item.target = target
        objc_setAssociatedObject(item, &quickToggleTargetKey, target, .OBJC_ASSOCIATION_RETAIN)
        return [item]
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

    /// Custom bold section header so it matches the weight of "Current Session Details:"
    /// in the active-session panel, instead of NSMenu's default thin secondary-gray.
    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        let label = HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)   // matches NSMenu item inset & ActiveSessionPanel inset
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(width: 330, alignment: .leading)

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
