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
        var typesToHold: [CFString] = []

        // Always hold "prevent user idle system sleep" so the Mac stays awake during the
        // session — that's the whole point of starting one.
        typesToHold.append(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString)

        if !policy.allowDisplaySleep {
            typesToHold.append(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString)
        }
        if !policy.allowSystemSleepWhenLidClosed {
            // PreventSystemSleep blocks deep sleep even with the lid closed (clamshell mode).
            typesToHold.append(kIOPMAssertionTypePreventSystemSleep as CFString)
        }

        var ids: [IOPMAssertionID] = []
        for type in typesToHold {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &id
            )
            guard result == kIOReturnSuccess else {
                // Release any we already grabbed before throwing.
                for prior in ids { IOPMAssertionRelease(prior) }
                throw SessionError.assertionFailed(code: result)
            }
            ids.append(id)
        }
        return IOKitToken(ids: ids)
    }

    private final class IOKitToken: PowerAssertionToken, @unchecked Sendable {
        private let ids: [IOPMAssertionID]
        private let released = OSAllocatedUnfairLock(initialState: false)

        init(ids: [IOPMAssertionID]) { self.ids = ids }

        func release() {
            released.withLock { wasReleased in
                guard !wasReleased else { return }
                for id in ids { IOPMAssertionRelease(id) }
                wasReleased = true
            }
        }

        deinit { release() }
    }
}
