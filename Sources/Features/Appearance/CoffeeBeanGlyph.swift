import SwiftUI

struct CoffeeBeanGlyph: View {
    let isFilled: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let thickness = max(1, side * 0.09)
            let beanWidth = side * 0.66
            let beanHeight = side * 0.95

            Group {
                if isFilled {
                    ZStack {
                        CoffeeBeanShape()
                            .fill(Color.primary)
                        CoffeeBeanSeam()
                            .stroke(Color.primary, lineWidth: thickness * 1.1)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                } else {
                    ZStack {
                        CoffeeBeanShape()
                            .stroke(Color.primary, lineWidth: thickness)
                        CoffeeBeanSeam()
                            .stroke(Color.primary, lineWidth: thickness)
                    }
                }
            }
            .frame(width: beanWidth, height: beanHeight)
            .rotationEffect(.degrees(-18))
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct CoffeeBeanShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in p.addEllipse(in: rect) }
    }
}

private struct CoffeeBeanSeam: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let top = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.08)
            let bottom = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.08)
            let bulge = rect.width * 0.32
            path.move(to: top)
            path.addCurve(
                to: bottom,
                control1: CGPoint(x: rect.midX + bulge, y: rect.midY - rect.height * 0.18),
                control2: CGPoint(x: rect.midX - bulge, y: rect.midY + rect.height * 0.18)
            )
        }
    }
}
