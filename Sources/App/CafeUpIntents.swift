import AppIntents
import Foundation

struct CafeUpShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartCafeUpSessionIntent(),
            phrases: [
                "Start a \(.applicationName) session",
                "Keep my Mac awake with \(.applicationName)"
            ],
            shortTitle: "Start session",
            systemImageName: "cup.and.saucer.fill"
        )
        AppShortcut(
            intent: StopCafeUpSessionIntent(),
            phrases: [
                "Stop \(.applicationName) session",
                "Let my Mac sleep with \(.applicationName)"
            ],
            shortTitle: "Stop session",
            systemImageName: "stop.fill"
        )
    }
}

struct StartCafeUpSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start CafeUp Session"
    static let description = IntentDescription(
        "Keep your Mac awake. Optionally specify a duration in minutes."
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Duration (minutes)",
        description: "Leave empty for an indefinite session.",
        inclusiveRange: (1, 1440)
    )
    var minutes: Int?

    @MainActor
    func perform() async throws -> some IntentResult {
        let bridge = AppIntentBridge.shared
        if let minutes {
            try bridge.startTimed(minutes: minutes)
        } else {
            try bridge.startIndefinite()
        }
        return .result()
    }
}

struct StopCafeUpSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop CafeUp Session"
    static let description = IntentDescription("Stop the current CafeUp session and let the Mac sleep normally.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentBridge.shared.stop()
        return .result()
    }
}
