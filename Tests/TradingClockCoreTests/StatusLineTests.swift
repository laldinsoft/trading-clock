import XCTest
@testable import TradingClockCore

/// The status wording lives in the app target, so this pins the inputs it relies on.
final class StatusLineTests: XCTestCase {
    func testHolidayNameAndEarlyCloseAreAvailable() {
        let cal = NYSECalendar()
        XCTAssertEqual(cal.holidayName(Day(2026, 11, 26)), "Thanksgiving Day")
        XCTAssertNil(cal.holidayName(Day(2026, 11, 27)))
        XCTAssertTrue(cal.session(on: Day(2026, 11, 27))!.isEarlyClose)
        XCTAssertTrue(Day(2026, 9, 27).isWeekend)
    }
}
