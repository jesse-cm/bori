import Foundation

public enum ConfigError: Error, CustomStringConvertible {
    case invalid(String)

    public var description: String {
        switch self {
        case .invalid(let message): return message
        }
    }
}

public struct BoriConfig: Equatable {
    /// Minutes a manually begun session lasts.
    public var sessionMinutes: Int
    /// Tabs a browser window is kept to during a session.
    public var tabCap: Int
    /// App names or bundle identifiers put away during a session.
    public var blockedApps: [String]
    /// Hosts put away during a session (via /etc/hosts, helper pending).
    public var blockedHosts: [String]
    public var schedules: [Schedule]

    public init(
        sessionMinutes: Int = 50,
        tabCap: Int = 10,
        blockedApps: [String] = [],
        blockedHosts: [String] = [],
        schedules: [Schedule] = []
    ) {
        self.sessionMinutes = sessionMinutes
        self.tabCap = tabCap
        self.blockedApps = blockedApps
        self.blockedHosts = blockedHosts
        self.schedules = schedules
    }

    public static var defaultPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".bori.toml").path
    }

    /// A missing file is not an error — Bori starts with defaults.
    public static func load(path: String = defaultPath) throws -> BoriConfig {
        guard FileManager.default.fileExists(atPath: path) else { return BoriConfig() }
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(toml: text)
    }

    public static func parse(toml text: String) throws -> BoriConfig {
        let dict = try TOML.parse(text)
        var config = BoriConfig()

        if let n = dict["session_minutes"] as? Int {
            guard n > 0 else { throw ConfigError.invalid("session_minutes must be positive") }
            config.sessionMinutes = n
        }
        if let n = dict["tab_cap"] as? Int {
            guard n > 0 else { throw ConfigError.invalid("tab_cap must be positive") }
            config.tabCap = n
        }
        if let blocklist = dict["blocklist"] as? [String: Any] {
            config.blockedApps = try stringArray(blocklist["apps"], name: "blocklist.apps")
            config.blockedHosts = try stringArray(blocklist["hosts"], name: "blocklist.hosts")
        }
        if let entries = dict["schedule"] as? [[String: Any]] {
            for (index, entry) in entries.enumerated() {
                let label = "schedule #\(index + 1)"
                let dayNames = try stringArray(entry["days"], name: "\(label) days")
                guard !dayNames.isEmpty else {
                    throw ConfigError.invalid("\(label): days is required")
                }
                var days: Set<Weekday> = []
                for name in dayNames {
                    guard let day = Weekday(name: name) else {
                        throw ConfigError.invalid("\(label): unknown day \"\(name)\"")
                    }
                    days.insert(day)
                }
                guard let startText = entry["start"] as? String, let start = HourMinute(startText) else {
                    throw ConfigError.invalid("\(label): start must be \"HH:MM\"")
                }
                let minutes = entry["minutes"] as? Int ?? config.sessionMinutes
                guard minutes > 0 else {
                    throw ConfigError.invalid("\(label): minutes must be positive")
                }
                config.schedules.append(Schedule(days: days, start: start, minutes: minutes))
            }
        }
        return config
    }

    private static func stringArray(_ value: Any?, name: String) throws -> [String] {
        guard let value else { return [] }
        guard let items = value as? [Any] else {
            throw ConfigError.invalid("\(name) must be an array of strings")
        }
        return try items.map {
            guard let s = $0 as? String else {
                throw ConfigError.invalid("\(name) must be an array of strings")
            }
            return s
        }
    }

    public static let sampleTOML = """
    # Bori configuration. This file is the only interface —
    # sessions are shaped here, never through dialogs.

    # Minutes a manually begun session lasts.
    session_minutes = 50

    # Each browser window is kept to this many tabs during a session.
    tab_cap = 10

    [blocklist]
    # Apps asked politely to quit when a session begins; any that
    # refuse are hidden. Names or bundle identifiers.
    apps = []

    # Hosts put away for the length of a session (via /etc/hosts).
    hosts = []

    # Sessions can also begin on a schedule. Repeat this block freely.
    # [[schedule]]
    # days = ["mon", "tue", "wed", "thu", "fri"]
    # start = "09:00"
    # minutes = 90
    """
}
