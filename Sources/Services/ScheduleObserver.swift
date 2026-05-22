import Foundation

@MainActor
protocol ScheduleObserver: AnyObject {
    func start(onChange: @escaping @MainActor (Date) -> Void)
    func stop()
    func currentDate() -> Date
}

@MainActor
final class TimerScheduleObserver: ScheduleObserver {
    private var timer: Timer?
    private var onChange: ((Date) -> Void)?
    private let interval: TimeInterval

    init(interval: TimeInterval = 30) {
        self.interval = interval
    }

    func start(onChange: @escaping @MainActor (Date) -> Void) {
        stop()
        self.onChange = onChange
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
    }

    func currentDate() -> Date { Date() }

    private func fire() { onChange?(Date()) }
}
