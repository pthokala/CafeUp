import Foundation
import Observation

@MainActor
@Observable
final class AppearanceViewModel {
    var iconStyle: MenuBarIconStyle {
        didSet {
            guard iconStyle != oldValue else { return }
            store.save(iconStyle)
        }
    }

    @ObservationIgnored private let store: IconStylePreferenceStore

    init(store: IconStylePreferenceStore) {
        self.store = store
        self.iconStyle = store.load()
    }
}
