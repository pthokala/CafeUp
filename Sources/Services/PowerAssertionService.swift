import Foundation
import IOKit
import IOKit.pwr_mgt
import os

protocol PowerAssertionService: Sendable {
    func acquire(policy: WakePolicy, reason: String) throws -> PowerAssertionToken
}

protocol PowerAssertionToken: Sendable {
    func release()
}

struct IOKitPowerAssertionService: PowerAssertionService {
    func acquire(policy: WakePolicy, reason: String) throws -> PowerAssertionToken {
        let type: CFString = switch policy {
        case .systemOnly:       kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        case .systemAndDisplay: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            throw SessionError.assertionFailed(code: result)
        }
        return IOKitToken(id: id)
    }

    private final class IOKitToken: PowerAssertionToken, @unchecked Sendable {
        private let id: IOPMAssertionID
        private let released = OSAllocatedUnfairLock(initialState: false)

        init(id: IOPMAssertionID) { self.id = id }

        func release() {
            released.withLock { wasReleased in
                guard !wasReleased else { return }
                IOPMAssertionRelease(id)
                wasReleased = true
            }
        }

        deinit { release() }
    }
}
