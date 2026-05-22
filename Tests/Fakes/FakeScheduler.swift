import Foundation
@testable import CafeUp

final class FakeScheduler: Scheduler, @unchecked Sendable {
    struct Pending {
        let duration: Duration
        let work: @Sendable () -> Void
        let handle: Handle
    }

    final class Handle: ScheduledWork, @unchecked Sendable {
        private(set) var cancelled = false
        func cancel() { cancelled = true }
    }

    private(set) var pending: [Pending] = []

    func schedule(after duration: Duration, _ work: @escaping @Sendable () -> Void) -> ScheduledWork {
        let handle = Handle()
        pending.append(.init(duration: duration, work: work, handle: handle))
        return handle
    }

    func fireAll() {
        let toFire = pending
        pending.removeAll()
        for item in toFire where !item.handle.cancelled {
            item.work()
        }
    }
}
