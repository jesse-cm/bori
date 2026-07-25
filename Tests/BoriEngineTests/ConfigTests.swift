import XCTest
@testable import BoriEngine

final class ConfigTests: XCTestCase {
    func testDefaults() throws {
        let config = try BoriConfig.parse(toml: "")
        XCTAssertEqual(config, BoriConfig())
        XCTAssertEqual(config.sessionMinutes, 50)
        XCTAssertEqual(config.tabCap, 10)
    }

    func testFullConfig() throws {
        let config = try BoriConfig.parse(toml: """
        session_minutes = 25
        tab_cap = 6

        [blocklist]
        apps = ["Slack", "com.tinyspeck.slackmacgap"]
        hosts = ["twitter.com", "youtube.com"]

        [[schedule]]
        days = ["mon", "tuesday", "WED"]
        start = "09:00"
        minutes = 90
        """)
        XCTAssertEqual(config.sessionMinutes, 25)
        XCTAssertEqual(config.tabCap, 6)
        XCTAssertEqual(config.blockedApps, ["Slack", "com.tinyspeck.slackmacgap"])
        XCTAssertEqual(config.blockedHosts, ["twitter.com", "youtube.com"])
        XCTAssertEqual(config.schedules, [
            Schedule(days: [.monday, .tuesday, .wednesday], start: HourMinute(hour: 9, minute: 0), minutes: 90)
        ])
    }

    func testScheduleMinutesDefaultToSessionMinutes() throws {
        let config = try BoriConfig.parse(toml: """
        session_minutes = 40

        [[schedule]]
        days = ["fri"]
        start = "13:30"
        """)
        XCTAssertEqual(config.schedules.first?.minutes, 40)
    }

    func testBadDayIsAnError() {
        XCTAssertThrowsError(try BoriConfig.parse(toml: """
        [[schedule]]
        days = ["blursday"]
        start = "09:00"
        """))
    }

    func testSampleConfigRoundTrips() throws {
        let config = try BoriConfig.parse(toml: BoriConfig.sampleTOML)
        XCTAssertEqual(config, BoriConfig())
    }
}
