import XCTest
@testable import BoriEngine

final class SessionEngineTests: XCTestCase {
    var calendar: Calendar!
    /// A fixed reference: 08:00 on an arbitrary morning.
    var morning8: Date!
    /// The weekday of that morning, so schedule tests are self-consistent.
    var weekday: Weekday!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        morning8 = calendar.date(from: DateComponents(year: 2026, month: 7, day: 22, hour: 8))!
        weekday = Weekday(rawValue: calendar.component(.weekday, from: morning8))!
    }

    func minutes(_ n: Int) -> TimeInterval { TimeInterval(n * 60) }

    func engine(schedules: [Schedule] = [], restored: DateInterval? = nil) -> SessionEngine {
        SessionEngine(
            config: BoriConfig(sessionMinutes: 50, schedules: schedules),
            calendar: calendar,
            restoredSession: restored
        )
    }

    // MARK: - Manual sessions

    func testIdleWithoutSchedules() {
        XCTAssertEqual(engine().state(at: morning8), .idle)
    }

    func testBeginRunsForConfiguredMinutes() {
        let e = engine()
        let events = e.begin(at: morning8)
        let end = morning8.addingTimeInterval(minutes(50))
        XCTAssertEqual(events, [.sessionBegan(start: morning8, end: end)])
        XCTAssertEqual(e.state(at: morning8 + 1), .running(start: morning8, end: end))
    }

    func testBeginWhileRunningIsANoOp() {
        let e = engine()
        e.begin(at: morning8)
        let end = morning8.addingTimeInterval(minutes(50))
        XCTAssertEqual(e.begin(at: morning8 + minutes(10)), [])
        XCTAssertEqual(e.state(at: morning8 + minutes(10)), .running(start: morning8, end: end))
    }

    func testExtendRatchets() {
        let e = engine()
        e.begin(at: morning8)
        let extended = morning8.addingTimeInterval(minutes(65))
        XCTAssertEqual(e.extend(at: morning8 + minutes(10)), [.sessionExtended(until: extended)])
        XCTAssertEqual(e.state(at: morning8 + minutes(60)), .running(start: morning8, end: extended))
    }

    func testExtendWhenIdleIsANoOp() {
        XCTAssertEqual(engine().extend(at: morning8), [])
    }

    func testTickEndsExpiredSession() {
        let e = engine()
        e.begin(at: morning8)
        let end = morning8.addingTimeInterval(minutes(50))
        XCTAssertEqual(e.tick(at: morning8 + minutes(49)), [])
        XCTAssertEqual(e.tick(at: end), [.sessionEnded(at: end)])
        XCTAssertEqual(e.state(at: end + 1), .idle)
    }

    func testRestoredSessionKeepsRunning() {
        let end = morning8.addingTimeInterval(minutes(30))
        let e = engine(restored: DateInterval(start: morning8 - minutes(20), end: end))
        XCTAssertEqual(e.state(at: morning8), .running(start: morning8 - minutes(20), end: end))
    }

    // MARK: - Schedules

    var nineToTen: Schedule {
        Schedule(days: [weekday], start: HourMinute(hour: 9, minute: 0), minutes: 60)
    }

    func testScheduledStateBeforeWindow() {
        let e = engine(schedules: [nineToTen])
        let nine = morning8.addingTimeInterval(minutes(60))
        XCTAssertEqual(e.state(at: morning8), .scheduled(nextStart: nine, minutes: 60))
    }

    func testTickJoinsOpenWindow() {
        let e = engine(schedules: [nineToTen])
        let nine = morning8.addingTimeInterval(minutes(60))
        let ten = morning8.addingTimeInterval(minutes(120))
        XCTAssertEqual(e.tick(at: morning8 + minutes(59)), [])
        let joined = nine + 1
        XCTAssertEqual(e.tick(at: joined), [.sessionBegan(start: joined, end: ten)])
        XCTAssertEqual(e.state(at: joined + 1), .running(start: joined, end: ten))
    }

    func testScheduledSessionEndsAndDoesNotRestart() {
        let e = engine(schedules: [nineToTen])
        let nine = morning8.addingTimeInterval(minutes(60))
        let ten = morning8.addingTimeInterval(minutes(120))
        e.tick(at: nine + 1)
        XCTAssertEqual(e.tick(at: ten), [.sessionEnded(at: ten)])
        XCTAssertEqual(e.tick(at: ten + 30), [])
        if case .running = e.state(at: ten + 30) {
            XCTFail("session restarted after its window closed")
        }
    }

    func testManualBeginInsideWindowRatchetsToWindowEnd() {
        // A 50-minute manual session begun at 9:30 inside a 9:00–10:00
        // window would end at 10:20 — the later end wins.
        let e = engine(schedules: [nineToTen])
        let nineThirty = morning8.addingTimeInterval(minutes(90))
        let events = e.begin(at: nineThirty)
        let manualEnd = nineThirty.addingTimeInterval(minutes(50))
        XCTAssertEqual(events, [.sessionBegan(start: nineThirty, end: manualEnd)])
    }

    func testManualSessionEndingInsideWindowJoinsRemainder() {
        // Manual session 8:20–9:10 ends inside the 9:00–10:00 window;
        // the tick that ends it immediately joins the remainder.
        let e = engine(schedules: [nineToTen])
        let start = morning8.addingTimeInterval(minutes(20))
        e.begin(at: start)
        let manualEnd = start.addingTimeInterval(minutes(50))
        let ten = morning8.addingTimeInterval(minutes(120))
        let events = e.tick(at: manualEnd + 1)
        XCTAssertEqual(events, [
            .sessionEnded(at: manualEnd),
            .sessionBegan(start: manualEnd + 1, end: ten),
        ])
    }

    func testNextScheduledPicksEarliest() {
        let later = Schedule(days: [weekday], start: HourMinute(hour: 15, minute: 0), minutes: 30)
        let e = engine(schedules: [later, nineToTen])
        guard case .scheduled(let next, let mins) = e.state(at: morning8) else {
            return XCTFail("expected scheduled state")
        }
        XCTAssertEqual(next, morning8.addingTimeInterval(minutes(60)))
        XCTAssertEqual(mins, 60)
    }
}
