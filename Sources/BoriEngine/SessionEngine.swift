import Foundation

public enum SessionState: Equatable {
    case idle
    case scheduled(nextStart: Date, minutes: Int)
    case running(start: Date, end: Date)
}

public enum SessionEvent: Equatable {
    case sessionBegan(start: Date, end: Date)
    case sessionExtended(until: Date)
    case sessionEnded(at: Date)
}

/// Pure state machine. Time always comes in through parameters; the engine
/// never reads the clock, never touches UI, and offers no way to end a
/// session early — the only mutations are begin, extend, and the tick.
public final class SessionEngine {
    public private(set) var config: BoriConfig
    public private(set) var session: DateInterval?
    public let calendar: Calendar

    public init(config: BoriConfig, calendar: Calendar = .current, restoredSession: DateInterval? = nil) {
        self.config = config
        self.calendar = calendar
        self.session = restoredSession
    }

    public func updateConfig(_ newConfig: BoriConfig) {
        config = newConfig
    }

    public func state(at now: Date) -> SessionState {
        if let s = session, now < s.end {
            return .running(start: s.start, end: s.end)
        }
        if let next = nextScheduled(after: now) {
            return .scheduled(nextStart: next.start, minutes: next.minutes)
        }
        return .idle
    }

    /// Begin a session now. A no-op while one is running: sessions are
    /// never restarted or shortened. If a scheduled window is already
    /// open, the later end wins (extend-only ratchet).
    @discardableResult
    public func begin(at now: Date, minutes: Int? = nil) -> [SessionEvent] {
        if let s = session, now < s.end { return [] }
        var end = now.addingTimeInterval(TimeInterval((minutes ?? config.sessionMinutes) * 60))
        if let window = activeScheduledWindow(at: now), window.end > end {
            end = window.end
        }
        session = DateInterval(start: now, end: end)
        return [.sessionBegan(start: now, end: end)]
    }

    @discardableResult
    public func extend(at now: Date, byMinutes: Int = 15) -> [SessionEvent] {
        guard let s = session, now < s.end else { return [] }
        let end = s.end.addingTimeInterval(TimeInterval(byMinutes * 60))
        session = DateInterval(start: s.start, end: end)
        return [.sessionExtended(until: end)]
    }

    /// Advance the clock: ends an expired session, then joins any
    /// scheduled window that is currently open.
    @discardableResult
    public func tick(at now: Date) -> [SessionEvent] {
        var events: [SessionEvent] = []
        if let s = session, now >= s.end {
            session = nil
            events.append(.sessionEnded(at: s.end))
        }
        if session == nil, let window = activeScheduledWindow(at: now) {
            session = DateInterval(start: now, end: window.end)
            events.append(.sessionBegan(start: now, end: window.end))
        }
        return events
    }

    public func nextScheduled(after now: Date) -> (start: Date, minutes: Int)? {
        var best: (start: Date, minutes: Int)?
        for schedule in config.schedules {
            if let start = schedule.nextStart(after: now, calendar: calendar),
               best == nil || start < best!.start {
                best = (start, schedule.minutes)
            }
        }
        return best
    }

    /// The scheduled window containing `now`, if any (latest end wins).
    public func activeScheduledWindow(at now: Date) -> DateInterval? {
        var best: DateInterval?
        for schedule in config.schedules {
            if let start = schedule.lastStart(onOrBefore: now, calendar: calendar) {
                let window = schedule.window(from: start)
                if window.end > now, best == nil || window.end > best!.end {
                    best = window
                }
            }
        }
        return best
    }
}
