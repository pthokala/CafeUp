import SwiftUI

/// Contents of the "Other Time/Until" submenu: keep awake *for* a number of hours and
/// minutes, or *until* a clock time (wrapping to tomorrow if it has already passed).
struct OtherTimePanel: View {
    let onStartFor: @MainActor (Duration) -> Void
    let onStartUntil: @MainActor (Date) -> Void

    private enum Mode: Hashable { case forDuration, until }

    @State private var mode = Mode.forDuration
    @State private var hours = "1"
    @State private var minutes = "0"
    @State private var endTime = Date().addingTimeInterval(60 * 60)

    /// Fixed so switching For/Until doesn't change the size of the hosting menu item,
    /// which NSMenu measures once when the submenu is built.
    static let size = CGSize(width: 156, height: 236)

    var body: some View {
        VStack(spacing: 0) {
            MenuSegmentedControl(
                segments: [(label: "For", value: Mode.forDuration), (label: "Until", value: Mode.until)],
                selection: $mode,
                fontSize: 13,
                segmentWidth: 44,
                height: 24
            )
            .padding(.top, 14)

            Spacer(minLength: 0)
            switch mode {
            case .forDuration: durationFields
            case .until: untilField
            }
            Spacer(minLength: 0)

            Button("Continue", action: start)
                .buttonStyle(MenuPushButtonStyle(prominent: true, font: .system(size: 13), height: 20))
                .frame(width: 118)
                .disabled(mode == .forDuration && durationSeconds == 0)
                .padding(.bottom, 14)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var durationFields: some View {
        VStack(spacing: 10) {
            labeledField($hours, label: "hours", maxDigits: 2)
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 96, height: 0.5)
            labeledField($minutes, label: "minutes", maxDigits: 3)
        }
    }

    private func labeledField(_ text: Binding<String>, label: String, maxDigits: Int) -> some View {
        VStack(spacing: 4) {
            MenuNumberField(text: text, width: 44, fontSize: 13, maxDigits: maxDigits)
                .onSubmit(start)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var untilField: some View {
        VStack(spacing: 8) {
            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
            Text("Tomorrow if the time\nhas already passed")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var durationSeconds: Int {
        (Int(hours) ?? 0) * 3600 + (Int(minutes) ?? 0) * 60
    }

    private func start() {
        switch mode {
        case .forDuration:
            guard durationSeconds > 0 else { return }
            onStartFor(.seconds(durationSeconds))
        case .until:
            onStartUntil(Self.nextOccurrence(of: endTime))
        }
    }

    /// `time` today if it is still ahead, otherwise the same clock time tomorrow.
    static func nextOccurrence(of time: Date, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        let today = calendar.date(
            bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: now
        ) ?? time
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
