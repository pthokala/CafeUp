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
                Picker("Sleep policy", selection: $menuBarViewModel.policy) {
                    Text("Keep system and display awake").tag(WakePolicy.systemAndDisplay)
                    Text("Allow display to sleep").tag(WakePolicy.systemOnly)
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
