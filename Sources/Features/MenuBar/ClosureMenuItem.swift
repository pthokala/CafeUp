import AppKit

/// `NSMenuItem` that fires an arbitrary Swift closure when selected, instead of
/// requiring an `@objc` selector on a long-lived target.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(
        title: String,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = .command,
        image: NSImage? = nil,
        handler: @escaping @MainActor () -> Void
    ) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        self.keyEquivalentModifierMask = modifierMask
        self.target = self
        self.image = image
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ClosureMenuItem")
    }

    @objc private func fire() {
        handler()
    }
}
