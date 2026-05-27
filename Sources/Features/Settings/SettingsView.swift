import SwiftUI

struct SettingsView: View {
    @Bindable var menuBarViewModel: MenuBarViewModel
    @Bindable var appearanceViewModel: AppearanceViewModel
    let triggersViewModel: TriggersViewModel
    let updatesViewModel: UpdatesSectionViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(menuBarViewModel: menuBarViewModel, updatesViewModel: updatesViewModel)
                .tabItem { Label("General", systemImage: "gearshape") }
            TriggersView(viewModel: triggersViewModel)
                .tabItem { Label("Triggers", systemImage: "bolt") }
            IconPickerView(viewModel: appearanceViewModel)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var menuBarViewModel: MenuBarViewModel
    @Bindable var updatesViewModel: UpdatesSectionViewModel
    @AppStorage(SessionSoundPreferences.isEnabledKey) private var sessionSoundsEnabled: Bool = true

    var body: some View {
        Form {
            Section("Default Wake Behavior") {
                LightCheckbox(title: "Allow display sleep", isOn: Binding(
                    get: { menuBarViewModel.policy.allowDisplaySleep },
                    set: { menuBarViewModel.policy.allowDisplaySleep = $0 }
                ))
                LightCheckbox(title: "Allow system sleep when display is closed", isOn: Binding(
                    get: { menuBarViewModel.policy.allowSystemSleepWhenLidClosed },
                    set: { menuBarViewModel.policy.allowSystemSleepWhenLidClosed = $0 }
                ))
                LightCheckbox(title: "Allow screen saver after 45m of inactivity", isOn: Binding(
                    get: { menuBarViewModel.policy.allowScreenSaverAfter45Min },
                    set: { menuBarViewModel.policy.allowScreenSaverAfter45Min = $0 }
                ))
            }

            Section("Alerts") {
                LightCheckbox(title: "Play sound when a session starts or ends", isOn: $sessionSoundsEnabled)
            }

            Section("Updates") {
                LabeledContent("Version") {
                    Text("CafeUp \(updatesViewModel.currentVersionDisplay)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Last checked") {
                    Text(updatesViewModel.lastCheckedDescription)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Check for Updates Now") {
                        updatesViewModel.checkForUpdates()
                    }
                    .disabled(!updatesViewModel.canCheckForUpdates)
                }
                Text("CafeUp doesn't check for updates automatically. Use this button or the menu bar to check manually.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

/// A checkbox-style row used inside the settings Form instead of `Toggle`.
/// We use a custom view because `.formStyle(.grouped)` on macOS intercepts
/// `Toggle` and renders it with the native NSCheckbox style, ignoring any
/// custom `ToggleStyle` applied in the environment. Drawing the checkbox
/// ourselves gives us a light fill on the unchecked state that reads well
/// against the dark grouped-form background.
private struct LightCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                checkbox
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var checkbox: some View {
        ZStack {
            // Off-white (rather than pure white) so the empty checkbox reads
            // light against the dark form background without feeling harsh.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isOn ? Color.accentColor : Color(red: 0.93, green: 0.93, blue: 0.91))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(
                            isOn ? Color.clear : Color.black.opacity(0.25),
                            lineWidth: 0.5
                        )
                )
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
    }
}
