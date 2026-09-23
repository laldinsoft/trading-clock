import XCTest
@testable import TradingClockCore

final class SessionTests: XCTestCase {
    let cal = NYSECalendar()
    let wed = Day(2026, 9, 23)

    func testPhasesThroughANormalDay() {
        XCTAssertEqual(cal.phase(at: wed.at(hour: 3, minute: 59)), .closed)
        XCTAssertEqual(cal.phase(at: wed.at(hour: 4, minute: 0)), .preMarket)
        XCTAssertEqual(cal.phase(at: wed.at(hour: 9, minute: 29, second: 59)), .preMarket)
        XCTAssertEqual(cal.phase(at: wed.at(hour: 9, minute: 30)), .regular)
        XCTAssertEqual(cal.phase(at: wed.at(hour: 15, minute: 59, second: 59)), .regular)
        XCTAssertEqual(cal.phase(at: wed.at(hour: 16, minute: 0)), .afterHours)
        XCTAssertEqual(cal.phase(at: wed.at(hour: 20, minute: 0)), .closed)
    }

    func testEarlyCloseDay() {
        let s = cal.session(on: Day(2026, 11, 27))!
        XCTAssertTrue(s.isEarlyClose)
        XCTAssertEqual(s.close, Day(2026, 11, 27).at(hour: 13, minute: 0))
        XCTAssertEqual(s.afterHoursClose, Day(2026, 11, 27).at(hour: 17, minute: 0))
    }

    func testWeekendAndHolidayAreClosed() {
        XCTAssertNil(cal.session(on: Day(2026, 9, 27)))
        XCTAssertEqual(cal.phase(at: Day(2026, 11, 26).at(hour: 10, minute: 0)), .closed)
    }

    func testSessionTimesFollowDST() {
        // 8 Mar 2026 is the DST switch; 9 Mar is EDT (UTC-4), 2 Mar is EST (UTC-5).
        let est = Day(2026, 3, 2).at(hour: 9, minute: 30)
        let edt = Day(2026, 3, 9).at(hour: 9, minute: 30)
        let utc = TimeZone(identifier: "UTC")!
        var c = Calendar(identifier: .gregorian); c.timeZone = utc
        XCTAssertEqual(c.component(.hour, from: est), 14)
        XCTAssertEqual(c.component(.hour, from: edt), 13)
    }
}
