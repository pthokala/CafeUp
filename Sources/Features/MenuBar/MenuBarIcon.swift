import SwiftUI

struct MenuBarIcon: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
            .accessibilityLabel(isActive ? "CafeUp active" : "CafeUp idle")
    }
}
