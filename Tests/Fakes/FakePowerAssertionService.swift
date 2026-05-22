import Foundation
@testable import CafeUp

final class FakePowerAssertionService: PowerAssertionService, @unchecked Sendable {
    private(set) var acquireCount = 0
    private(set) var lastPolicy: WakePolicy?
    private(set) var lastIssuedToken: FakeToken?
    var failure: SessionError?

    func acquire(policy: WakePolicy, reason: String) throws -> PowerAssertionToken {
        if let failure { throw failure }
        acquireCount += 1
        lastPolicy = policy
        let token = FakeToken()
        lastIssuedToken = token
        return token
    }

    final class FakeToken: PowerAssertionToken, @unchecked Sendable {
        private(set) var released = false
        func release() { released = true }
    }
}

final class SilentLogger: AppLogger, @unchecked Sendable {
    func info(_ message: String) {}
    func error(_ message: String) {}
}
