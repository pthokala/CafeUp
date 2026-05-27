import Foundation

/// Routes `cafeup://…` URLs to an `AgentCommandHandler`.
///
/// Pure parsing: no I/O, no observation, no globals. The router is
/// `@MainActor` only because dispatching to the handler is — the parsing
/// itself is independent of any actor.
///
/// Grammar:
///   cafeup://start                         — indefinite session
///   cafeup://start?minutes=N               — timed (N ∈ [1, 1440])
///   cafeup://stop                          — end the current session
///   cafeup://policy?display=true&…         — partial policy update
///
/// Policy keys: `display`, `lidClosed`, `screensaver`. Values: strict
/// `"true"` or `"false"` (case-insensitive). At least one key required.
@MainActor
struct URLCommandRouter {
    nonisolated static let scheme = "cafeup"

    private let handler: AgentCommandHandler
    private let logger: AppLogger

    init(handler: AgentCommandHandler, logger: AppLogger) {
        self.handler = handler
        self.logger = logger
    }

    /// Parse `url` and dispatch the resulting command. Always returns a
    /// `RoutingOutcome` so callers (and tests) can verify what happened
    /// without scraping logs.
    @discardableResult
    func handle(_ url: URL) -> RoutingOutcome {
        switch parse(url) {
        case .failure(let rejection):
            logger.error("URL rejected: \(rejection) — \(url.absoluteString)")
            return .rejected(rejection)
        case .success(let command):
            do {
                try dispatch(command)
                logger.info("URL handled: \(command)")
                return .accepted(command)
            } catch {
                logger.error("URL handler failed: \(error) — \(url.absoluteString)")
                return .handlerFailed(command, error.localizedDescription)
            }
        }
    }

    // MARK: - Parsing

    private func parse(_ url: URL) -> Result<AgentCommand, RoutingRejection> {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.malformedURL)
        }
        guard let scheme = components.scheme?.lowercased(), scheme == Self.scheme else {
            return .failure(.wrongScheme(components.scheme ?? ""))
        }
        // For `cafeup://start`, `host` is "start". A trailing-only `cafeup://`
        // gives `host == nil` (which we reject as missing).
        guard let host = components.host?.lowercased(), !host.isEmpty else {
            return .failure(.missingCommand)
        }

        let params = QueryParameters(items: components.queryItems ?? [])

        switch host {
        case "start":   return parseStart(params)
        case "stop":    return .success(.stop)
        case "policy":  return parsePolicy(params)
        default:        return .failure(.unknownCommand(host))
        }
    }

    private func parseStart(_ params: QueryParameters) -> Result<AgentCommand, RoutingRejection> {
        guard let raw = params.first("minutes") else {
            return .success(.startIndefinite)
        }
        guard let minutes = Int(raw) else {
            return .failure(.invalidParameter(name: "minutes", value: raw))
        }
        let lo = AppIntentBridge.minTimedMinutes
        let hi = AppIntentBridge.maxTimedMinutes
        guard (lo...hi).contains(minutes) else {
            return .failure(.parameterOutOfRange(name: "minutes", value: raw, allowed: "\(lo)…\(hi)"))
        }
        return .success(.startTimed(minutes: minutes))
    }

    private func parsePolicy(_ params: QueryParameters) -> Result<AgentCommand, RoutingRejection> {
        var update = PolicyUpdate()
        if let raw = params.first("display") {
            switch Self.parseBool(raw) {
            case .some(let v): update.allowDisplaySleep = v
            case .none:        return .failure(.invalidParameter(name: "display", value: raw))
            }
        }
        if let raw = params.first("lidClosed") {
            switch Self.parseBool(raw) {
            case .some(let v): update.allowSystemSleepWhenLidClosed = v
            case .none:        return .failure(.invalidParameter(name: "lidClosed", value: raw))
            }
        }
        if let raw = params.first("screensaver") {
            switch Self.parseBool(raw) {
            case .some(let v): update.allowScreenSaverAfter45Min = v
            case .none:        return .failure(.invalidParameter(name: "screensaver", value: raw))
            }
        }
        guard !update.isEmpty else { return .failure(.noPolicyParameters) }
        return .success(.updatePolicy(update))
    }

    /// Strict bool parser — accepts only `true`/`false` (case-insensitive).
    /// Returning `nil` lets the caller report the offending value.
    static func parseBool(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "true":  return true
        case "false": return false
        default:      return nil
        }
    }

    // MARK: - Dispatch

    private func dispatch(_ command: AgentCommand) throws {
        switch command {
        case .startIndefinite:           try handler.startIndefinite()
        case .startTimed(let minutes):   try handler.startTimed(minutes: minutes)
        case .stop:                      handler.stop()
        case .updatePolicy(let update):  try handler.updatePolicy(update)
        }
    }
}

// MARK: - Types

enum AgentCommand: Equatable, CustomStringConvertible {
    case startIndefinite
    case startTimed(minutes: Int)
    case stop
    case updatePolicy(PolicyUpdate)

    var description: String {
        switch self {
        case .startIndefinite:           return "start(indefinite)"
        case .startTimed(let minutes):   return "start(timed:\(minutes)m)"
        case .stop:                      return "stop"
        case .updatePolicy(let u):       return "policy(\(u))"
        }
    }
}

enum RoutingOutcome: Equatable {
    case accepted(AgentCommand)
    case rejected(RoutingRejection)
    case handlerFailed(AgentCommand, String)
}

enum RoutingRejection: Error, Equatable, CustomStringConvertible {
    case malformedURL
    case wrongScheme(String)
    case missingCommand
    case unknownCommand(String)
    case invalidParameter(name: String, value: String)
    case parameterOutOfRange(name: String, value: String, allowed: String)
    case noPolicyParameters

    var description: String {
        switch self {
        case .malformedURL:
            return "malformed URL"
        case .wrongScheme(let s):
            return "wrong scheme '\(s)' (expected '\(URLCommandRouter.scheme)')"
        case .missingCommand:
            return "missing command"
        case .unknownCommand(let cmd):
            return "unknown command '\(cmd)'"
        case .invalidParameter(let name, let value):
            return "invalid value for '\(name)': '\(value)'"
        case .parameterOutOfRange(let name, let value, let allowed):
            return "value for '\(name)' out of range: '\(value)' (allowed: \(allowed))"
        case .noPolicyParameters:
            return "policy command needs at least one of: display, lidClosed, screensaver"
        }
    }
}

/// Tiny wrapper to look up the first value for a query item by name.
/// Tolerates repeated keys (takes the first) and percent-decoding (already
/// done by `URLComponents`). Lookups are case-sensitive — the grammar uses
/// fixed lowercase keys.
private struct QueryParameters {
    private let items: [URLQueryItem]

    init(items: [URLQueryItem]) { self.items = items }

    func first(_ name: String) -> String? {
        for item in items where item.name == name {
            // An empty-value query (`?display`) gets value == nil; treat as
            // absent so callers can distinguish "supplied" from "missing".
            if let value = item.value, !value.isEmpty { return value }
        }
        return nil
    }
}
