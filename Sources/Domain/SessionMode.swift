import Foundation

enum SessionMode: Sendable, Equatable {
    case indefinite
    case timed(Duration)

    var duration: Duration? {
        if case .timed(let d) = self { return d }
        return nil
    }
}
