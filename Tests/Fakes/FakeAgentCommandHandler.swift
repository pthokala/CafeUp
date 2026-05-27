import Foundation
@testable import CafeUp

/// Records every command dispatched to it and optionally throws a
/// preconfigured error from any throwing method (used to exercise the
/// router's handler-error path).
@MainActor
final class FakeAgentCommandHandler: AgentCommandHandler {
    private(set) var calls: [AgentCommand] = []
    var isActiveValue: Bool = false
    var errorToThrow: Error?

    var isActive: Bool { isActiveValue }

    func startIndefinite() throws {
        calls.append(.startIndefinite)
        if let errorToThrow { throw errorToThrow }
    }

    func startTimed(minutes: Int) throws {
        calls.append(.startTimed(minutes: minutes))
        if let errorToThrow { throw errorToThrow }
    }

    func stop() {
        calls.append(.stop)
    }

    func updatePolicy(_ update: PolicyUpdate) throws {
        calls.append(.updatePolicy(update))
        if let errorToThrow { throw errorToThrow }
    }
}
