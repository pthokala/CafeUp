import Foundation
@testable import CafeUp

final class FakeClock: Clock, @unchecked Sendable {
    private var _now: Date
    init(_ start: Date = Date(timeIntervalSince1970: 0)) { self._now = start }
    var now: Date { _now }
    func advance(by seconds: TimeInterval) { _now = _now.addingTimeInterval(seconds) }
}
