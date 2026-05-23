enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case coffeeBean
    case cupAndSaucer
    case cupAndSteam
    case mug
    case takeoutCup
    case dot
    case dividedDisc
    case dividedCircle
    case circle
    case pill
    case bolt
    case eye
    case sun

    var id: String { rawValue }

    static let `default`: MenuBarIconStyle = .cupAndSaucer

    var displayName: String {
        switch self {
        case .coffeeBean:    return "Coffee Bean"
        case .cupAndSaucer:  return "Coffee Cup"
        case .cupAndSteam:   return "Steaming Cup"
        case .mug:           return "Mug"
        case .takeoutCup:    return "Takeout Cup"
        case .dot:           return "Dot"
        case .dividedDisc:   return "Divided Disc"
        case .dividedCircle: return "Divided Circle"
        case .circle:        return "Circle"
        case .pill:          return "Pill"
        case .bolt:          return "Bolt"
        case .eye:           return "Eye"
        case .sun:           return "Sun"
        }
    }

    func rendering(isActive: Bool) -> IconRendering {
        switch self {
        case .coffeeBean:
            return .coffeeBean(isFilled: isActive)
        case .dividedCircle:
            return .dividedCircle(orientation: isActive ? .vertical : .horizontal)
        case .dot:
            return .solidCircle(isFilled: isActive)
        case .dividedDisc:
            return .dividedDisc(orientation: isActive ? .vertical : .horizontal)
        case .cupAndSaucer:
            return .symbol(isActive ? "cup.and.saucer.fill"                  : "cup.and.saucer")
        case .cupAndSteam:
            return .symbol(isActive ? "cup.and.heat.waves.fill"              : "cup.and.heat.waves")
        case .mug:
            return .symbol(isActive ? "mug.fill"                             : "mug")
        case .takeoutCup:
            return .symbol(isActive ? "takeoutbag.and.cup.and.straw.fill"    : "takeoutbag.and.cup.and.straw")
        case .circle:
            return .symbol(isActive ? "circle.fill"                          : "circle")
        case .pill:
            return .symbol(isActive ? "pill.fill"                            : "pill")
        case .bolt:
            return .symbol(isActive ? "bolt.fill"                            : "bolt")
        case .eye:
            return .symbol(isActive ? "eye.fill"                             : "eye.slash")
        case .sun:
            return .symbol(isActive ? "sun.max.fill"                         : "sun.max")
        }
    }
}

enum IconRendering: Hashable, Sendable {
    case symbol(String)
    case dividedCircle(orientation: DividerOrientation)
    case coffeeBean(isFilled: Bool)
    case solidCircle(isFilled: Bool)
    case dividedDisc(orientation: DividerOrientation)
}

enum DividerOrientation: Hashable, Sendable {
    case horizontal
    case vertical
}
