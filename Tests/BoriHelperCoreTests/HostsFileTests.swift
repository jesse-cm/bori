import XCTest
@testable import BoriHelperCore

final class HostsFileTests: XCTestCase {
    let base = """
    ##
    # Host Database
    ##
    127.0.0.1\tlocalhost
    255.255.255.255\tbroadcasthost
    """

    func testApplyAddsMarkerBlockWithWWW() {
        let out = HostsFile.applying(["twitter.com"], to: base)
        XCTAssertTrue(out.contains("# bori:begin\n0.0.0.0 twitter.com\n0.0.0.0 www.twitter.com\n# bori:end"))
        XCTAssertTrue(out.hasPrefix(base))
    }

    func testWWWHostIsNotDoubled() {
        let out = HostsFile.applying(["www.reddit.com"], to: base)
        XCTAssertTrue(out.contains("0.0.0.0 www.reddit.com"))
        XCTAssertFalse(out.contains("www.www."))
    }

    func testApplyReplacesExistingBlock() {
        let once = HostsFile.applying(["twitter.com"], to: base)
        let twice = HostsFile.applying(["youtube.com"], to: once)
        XCTAssertFalse(twice.contains("twitter.com"))
        XCTAssertTrue(twice.contains("youtube.com"))
        XCTAssertEqual(twice.components(separatedBy: HostsFile.beginMarker).count, 2)
    }

    func testRemoveRestoresOriginal() {
        let blocked = HostsFile.applying(["twitter.com", "reddit.com"], to: base + "\n")
        let restored = HostsFile.removingBlock(from: blocked)
        XCTAssertFalse(restored.contains("bori"))
        XCTAssertTrue(restored.hasPrefix(base))
    }

    func testRemoveWithoutBlockIsUntouched() {
        XCTAssertEqual(HostsFile.removingBlock(from: base), base)
    }

    func testInvalidHostsAreNeverWritten() {
        let out = HostsFile.applying(
            ["evil.com 127.0.0.1 something", "ok.com", "bad\nline.com", "", "-x.com", "a..b"],
            to: base
        )
        XCTAssertTrue(out.contains("0.0.0.0 ok.com"))
        XCTAssertFalse(out.contains("evil.com"))
        XCTAssertFalse(out.contains("bad"))
    }

    func testValidation() {
        XCTAssertTrue(HostsFile.isValidHost("news.ycombinator.com"))
        XCTAssertTrue(HostsFile.isValidHost("X.com"))
        XCTAssertFalse(HostsFile.isValidHost("host with space"))
        XCTAssertFalse(HostsFile.isValidHost("tab\thost"))
        XCTAssertFalse(HostsFile.isValidHost(".com"))
        XCTAssertFalse(HostsFile.isValidHost("com."))
    }

    func testOnlyInvalidHostsMeansNoBlock() {
        let out = HostsFile.applying(["not a host"], to: base)
        XCTAssertEqual(out, base)
    }
}
