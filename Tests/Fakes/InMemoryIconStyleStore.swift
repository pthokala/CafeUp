import Foundation
@testable import CafeUp

final class InMemoryIconStyleStore: IconStylePreferenceStore, @unchecked Sendable {
    private var stored: MenuBarIconStyle
    private(set) var saveCount = 0

    init(initial: MenuBarIconStyle = .default) {
        self.stored = initial
    }

    func load() -> MenuBarIconStyle { stored }

    func save(_ style: MenuBarIconStyle) {
        stored = style
        saveCount += 1
    }
}
