import AppKit
import Foundation

struct PickedApplication: Equatable {
    let displayName: String
    let bundleIdentifier: String
}

protocol AppPicker: Sendable {
    @MainActor func pickApplication() -> PickedApplication?
}

@MainActor
struct OpenPanelAppPicker: AppPicker {
    func pickApplication() -> PickedApplication? {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else { return nil }
        let displayName =
            (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return PickedApplication(displayName: displayName, bundleIdentifier: bundleId)
    }
}
