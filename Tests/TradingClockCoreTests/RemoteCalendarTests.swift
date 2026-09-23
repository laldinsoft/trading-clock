import XCTest
@testable import TradingClockCore

final class RemoteCalendarTests: XCTestCase {
    let sample = """
    [{"date":"2026-11-26","exchange":"NYSE","name":"Thanksgiving","status":"closed"},
     {"date":"2026-11-26","exchange":"NASDAQ","name":"Thanksgiving","status":"closed"},
     {"date":"2026-11-27","exchange":"NYSE","name":"Thanksgiving","status":"early-close","open":"2026-11-27T14:30:00.000Z","close":"2026-11-27T18:00:00.000Z"},
     {"date":"2026-10-05","exchange":"NYSE","name":"National Day of Mourning","status":"closed"},
     {"date":"2026-10-06","exchange":"OTC","name":"Something","status":"closed"},
     {"date":"bad","exchange":"NYSE","name":"Broken","status":"closed"}]
    """.data(using: .utf8)!

    func testParseAndOverrides() throws {
        let entries = try RemoteCalendar.parse(sample)
        XCTAssertEqual(entries.count, 6)
        let o = RemoteCalendar.overrides(from: entries)
        XCTAssertEqual(o.closed, ["2026-10-05", "2026-11-26"])
        XCTAssertEqual(o.earlyClose, ["2026-11-27"])
        let cal = NYSECalendar(overrides: o)
        XCTAssertFalse(cal.isTradingDay(Day(2026, 10, 5)))
    }

    func testMergeKeepsManualOpenDays() {
        let manual = NYSECalendar.Overrides(earlyClose: ["2026-10-09"], open: ["2026-10-05"])
        let remote = NYSECalendar.Overrides(closed: ["2026-10-05"])
        let cal = NYSECalendar(overrides: manual.merged(with: remote))
        XCTAssertTrue(cal.isTradingDay(Day(2026, 10, 5)))
        XCTAssertTrue(cal.isEarlyClose(Day(2026, 10, 9)))
    }
}
