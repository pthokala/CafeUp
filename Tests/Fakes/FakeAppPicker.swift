import Foundation
@testable import CafeUp

@MainActor
final class FakeAppPicker: AppPicker {
    var nextResult: PickedApplication?
    private(set) var callCount = 0

    func pickApplication() -> PickedApplication? {
        callCount += 1
        return nextResult
    }
}
