import SwiftUI

struct EndAtTimeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let onStart: @MainActor (Date) -> Void

    @State private var endDate: Date = Date().addingTimeInterval(60 * 60)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("End at a Specific Time")
                .font(.headline)
            Text("Keep your Mac awake until this time. If the time has already passed today, it wraps to tomorrow.")
                .font(.caption)
                .foregroundStyle(.secondary)

            DatePicker(
                "End time",
                selection: $endDate,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.field)

            HStack {
                Spacer()
                Button("Cancel") { dismissWindow(id: WindowID.endAtTime) }
                    .keyboardShortcut(.cancelAction)
                Button("Start") {
                    onStart(normalizedEndDate())
                    dismissWindow(id: WindowID.endAtTime)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func normalizedEndDate() -> Date {
        let now = Date()
        if endDate > now { return endDate }
        return Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
    }
}
