import Foundation
@testable import CafeUp

@MainActor
final class FakePowerObserver: PowerObserver {
    private var current: PowerSource
    private var onChange: ((PowerSource) -> Void)?
    private(set) var isStarted = false

    init(initial: PowerSource = .unknown) {
        self.current = initial
    }

    func start(onChange: @escaping @MainActor (PowerSource) -> Void) {
        isStarted = true
        self.onChange = onChange
    }

    func stop() {
        isStarted = false
        onChange = nil
    }

    func currentPowerSource() -> PowerSource { current }

    func emit(_ source: PowerSource) {
        current = source
        onChange?(source)
    }
}
