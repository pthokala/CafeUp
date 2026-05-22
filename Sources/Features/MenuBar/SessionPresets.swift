import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let duration: Duration

    static let standard: [SessionPreset] = [
        .init(label: "5 minutes",  duration: .seconds(5 * 60)),
        .init(label: "15 minutes", duration: .seconds(15 * 60)),
        .init(label: "30 minutes", duration: .seconds(30 * 60)),
        .init(label: "1 hour",     duration: .seconds(60 * 60)),
        .init(label: "2 hours",    duration: .seconds(2 * 60 * 60)),
        .init(label: "5 hours",    duration: .seconds(5 * 60 * 60))
    ]
}
