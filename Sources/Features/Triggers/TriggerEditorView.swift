import SwiftUI

struct TriggerEditorView: View {
    @Binding var draft: TriggerDraft
    let pickApplication: @MainActor () -> PickedApplication?
    let onCancel: @MainActor () -> Void
    let onSave: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.name.isEmpty ? "New trigger" : draft.name)
                .font(.title3.weight(.semibold))

            Form {
                TextField("Name", text: $draft.name)
                Picker("Wake policy", selection: $draft.policy) {
                    Text("System only").tag(WakePolicy.systemOnly)
                    Text("System and display").tag(WakePolicy.systemAndDisplay)
                }
                Toggle("Enabled", isOn: $draft.isEnabled)
            }
            .formStyle(.grouped)

            conditionsSection

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Conditions").font(.headline)
                Spacer()
                addConditionMenu
            }

            if draft.conditions.isEmpty {
                Text("Add at least one condition. The trigger activates when all conditions are met.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(draft.conditions.indices, id: \.self) { index in
                    ConditionRow(
                        condition: Binding(
                            get: { draft.conditions[index] },
                            set: { draft.conditions[index] = $0 }
                        ),
                        onRemove: { draft.conditions.remove(at: index) }
                    )
                }
            }
        }
    }

    private var addConditionMenu: some View {
        Menu {
            Button("App is running…") { addAppRunning() }
            Button("Schedule") { addSchedule() }
            Button("On AC power") { addOnACPower() }
            Button("Battery at least…") { addBatteryAtLeast() }
        } label: {
            Label("Add condition", systemImage: "plus")
        }
        .fixedSize()
    }

    private func addAppRunning() {
        if let app = pickApplication() {
            draft.conditions.append(.appRunning(bundleIdentifier: app.bundleIdentifier))
        }
    }

    private func addSchedule() {
        draft.conditions.append(.schedule(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            range: TimeRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 0))
        ))
    }

    private func addOnACPower() {
        draft.conditions.append(.onACPower)
    }

    private func addBatteryAtLeast() {
        draft.conditions.append(.batteryAtLeast(percent: 50))
    }
}

private struct ConditionRow: View {
    @Binding var condition: TriggerCondition
    let onRemove: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                editor
            }
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
    }

    private var iconName: String {
        switch condition {
        case .appRunning:     return "app"
        case .schedule:       return "clock"
        case .onACPower:      return "powerplug"
        case .batteryAtLeast: return "battery.75"
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch condition {
        case .appRunning(let bundleId):
            Text("App is running")
                .font(.callout.weight(.medium))
            Text(bundleId)
                .font(.caption)
                .foregroundStyle(.secondary)

        case .schedule(let weekdays, let range):
            Text("Schedule")
                .font(.callout.weight(.medium))
            ScheduleEditor(
                weekdays: weekdays,
                range: range,
                onChange: { newWeekdays, newRange in
                    condition = .schedule(weekdays: newWeekdays, range: newRange)
                }
            )

        case .onACPower:
            Text("Mac is on AC power")
                .font(.callout.weight(.medium))

        case .batteryAtLeast(let percent):
            Text("Battery at least")
                .font(.callout.weight(.medium))
            BatteryPercentEditor(
                percent: percent,
                onChange: { condition = .batteryAtLeast(percent: $0) }
            )
        }
    }
}

private struct ScheduleEditor: View {
    let weekdays: Set<Weekday>
    let range: TimeRange
    let onChange: @MainActor (Set<Weekday>, TimeRange) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Weekday.allCases) { day in
                    WeekdayToggle(
                        day: day,
                        isOn: weekdays.contains(day),
                        onTap: {
                            var next = weekdays
                            if next.contains(day) { next.remove(day) } else { next.insert(day) }
                            onChange(next, range)
                        }
                    )
                }
            }
            HStack(spacing: 8) {
                TimePicker(
                    label: "from",
                    time: range.start,
                    onChange: { onChange(weekdays, TimeRange(start: $0, end: range.end)) }
                )
                Text("to")
                    .font(.caption)
                TimePicker(
                    label: "to",
                    time: range.end,
                    onChange: { onChange(weekdays, TimeRange(start: range.start, end: $0)) }
                )
            }
            if range.isOvernight {
                Text("Range spans midnight")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WeekdayToggle: View {
    let day: Weekday
    let isOn: Bool
    let onTap: @MainActor () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(day.shortName)
                .font(.caption.weight(isOn ? .bold : .regular))
                .frame(minWidth: 32, minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.shortName)
        .accessibilityValue(isOn ? "on" : "off")
    }
}

private struct TimePicker: View {
    let label: String
    let time: TimeOfDay
    let onChange: @MainActor (TimeOfDay) -> Void

    var body: some View {
        DatePicker(
            label,
            selection: Binding(
                get: { dateRepresentation(of: time) },
                set: { onChange(TimeOfDay(date: $0)) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.compact)
    }

    private func dateRepresentation(of time: TimeOfDay) -> Date {
        let components = DateComponents(hour: time.hour, minute: time.minute)
        return Calendar.current.date(from: components) ?? Date()
    }
}

private struct BatteryPercentEditor: View {
    let percent: Int
    let onChange: @MainActor (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { Double(percent) },
                    set: { onChange(Int($0)) }
                ),
                in: 0...100,
                step: 5
            )
            .frame(maxWidth: 180)
            Text("\(percent)%")
                .font(.caption.monospacedDigit())
                .frame(width: 40, alignment: .trailing)
        }
    }
}
