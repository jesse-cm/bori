import XCTest
@testable import BoriEngine

final class TOMLTests: XCTestCase {
    func testScalarsAndComments() throws {
        let dict = try TOML.parse("""
        # a comment
        session_minutes = 50   # trailing comment
        tab_cap = 10
        flag = true
        name = "The # Shelf"
        start = 09:30
        """)
        XCTAssertEqual(dict["session_minutes"] as? Int, 50)
        XCTAssertEqual(dict["tab_cap"] as? Int, 10)
        XCTAssertEqual(dict["flag"] as? Bool, true)
        XCTAssertEqual(dict["name"] as? String, "The # Shelf")
        XCTAssertEqual(dict["start"] as? String, "09:30")
    }

    func testTablesAndArrays() throws {
        let dict = try TOML.parse("""
        [blocklist]
        apps = ["Slack", "Discord"]
        hosts = [
            "twitter.com",
            "reddit.com",  # multiline, trailing comma
        ]
        """)
        let blocklist = try XCTUnwrap(dict["blocklist"] as? [String: Any])
        XCTAssertEqual(blocklist["apps"] as? [String], ["Slack", "Discord"])
        XCTAssertEqual(blocklist["hosts"] as? [String], ["twitter.com", "reddit.com"])
    }

    func testArrayOfTables() throws {
        let dict = try TOML.parse("""
        [[schedule]]
        days = ["mon"]
        start = "09:00"
        minutes = 90

        [[schedule]]
        days = ["sat", "sun"]
        start = "14:00"
        """)
        let schedules = try XCTUnwrap(dict["schedule"] as? [[String: Any]])
        XCTAssertEqual(schedules.count, 2)
        XCTAssertEqual(schedules[0]["minutes"] as? Int, 90)
        XCTAssertEqual(schedules[1]["days"] as? [String], ["sat", "sun"])
        XCTAssertNil(schedules[1]["minutes"])
    }

    func testSyntaxErrorCarriesLine() {
        XCTAssertThrowsError(try TOML.parse("ok = 1\nbroken")) { error in
            guard case TOMLError.syntax(let line, _) = error as! TOMLError else {
                return XCTFail("wrong error")
            }
            XCTAssertEqual(line, 2)
        }
    }

    func testSampleConfigParses() throws {
        _ = try TOML.parse(BoriConfig.sampleTOML)
    }
}
