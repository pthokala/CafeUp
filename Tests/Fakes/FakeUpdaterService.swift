import Foundation
@testable import CafeUp

@MainActor
final class FakeUpdaterService: UpdaterService {
    var canCheckForUpdates: Bool
    var currentVersionDisplay: String
    var lastUpdateCheckDate: Date?
    private(set) var checkForUpdatesCount = 0

    init(
        canCheckForUpdates: Bool = true,
        currentVersionDisplay: String = "1.0.0 (1)",
        lastUpdateCheckDate: Date? = nil
    ) {
        self.canCheckForUpdates = canCheckForUpdates
        self.currentVersionDisplay = currentVersionDisplay
        self.lastUpdateCheckDate = lastUpdateCheckDate
    }

    func checkForUpdates() {
        checkForUpdatesCount += 1
    }
}
