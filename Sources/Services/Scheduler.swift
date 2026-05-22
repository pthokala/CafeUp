import Foundation

protocol ScheduledWork: Sendable {
    func cancel()
}

protocol Scheduler: Sendable {
    @discardableResult
    func schedule(after duration: Duration, _ work: @escaping @Sendable () -> Void) -> ScheduledWork
}

struct TaskScheduler: Scheduler {
    func schedule(after duration: Duration, _ work: @escaping @Sendable () -> Void) -> ScheduledWork {
        let task = Task {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled { work() }
        }
        return TaskHandle(task: task)
    }

    private struct TaskHandle: ScheduledWork {
        let task: Task<Void, Never>
        func cancel() { task.cancel() }
    }
}
