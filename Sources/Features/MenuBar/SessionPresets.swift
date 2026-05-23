import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let duration: Duration

    static let minutePresets: [SessionPreset] = [
        SessionPreset(label: "5 Minutes",  duration: .seconds(5 * 60)),
        SessionPreset(label: "10 Minutes", duration: .seconds(10 * 60)),
        SessionPreset(label: "15 Minutes", duration: .seconds(15 * 60)),
        SessionPreset(label: "20 Minutes", duration: .seconds(20 * 60)),
        SessionPreset(label: "30 Minutes", duration: .seconds(30 * 60)),
        SessionPreset(label: "45 Minutes", duration: .seconds(45 * 60))
    ]

    static let hourPresets: [SessionPreset] = [
        SessionPreset(label: "1 Hour",   duration: .seconds(60 * 60)),
        SessionPreset(label: "2 Hours",  duration: .seconds(2 * 60 * 60)),
        SessionPreset(label: "3 Hours",  duration: .seconds(3 * 60 * 60)),
        SessionPreset(label: "4 Hours",  duration: .seconds(4 * 60 * 60)),
        SessionPreset(label: "5 Hours",  duration: .seconds(5 * 60 * 60)),
        SessionPreset(label: "6 Hours",  duration: .seconds(6 * 60 * 60)),
        SessionPreset(label: "8 Hours",  duration: .seconds(8 * 60 * 60)),
        SessionPreset(label: "12 Hours", duration: .seconds(12 * 60 * 60))
    ]
}
