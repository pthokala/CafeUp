import AppKit
import Observation

/// Owns the `NSStatusItem` for CafeUp's menu bar icon, rebuilds the dropdown menu
/// on every open (so the active-session header reflects current state), and updates
/// the icon when activity state changes via SwiftUI's Observation API.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let viewModel: MenuBarViewModel
    private let appearanceViewModel: AppearanceViewModel
    private let updaterService: UpdaterService
    private let pickApplication: () -> PickedApplication?
    private let openSettings: () -> Void
    private let openCustomDuration: () -> Void
    private let openEndAtTime: () -> Void

    init(
        viewModel: MenuBarViewModel,
        appearanceViewModel: AppearanceViewModel,
        updaterService: UpdaterService,
        pickApplication: @escaping () -> PickedApplication?,
        openSettings: @escaping () -> Void,
        openCustomDuration: @escaping () -> Void,
        openEndAtTime: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.appearanceViewModel = appearanceViewModel
        self.updaterService = updaterService
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

    /// Assigning a template `NSImage` to `statusItem.button?.image` is what makes
    /// macOS handle the click-state highlight correctly (inverting the icon against
    /// the selection background). A previous version of this controller embedded
    /// an `NSHostingView<MenuBarIcon>` as a button subview, which caused filled
    /// symbols to render as solid dark blobs on the highlight.
    private func installIcon() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIconImage.template(
            for: appearanceViewModel.iconStyle,
            isActive: viewModel.isActive
        )
        button.imagePosition = .imageOnly
    }

    /// Re-render the template image whenever `isActive` or `iconStyle` changes.
    /// `withObservationTracking` fires once per change; we re-register at the end.
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
        statusItem.button?.image = MenuBarIconImage.template(
            for: appearanceViewModel.iconStyle,
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
                updaterService: updaterService,
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
