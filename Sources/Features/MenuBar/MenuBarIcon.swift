import AppKit
import SwiftUI

struct MenuBarIcon: View {
    let style: MenuBarIconStyle
    let isActive: Bool

    var body: some View {
        Group {
            switch style.rendering(isActive: isActive) {
            case .symbol(let name):
                Image(systemName: name)
            case .dividedCircle(let orientation):
                DividedCircleGlyph(orientation: orientation)
                    .renderedAsMenuBarTemplate()
            case .coffeeBean(let isFilled):
                CoffeeBeanGlyph(isFilled: isFilled)
                    .renderedAsMenuBarTemplate()
            case .solidCircle(let isFilled):
                SolidCircleGlyph(isFilled: isFilled)
                    .renderedAsMenuBarTemplate()
            case .dividedDisc(let orientation):
                DividedDiscGlyph(orientation: orientation)
                    .renderedAsMenuBarTemplate()
            }
        }
        .accessibilityLabel(isActive ? "CafeUp active" : "CafeUp idle")
    }
}

@MainActor
private extension View {
    func renderedAsMenuBarTemplate(size: CGFloat = 18) -> Image {
        let renderer = ImageRenderer(
            content: self
                .frame(width: size, height: size)
                .foregroundStyle(Color.black)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let nsImage = renderer.nsImage else {
            return Image(systemName: "questionmark")
        }
        nsImage.isTemplate = true
        return Image(nsImage: nsImage)
    }
}
