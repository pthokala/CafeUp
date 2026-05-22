import Foundation

enum SessionError: Error, Equatable {
    case assertionFailed(code: Int32)
    case alreadyActive
}
