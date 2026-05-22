import SwiftUI

@main
struct CafeUpApp: App {
    @State private var deps = CompositionRoot.makeAppDependencies()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                viewModel: deps.menuBarViewModel,
                presets: SessionPreset.standard,
                openTriggers: openTriggersWindow
            )
        } label: {
            MenuBarIcon(isActive: deps.menuBarViewModel.isActive)
        }
        .menuBarExtraStyle(.window)

        Window("Triggers", id: WindowID.triggers) {
            TriggersView(viewModel: deps.triggersViewModel)
        }
        .windowResizability(.contentSize)
    }

    private func openTriggersWindow() {
        openWindow(id: WindowID.triggers)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum WindowID {
    static let triggers = "triggers"
}
