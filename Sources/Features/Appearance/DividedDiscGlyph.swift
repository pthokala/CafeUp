import SwiftUI

struct DividedDiscGlyph: View {
    let orientation: DividerOrientation

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let thickness = max(1.5, side * 0.11)
            let dividerLength = side * 0.86

            ZStack {
                Circle()
                    .fill(Color.primary)
                Capsule()
                    .frame(
                        width: orientation == .vertical ? thickness : dividerLength,
                        height: orientation == .vertical ? dividerLength : thickness
                    )
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
