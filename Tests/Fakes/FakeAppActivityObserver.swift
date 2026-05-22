import Foundation
@testable import CafeUp

@MainActor
final class FakeAppActivityObserver: AppActivityObserver {
    private(set) var isStarted = false
    private var onChange: ((Set<String>) -> Void)?
    private var snapshot: Set<String>

    init(initialSnapshot: Set<String> = []) {
        self.snapshot = initialSnapshot
    }

    func start(onChange: @escaping @MainActor (Set<String>) -> Void) {
        isStarted = true
        self.onChange = onChange
    }

    func stop() {
        isStarted = false
        onChange = nil
    }

    func currentSnapshot() -> Set<String> { snapshot }

    func emit(_ running: Set<String>) {
        snapshot = running
        onChange?(running)
    }
}
