import SwiftUI

struct SettingsView: View {
    @Bindable var menuBarViewModel: MenuBarViewModel
    @Bindable var appearanceViewModel: AppearanceViewModel
    let triggersViewModel: TriggersViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(menuBarViewModel: menuBarViewModel)
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

    var body: some View {
        Form {
            Section("Default Wake Behavior") {
                Toggle("Allow display sleep", isOn: Binding(
                    get: { menuBarViewModel.policy.allowDisplaySleep },
                    set: { menuBarViewModel.policy.allowDisplaySleep = $0 }
                ))
                Toggle("Allow system sleep when display is closed", isOn: Binding(
                    get: { menuBarViewModel.policy.allowSystemSleepWhenLidClosed },
                    set: { menuBarViewModel.policy.allowSystemSleepWhenLidClosed = $0 }
                ))
                Toggle("Allow screen saver after 45m of inactivity", isOn: Binding(
                    get: { menuBarViewModel.policy.allowScreenSaverAfter45Min },
                    set: { menuBarViewModel.policy.allowScreenSaverAfter45Min = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
