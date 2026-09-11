import SwiftUI

@main
struct CafeUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // CafeUp's windows are presented by `AuxiliaryWindows` — see there for
        // why they aren't SwiftUI `Window` scenes. An `App` still needs one
        // scene, and an empty `Settings` scene never opens on its own.
        Settings { EmptyView() }
            .commands {
                // Point ⌘, at the real Settings window instead of this empty scene.
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.showSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
