import SwiftUI

struct TriggersView: View {
    @Bindable var viewModel: TriggersViewModel
    @State private var editingDraft: TriggerDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 540, minHeight: 360)
        .sheet(item: $editingDraft) { draft in
            TriggerEditorSheet(
                initial: draft,
                viewModel: viewModel,
                onDismiss: { editingDraft = nil }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Triggers").font(.title2.weight(.semibold))
            Spacer()
            Button {
                editingDraft = TriggerDraft()
            } label: {
                Label("New Trigger", systemImage: "plus")
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.triggers.isEmpty {
            ContentUnavailableView(
                "No triggers yet",
                systemImage: "bolt.slash",
                description: Text("Create a trigger to keep your Mac awake automatically when specific apps are running.")
            )
        } else {
            List {
                ForEach(viewModel.triggers) { trigger in
                    TriggerRow(
                        trigger: trigger,
                        isActive: viewModel.activeTriggerIds.contains(trigger.id),
                        onToggle: { viewModel.toggle(triggerId: trigger.id, isEnabled: $0) },
                        onEdit: { editingDraft = TriggerDraft(from: trigger) },
                        onDelete: { viewModel.remove(triggerId: trigger.id) }
                    )
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct TriggerEditorSheet: View {
    @State private var draft: TriggerDraft
    private let viewModel: TriggersViewModel
    private let onDismiss: () -> Void

    init(initial: TriggerDraft, viewModel: TriggersViewModel, onDismiss: @escaping () -> Void) {
        _draft = State(initialValue: initial)
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    var body: some View {
        TriggerEditorView(
            draft: $draft,
            pickApplication: { viewModel.pickApplication() },
            onCancel: onDismiss,
            onSave: {
                viewModel.save(draft.toTrigger())
                onDismiss()
            }
        )
    }
}

extension TriggerCondition {
    var summaryLabel: String {
        switch self {
        case .appRunning(let id):
            return "App: \(id)"
        case .schedule(let weekdays, let range):
            let days = weekdays.sorted { $0.rawValue < $1.rawValue }.map(\.shortName).joined(separator: ",")
            return "\(days) \(range.start.formatted)–\(range.end.formatted)"
        case .onACPower:
            return "AC power"
        case .batteryAtLeast(let percent):
            return "Battery ≥ \(percent)%"
        }
    }
}

private struct TriggerRow: View {
    let trigger: Trigger
    let isActive: Bool
    let onToggle: @Sendable @MainActor (Bool) -> Void
    let onEdit: @MainActor () -> Void
    let onDelete: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(trigger.name).font(.body.weight(.medium))
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enable \(trigger.name)", isOn: Binding(get: { trigger.isEnabled }, set: onToggle))
                .labelsHidden()
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    private var statusDot: some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
            .frame(width: 10, height: 10)
            .accessibilityLabel(isActive ? "Active" : "Inactive")
    }

    private var summary: String {
        let count = trigger.conditions.count
        let conditionWord = count == 1 ? "condition" : "conditions"
        let policy = trigger.policy == .systemAndDisplay ? "system + display" : "system only"
        return "\(count) \(conditionWord) · \(policy)"
    }
}

extension TriggerDraft: Identifiable {}
