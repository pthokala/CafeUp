import Foundation
@testable import CafeUp

/// Captures every snapshot the publisher tries to write so tests can
/// assert on the exact sequence.
@MainActor
final class FakeStatusWriter: StatusWriter {
    private(set) var writes: [StatusSnapshot] = []
    func write(_ snapshot: StatusSnapshot) { writes.append(snapshot) }
}
