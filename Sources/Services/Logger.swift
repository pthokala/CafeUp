import Foundation
import OSLog

protocol AppLogger: Sendable {
    func info(_ message: String)
    func error(_ message: String)
}

struct OSAppLogger: AppLogger {
    private let logger: Logger

    init(category: String) {
        self.logger = Logger(subsystem: "com.pardhu.CafeUp", category: category)
    }

    func info(_ message: String)  { logger.info("\(message, privacy: .public)") }
    func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}
