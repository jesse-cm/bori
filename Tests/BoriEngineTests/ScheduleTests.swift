import XCTest
@testable import BoriEngine

final class ScheduleTests: XCTestCase {
    var calendar: Calendar!
    var noon: Date!
    var weekday: Weekday!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        noon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 22, hour: 12))!
        weekday = Weekday(rawValue: calendar.component(.weekday, from: noon))!
    }

    func testWeekdayNames() {
        XCTAssertEqual(Weekday(name: "mon"), .monday)
        XCTAssertEqual(Weekday(name: "Thursday"), .thursday)
        XCTAssertEqual(Weekday(name: "SUN"), .sunday)
        XCTAssertNil(Weekday(name: "someday"))
    }

    func testHourMinuteParsing() {
        XCTAssertEqual(HourMinute("9:05"), HourMinute(hour: 9, minute: 5))
        XCTAssertEqual(HourMinute("23:59"), HourMinute(hour: 23, minute: 59))
        XCTAssertNil(HourMinute("24:00"))
        XCTAssertNil(HourMinute("nine"))
    }

    func testLastStartIsEarlierToday() throws {
        let schedule = Schedule(days: [weekday], start: HourMinute(hour: 9, minute: 0), minutes: 60)
        let last = try XCTUnwrap(schedule.lastStart(onOrBefore: noon, calendar: calendar))
        XCTAssertEqual(noon.timeIntervalSince(last), 3 * 3600)
    }

    func testNextStartIsNextWeekWhenTodayHasPassed() throws {
        let schedule = Schedule(days: [weekday], start: HourMinute(hour: 9, minute: 0), minutes: 60)
        let next = try XCTUnwrap(schedule.nextStart(after: noon, calendar: calendar))
        XCTAssertGreaterThan(next, noon)
        XCTAssertEqual(calendar.component(.weekday, from: next), weekday.rawValue)
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
    }

    func testNextStartLaterToday() throws {
        let schedule = Schedule(days: [weekday], start: HourMinute(hour: 15, minute: 30), minutes: 30)
        let next = try XCTUnwrap(schedule.nextStart(after: noon, calendar: calendar))
        XCTAssertEqual(next.timeIntervalSince(noon), 3.5 * 3600)
    }
}
