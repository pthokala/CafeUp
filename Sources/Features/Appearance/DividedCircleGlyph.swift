import SwiftUI

struct DividedCircleGlyph: View {
    let orientation: DividerOrientation

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let thickness = max(1, side * 0.07)
            let inset = thickness / 2

            ZStack {
                Circle()
                    .inset(by: inset)
                    .stroke(Color.primary, lineWidth: thickness)

                divider(side: side, thickness: thickness)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    @ViewBuilder
    private func divider(side: CGFloat, thickness: CGFloat) -> some View {
        let length = side * 0.6
        Capsule()
            .fill(Color.primary)
            .frame(
                width: orientation == .vertical ? thickness : length,
                height: orientation == .vertical ? length : thickness
            )
    }
}
