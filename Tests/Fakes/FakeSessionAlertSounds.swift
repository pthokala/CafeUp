import Foundation
@testable import CafeUp

@MainActor
final class FakeSessionAlertSounds: SessionAlertSounds {
    private(set) var startPlayCount = 0
    private(set) var endPlayCount = 0

    func playSessionStart() { startPlayCount += 1 }
    func playSessionEnd()   { endPlayCount += 1 }
}
