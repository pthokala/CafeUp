import SwiftUI

struct TriggerEditorView: View {
    @Binding var draft: TriggerDraft
    let pickApplication: () -> PickedApplication?
    let onCancel: () -> Void
    let onSave: () -> Void

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
        .frame(minWidth: 480, minHeight: 360)
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Conditions").font(.headline)
                Spacer()
                Button {
                    if let app = pickApplication() {
                        draft.conditions.append(.appRunning(bundleIdentifier: app.bundleIdentifier))
                    }
                } label: {
                    Label("Add app", systemImage: "plus")
                }
            }

            if draft.conditions.isEmpty {
                Text("Add at least one condition. The trigger activates when all conditions are met.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(Array(draft.conditions.enumerated()), id: \.offset) { index, condition in
                    ConditionRow(
                        condition: condition,
                        onRemove: { draft.conditions.remove(at: index) }
                    )
                }
            }
        }
    }
}

private struct ConditionRow: View {
    let condition: TriggerCondition
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "app")
            Text(label)
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
    }

    private var label: String {
        switch condition {
        case .appRunning(let bundleId):
            return "App is running — \(bundleId)"
        }
    }
}
