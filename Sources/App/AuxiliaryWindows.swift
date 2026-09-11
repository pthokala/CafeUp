import AppKit
import SwiftUI

/// Presents CafeUp's standalone windows (Settings, Custom Duration, End at
/// Time) as AppKit windows hosting SwiftUI content.
///
/// These used to be SwiftUI `Window` scenes, but SwiftUI materialises the
/// first declared `Window` scene at launch — even in an `LSUIElement` app —
/// so Settings popped open on every start. Owning the windows here means
/// nothing appears until the user asks for it, and opening one no longer
/// depends on a SwiftUI `openWindow` action captured from a view that
/// happened to appear first.
@MainActor
final class AuxiliaryWindows {
    private var windows: [String: NSWindow] = [:]

    /// Brings the window for `id` to the front, creating it if it isn't open.
    ///
    /// `content` receives a `close` action for the view's own buttons. A
    /// window that was closed is rebuilt on the next `show`, so forms start
    /// from fresh state each time — as the SwiftUI scenes did.
    func show<Content: View>(
        id: String,
        title: String,
        content: (_ close: @escaping @MainActor () -> Void) -> Content
    ) {
        if let window = windows[id], window.isVisible || window.isMiniaturized {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            let close: @MainActor () -> Void = { [weak self] in self?.windows[id]?.close() }
            let window = NSWindow(contentViewController: NSHostingController(rootView: content(close)))
            window.title = title
            // We hold the only reference; a closed window is released when
            // the next `show` replaces it, never from inside `close()`.
            window.isReleasedWhenClosed = false
            window.center()
            windows[id] = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
