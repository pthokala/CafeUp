import SwiftUI

struct IconPickerView: View {
    @Bindable var viewModel: AppearanceViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu bar icon")
                .font(.headline)
            Text("Click an option to apply. Both active and idle variants are shown.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MenuBarIconStyle.allCases) { style in
                    IconStyleCell(
                        style: style,
                        isSelected: viewModel.iconStyle == style,
                        onTap: { viewModel.iconStyle = style }
                    )
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct IconStyleCell: View {
    let style: MenuBarIconStyle
    let isSelected: Bool
    let onTap: @MainActor () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                IconStylePreview(style: style, isActive: true)
                IconStylePreview(style: style, isActive: false)
            }
            Text(style.displayName)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(style.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Tap to use this menu bar icon")
    }

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fillColor)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: isSelected ? 2 : 1)
        }
    }

    private var fillColor: Color {
        if isSelected { return Color.accentColor.opacity(0.12) }
        if isHovering { return Color.secondary.opacity(0.08) }
        return Color.clear
    }

    private var strokeColor: Color {
        if isSelected { return .accentColor }
        if isHovering { return Color.secondary.opacity(0.5) }
        return Color.secondary.opacity(0.25)
    }
}

private struct IconStylePreview: View {
    let style: MenuBarIconStyle
    let isActive: Bool

    var body: some View {
        Group {
            switch style.rendering(isActive: isActive) {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.title)
            case .dividedCircle(let orientation):
                DividedCircleGlyph(orientation: orientation)
            case .coffeeBean(let isFilled):
                CoffeeBeanGlyph(isFilled: isFilled)
            case .solidCircle(let isFilled):
                SolidCircleGlyph(isFilled: isFilled)
            case .dividedDisc(let orientation):
                DividedDiscGlyph(orientation: orientation)
            }
        }
        .frame(width: 32, height: 32)
        .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(0.7))
    }
}
