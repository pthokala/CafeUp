import Foundation
import os

protocol TriggerStore: Sendable {
    func load() -> [Trigger]
    func save(_ triggers: [Trigger])
}

/// Persists triggers as a JSON array in `UserDefaults`.
///
/// Entries are decoded one at a time: a trigger this build can't read
/// (written by a newer version, or damaged) is skipped instead of discarding
/// the whole list, and its raw JSON is written back untouched on every
/// `save`, so editing triggers here never destroys it and it reappears after
/// an upgrade. A payload that isn't a JSON array at all is copied to
/// `unreadableBackupKey` before the next `save` can overwrite it.
final class UserDefaultsTriggerStore: TriggerStore, @unchecked Sendable {
    private static let storageKey = "com.pardhu.CafeUp.triggers.v1"
    static let unreadableBackupKey = "com.pardhu.CafeUp.triggers.v1.unreadable"

    private let defaults: UserDefaults
    private let logger: AppLogger
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    /// Entries from the last `load` that didn't decode as a `Trigger`.
    private let unreadableEntries = OSAllocatedUnfairLock<[JSONValue]>(initialState: [])

    init(defaults: UserDefaults = .standard, logger: AppLogger = OSAppLogger(category: "triggers")) {
        self.defaults = defaults
        self.logger = logger
    }

    func load() -> [Trigger] {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            unreadableEntries.withLock { $0 = [] }
            return []
        }
        guard let entries = try? decoder.decode([StoredEntry].self, from: data) else {
            defaults.set(data, forKey: Self.unreadableBackupKey)
            unreadableEntries.withLock { $0 = [] }
            logger.error("Stored triggers aren't a readable list; raw data kept under \(Self.unreadableBackupKey)")
            return []
        }

        var triggers: [Trigger] = []
        var unreadable: [JSONValue] = []
        for entry in entries {
            switch entry {
            case .trigger(let trigger): triggers.append(trigger)
            case .unreadable(let raw): unreadable.append(raw)
            }
        }
        if !unreadable.isEmpty {
            logger.error("Skipped \(unreadable.count) stored trigger(s) this version can't read; they are kept on save")
        }
        unreadableEntries.withLock { $0 = unreadable }
        return triggers
    }

    func save(_ triggers: [Trigger]) {
        let preserved = unreadableEntries.withLock { $0 }
        let entries = triggers.map(StoredEntry.trigger) + preserved.map(StoredEntry.unreadable)
        guard let data = try? encoder.encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// One element of the stored array: a trigger, or JSON this build can't
/// interpret, kept verbatim so it can be written back.
private enum StoredEntry: Codable {
    case trigger(Trigger)
    case unreadable(JSONValue)

    init(from decoder: Decoder) throws {
        if let trigger = try? Trigger(from: decoder) {
            self = .trigger(trigger)
        } else {
            self = .unreadable(try JSONValue(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .trigger(let trigger): try trigger.encode(to: encoder)
        case .unreadable(let raw): try raw.encode(to: encoder)
        }
    }
}

/// Any JSON value, decoded faithfully enough to re-encode it unchanged.
private enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
