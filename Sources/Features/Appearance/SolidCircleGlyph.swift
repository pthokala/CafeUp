import SwiftUI

struct SolidCircleGlyph: View {
    let isFilled: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let thickness = max(1, side * 0.09)

            Group {
                if isFilled {
                    Circle()
                        .fill(Color.primary)
                } else {
                    Circle()
                        .inset(by: thickness / 2)
                        .stroke(Color.primary, lineWidth: thickness)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
