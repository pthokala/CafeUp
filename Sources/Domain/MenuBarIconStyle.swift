enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    // Coffee / beverage
    case cupAndSteam
    case espressoDrop

    // Energy / power
    case bolt
    case flame
    case battery

    // Light
    case ledBulb
    case deskLamp
    case sun

    // Sleep
    case moon

    // Abstract / geometric
    case circle
    case waveRing

    var id: String { rawValue }

    static let `default`: MenuBarIconStyle = .cupAndSteam

    var displayName: String {
        switch self {
        case .cupAndSteam:   return "Steaming Cup"
        case .espressoDrop:  return "Espresso Drop"
        case .bolt:          return "Bolt"
        case .flame:         return "Flame"
        case .battery:       return "Battery"
        case .ledBulb:       return "LED Bulb"
        case .deskLamp:      return "Desk Lamp"
        case .sun:           return "Sun"
        case .moon:          return "Moon"
        case .circle:        return "Circle"
        case .waveRing:      return "Wave Ring"
        }
    }

    func rendering(isActive: Bool) -> IconRendering {
        switch self {
        // Custom drawn glyph
        case .waveRing:
            return .waveRing(isActive: isActive)

        // SF Symbol pairs (idle outline → active fill)
        case .cupAndSteam:
            return .symbol(isActive ? "cup.and.heat.waves.fill"    : "cup.and.heat.waves")
        case .espressoDrop:
            return .symbol(isActive ? "drop.fill"                  : "drop")
        case .bolt:
            return .symbol(isActive ? "bolt.fill"                  : "bolt")
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
        case .circle:
            return .symbol(isActive ? "circle.fill"                : "circle")

        // Battery is an asymmetric pair: idle = empty (sleeping), active = full
        // (powered up). Reads as "is the system topped up?" at a glance.
        case .battery:
            return .symbol(isActive ? "battery.100percent"         : "battery.0percent")
        }
    }
}

enum IconRendering: Hashable, Sendable {
    case symbol(String)
    case waveRing(isActive: Bool)

    /// Whether the status item should draw this as a template image (one colour, tinted by
    /// macOS). The active Wave Ring has a blue wave, so it can't be one.
    var isTemplate: Bool {
        if case .waveRing(isActive: true) = self { return false }
        return true
    }
}
