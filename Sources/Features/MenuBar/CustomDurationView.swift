import SwiftUI

struct CustomDurationView: View {
    let onStart: @MainActor (Duration) -> Void
    let onClose: @MainActor () -> Void

    @State private var hours: Int = 1
    @State private var minutes: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start a Custom Duration Session")
                .font(.headline)
            Text("Pick how long to keep your Mac awake.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Stepper(value: $hours, in: 0...24) {
                    HStack {
                        Text("Hours")
                        Spacer()
                        Text("\(hours)").monospacedDigit()
                    }
                }
                Stepper(value: $minutes, in: 0...59) {
                    HStack {
                        Text("Minutes")
                        Spacer()
                        Text("\(minutes)").monospacedDigit()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                    .keyboardShortcut(.cancelAction)
                Button("Start") {
                    let seconds = hours * 3600 + minutes * 60
                    guard seconds > 0 else { return }
                    onStart(.seconds(seconds))
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hours == 0 && minutes == 0)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}
