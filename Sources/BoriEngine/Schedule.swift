import Foundation

/// Calendar-compatible weekday numbering: 1 = Sunday … 7 = Saturday.
public enum Weekday: Int, CaseIterable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// Accepts "mon", "monday", "Tue", etc.
    public init?(name: String) {
        let prefix = name.lowercased().prefix(3)
        switch prefix {
        case "sun": self = .sunday
        case "mon": self = .monday
        case "tue": self = .tuesday
        case "wed": self = .wednesday
        case "thu": self = .thursday
        case "fri": self = .friday
        case "sat": self = .saturday
        default: return nil
        }
    }
}

public struct HourMinute: Equatable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Accepts "9:00" or "09:00".
    public init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        self.init(hour: h, minute: m)
    }
}

public struct Schedule: Equatable {
    public var days: Set<Weekday>
    public var start: HourMinute
    public var minutes: Int

    public init(days: Set<Weekday>, start: HourMinute, minutes: Int) {
        self.days = days
        self.start = start
        self.minutes = minutes
    }

    public func nextStart(after date: Date, calendar: Calendar) -> Date? {
        occurrences(of: date, calendar: calendar, direction: .forward).min()
    }

    /// The most recent start strictly before `date`.
    public func lastStart(onOrBefore date: Date, calendar: Calendar) -> Date? {
        occurrences(of: date, calendar: calendar, direction: .backward).max()
    }

    public func window(from start: Date) -> DateInterval {
        DateInterval(start: start, duration: TimeInterval(minutes * 60))
    }

    private func occurrences(of date: Date, calendar: Calendar, direction: Calendar.SearchDirection) -> [Date] {
        days.compactMap { day in
            calendar.nextDate(
                after: date,
                matching: DateComponents(hour: start.hour, minute: start.minute, weekday: day.rawValue),
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: direction
            )
        }
    }
}
