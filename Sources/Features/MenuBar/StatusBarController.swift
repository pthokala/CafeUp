import AppKit
import SwiftUI
import Observation

/// Owns the `NSStatusItem` for CafeUp's menu bar icon, rebuilds the dropdown menu
/// on every open (so the active-session header reflects current state), and updates
/// the icon when activity state changes via SwiftUI's Observation API.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let viewModel: MenuBarViewModel
    private let appearanceViewModel: AppearanceViewModel
    private let pickApplication: () -> PickedApplication?
    private let openSettings: () -> Void
    private let openCustomDuration: () -> Void
    private let openEndAtTime: () -> Void

    private var iconHost: NSHostingView<MenuBarIcon>?

    init(
        viewModel: MenuBarViewModel,
        appearanceViewModel: AppearanceViewModel,
        pickApplication: @escaping () -> PickedApplication?,
        openSettings: @escaping () -> Void,
        openCustomDuration: @escaping () -> Void,
        openEndAtTime: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.appearanceViewModel = appearanceViewModel
        self.pickApplication = pickApplication
        self.openSettings = openSettings
        self.openCustomDuration = openCustomDuration
        self.openEndAtTime = openEndAtTime

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        installIcon()
        installMenu()
        observeIconState()
    }

    // MARK: - Icon

    private func installIcon() {
        guard let button = statusItem.button else { return }
        let host = NSHostingView(rootView: MenuBarIcon(
            style: appearanceViewModel.iconStyle,
            isActive: viewModel.isActive
        ))
        host.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            host.widthAnchor.constraint(equalToConstant: 22),
            host.heightAnchor.constraint(equalToConstant: 22),
        ])
        self.iconHost = host
    }

    /// Reinstall the icon SwiftUI root whenever `isActive` or `iconStyle` changes.
    /// Uses `withObservationTracking` to receive a single callback per change, then
    /// re-registers — the standard Observation re-arming pattern.
    private func observeIconState() {
        withObservationTracking {
            _ = viewModel.isActive
            _ = appearanceViewModel.iconStyle
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshIcon()
                self?.observeIconState()
            }
        }
    }

    private func refreshIcon() {
        iconHost?.rootView = MenuBarIcon(
            style: appearanceViewModel.iconStyle,
            isActive: viewModel.isActive
        )
    }

    // MARK: - Menu

    private func installMenu() {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        // NSMenu always dispatches delegate callbacks on the main thread, but the
        // protocol isn't `@MainActor`. Bridge once and rebuild inline.
        let unsafeMenu = NonSendableBox(menu)
        MainActor.assumeIsolated {
            let menu = unsafeMenu.value
            menu.removeAllItems()
            let builder = StatusBarMenuBuilder(
                viewModel: viewModel,
                pickApplication: pickApplication,
                openSettings: openSettings,
                openCustomDuration: openCustomDuration,
                openEndAtTime: openEndAtTime
            )
            let fresh = builder.buildMenu()
            for item in fresh.items {
                fresh.removeItem(item)
                menu.addItem(item)
            }
        }
    }
}

/// Bypass for non-Sendable types we know cross thread boundaries safely (e.g. NSMenu
/// delegate callbacks always dispatched on main).
private struct NonSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
