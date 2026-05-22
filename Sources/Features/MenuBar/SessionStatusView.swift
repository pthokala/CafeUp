import Foundation
import SwiftUI

struct SessionStatusView: View {
    let session: Session?
    let isTriggerActive: Bool
    let activeTriggerCount: Int

    var body: some View {
        switch state {
        case .idle:
            Text("CafeUp — sleep allowed")
                .foregroundStyle(.secondary)
        case .triggerOnly:
            let word = activeTriggerCount == 1 ? "trigger" : "triggers"
            Text("Awake — \(activeTriggerCount) \(word) active")
        case .indefinite:
            Text("Awake — indefinite")
        case .timed(let endsAt):
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                Text("Awake — \(formattedRemaining(endsAt: endsAt, at: context.date)) left")
            }
        }
    }

    private enum State {
        case idle
        case triggerOnly
        case indefinite
        case timed(endsAt: Date)
    }

    private var state: State {
        if let session, let endsAt = session.endsAt {
            return .timed(endsAt: endsAt)
        }
        if session != nil { return .indefinite }
        if isTriggerActive { return .triggerOnly }
        return .idle
    }

    private func formattedRemaining(endsAt: Date, at now: Date) -> String {
        RemainingFormatter.format(secondsRemaining: secondsRemaining(endsAt: endsAt, at: now))
    }

    private func secondsRemaining(endsAt: Date, at now: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }
}
