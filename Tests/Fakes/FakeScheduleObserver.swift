import Foundation
@testable import CafeUp

@MainActor
final class FakeScheduleObserver: ScheduleObserver {
    private var current: Date
    private var onChange: ((Date) -> Void)?
    private(set) var isStarted = false

    init(initial: Date = Date(timeIntervalSince1970: 0)) {
        self.current = initial
    }

    func start(onChange: @escaping @MainActor (Date) -> Void) {
        isStarted = true
        self.onChange = onChange
    }

    func stop() {
        isStarted = false
        onChange = nil
    }

    func currentDate() -> Date { current }

    func emit(_ date: Date) {
        current = date
        onChange?(date)
    }
}
