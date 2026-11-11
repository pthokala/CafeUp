import AppKit
import SwiftUI

// Controls for SwiftUI content hosted inside the status-item menu.
//
// System `.checkbox` toggles, bordered buttons and segmented pickers render in their
// inactive (dimmed) state inside a menu because the menu window never becomes key, so
// these are drawn by hand to match the active system look.

/// Small checkbox: accent fill when on, a translucent well when off.
struct MenuCheckboxStyle: ToggleStyle {
    var labelSize: CGFloat = 11
    var boxSize: CGFloat = 12

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: boxSize / 2) {
                box(isOn: configuration.isOn)
                configuration.label
                    .font(.system(size: labelSize))
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func box(isOn: Bool) -> some View {
        let dark = colorScheme == .dark
        return ZStack {
            RoundedRectangle(cornerRadius: boxSize / 4, style: .continuous)
                .fill(isOn ? Color.accentColor : (dark ? Color.white.opacity(0.2) : Color.white))
            if !isOn {
                RoundedRectangle(cornerRadius: boxSize / 4, style: .continuous)
                    .strokeBorder(dark ? Color.white.opacity(0.1) : Color.black.opacity(0.2), lineWidth: 0.5)
            }
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: boxSize * 2 / 3, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: boxSize, height: boxSize)
    }
}

/// Compact push button. Plain: translucent gray fill with a hairline edge.
/// Prominent: accent fill with white text (the panel's default action).
struct MenuPushButtonStyle: ButtonStyle {
    var prominent = false
    var font: Font = .system(size: 12, weight: .bold)
    var height: CGFloat = 17

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        return configuration.label
            .font(font)
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(shape.fill(fill(pressed: configuration.isPressed)))
            .overlay(shape.strokeBorder(edge, lineWidth: 0.5))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 0, y: 0.5)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(shape)
    }

    private func fill(pressed: Bool) -> Color {
        if prominent {
            return Color.accentColor.opacity(pressed ? 0.8 : 1)
        }
        return colorScheme == .dark
            ? Color.white.opacity(pressed ? 0.35 : 0.25)
            : Color.white.opacity(pressed ? 0.7 : 1)
    }

    private var edge: Color {
        if prominent { return Color.white.opacity(0.15) }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.15)
    }
}

/// Two-or-more-segment switch; the selected segment is a raised lighter capsule.
struct MenuSegmentedControl<Value: Hashable>: View {
    let segments: [(label: String, value: Value)]
    @Binding var selection: Value
    var fontSize: CGFloat = 11
    var segmentWidth: CGFloat = 20
    var height: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        HStack(spacing: 0) {
            ForEach(segments, id: \.value) { segment in
                let selected = segment.value == selection
                Button {
                    selection = segment.value
                } label: {
                    Text(segment.label)
                        .font(.system(size: fontSize))
                        .foregroundStyle(.primary)
                        .frame(width: segmentWidth, height: height - 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(selected ? (dark ? Color.white.opacity(0.3) : Color.white) : Color.clear)
                                .shadow(color: .black.opacity(selected ? 0.2 : 0), radius: 0, y: 0.5)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07))
        )
    }
}

/// Small text box for whole numbers. Non-digits are dropped as they are typed; the
/// accent ring shows while it has focus.
struct MenuNumberField: View {
    @Binding var text: String
    var width: CGFloat = 32
    var fontSize: CGFloat = 12
    var maxDigits = 4

    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: fontSize).monospacedDigit())
            .multilineTextAlignment(.center)
            .focused($focused)
            .frame(width: width - 8)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(shape.fill(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
            .overlay(shape.inset(by: -1.5).stroke(Color.accentColor.opacity(focused ? 0.8 : 0), lineWidth: 3))
            .onChange(of: text) { _, newValue in
                let digits = String(newValue.filter(\.isNumber).prefix(maxDigits))
                if digits != newValue { text = digits }
            }
    }
}

/// Hosts a SwiftUI view as a menu item, sized to the view's ideal size.
@MainActor
func hostedMenuItem<Content: View>(_ content: Content) -> NSMenuItem {
    let item = NSMenuItem()
    let host = NSHostingView(rootView: content)
    host.translatesAutoresizingMaskIntoConstraints = true
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    item.view = host
    return item
}
