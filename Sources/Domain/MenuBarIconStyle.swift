enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    // Coffee / beverage
    case cupAndSaucer
    case cupAndSteam
    case mug
    case espressoDrop

    // Energy / power
    case bolt
    case powerToggle
    case flame
    case battery

    // Light
    case ledBulb
    case deskLamp
    case sun

    // Sleep / wildlife
    case moon
    case owl

    // Abstract / geometric
    case hexagon
    case circle
    case pill
    case dot
    case dividedDisc

    var id: String { rawValue }

    static let `default`: MenuBarIconStyle = .cupAndSaucer

    var displayName: String {
        switch self {
        case .cupAndSaucer:  return "Coffee Cup"
        case .cupAndSteam:   return "Steaming Cup"
        case .mug:           return "Mug"
        case .espressoDrop:  return "Espresso Drop"
        case .bolt:          return "Bolt"
        case .powerToggle:   return "Power Toggle"
        case .flame:         return "Flame"
        case .battery:       return "Battery"
        case .ledBulb:       return "LED Bulb"
        case .deskLamp:      return "Desk Lamp"
        case .sun:           return "Sun"
        case .moon:          return "Moon"
        case .owl:           return "Owl"
        case .hexagon:       return "Hexagon"
        case .circle:        return "Circle"
        case .pill:          return "Pill"
        case .dot:           return "Dot"
        case .dividedDisc:   return "Divided Disc"
        }
    }

    func rendering(isActive: Bool) -> IconRendering {
        switch self {
        // Custom SwiftUI shape glyphs
        case .dot:
            return .solidCircle(isFilled: isActive)
        case .dividedDisc:
            return .dividedDisc(orientation: isActive ? .vertical : .horizontal)

        // SF Symbol pairs (idle outline → active fill)
        case .cupAndSaucer:
            return .symbol(isActive ? "cup.and.saucer.fill"        : "cup.and.saucer")
        case .cupAndSteam:
            return .symbol(isActive ? "cup.and.heat.waves.fill"    : "cup.and.heat.waves")
        case .mug:
            return .symbol(isActive ? "mug.fill"                   : "mug")
        case .espressoDrop:
            return .symbol(isActive ? "drop.fill"                  : "drop")
        case .bolt:
            return .symbol(isActive ? "bolt.fill"                  : "bolt")
        case .powerToggle:
            return .symbol(isActive ? "power.circle.fill"          : "power.circle")
        case .flame:
            return .symbol(isActive ? "flame.fill"                 : "flame")
        case .ledBulb:
            return .symbol(isActive ? "lightbulb.led.fill"         : "lightbulb.led")
        case .deskLamp:
            return .symbol(isActive ? "lamp.desk.fill"             : "lamp.desk")
        case .sun:
            return .symbol(isActive ? "sun.max.fill"               : "sun.max")
        case .moon:
            return .symbol(isActive ? "moon.fill"                  : "moon")
        case .owl:
            // Apple's `bird` glyph is the closest single-symbol stand-in for
            // Amphetamine's classic owl icon — perched-bird silhouette at 18pt.
            return .symbol(isActive ? "bird.fill"                  : "bird")
        case .hexagon:
            return .symbol(isActive ? "hexagon.fill"               : "hexagon")
        case .circle:
            return .symbol(isActive ? "circle.fill"                : "circle")
        case .pill:
            return .symbol(isActive ? "pill.fill"                  : "pill")

        // Battery is an asymmetric pair: idle = empty (sleeping), active = full
        // (powered up). Reads as "is the system topped up?" at a glance.
        case .battery:
            return .symbol(isActive ? "battery.100percent"         : "battery.0percent")
        }
    }
}

enum IconRendering: Hashable, Sendable {
    case symbol(String)
    case solidCircle(isFilled: Bool)
    case dividedDisc(orientation: DividerOrientation)
}

enum DividerOrientation: Hashable, Sendable {
    case horizontal
    case vertical
}
