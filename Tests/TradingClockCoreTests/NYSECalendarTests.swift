import XCTest
@testable import TradingClockCore

final class NYSECalendarTests: XCTestCase {
    let cal = NYSECalendar()

    func testHolidays2026MatchThePublishedSchedule() {
        let expected = [Day(2026, 1, 1), Day(2026, 1, 19), Day(2026, 2, 16), Day(2026, 4, 3), Day(2026, 5, 25),
                        Day(2026, 6, 19), Day(2026, 7, 3), Day(2026, 9, 7), Day(2026, 11, 26), Day(2026, 12, 25)]
        XCTAssertEqual(cal.holidays(year: 2026).map(\.day), expected)
        XCTAssertEqual(cal.earlyCloses(year: 2026), [Day(2026, 11, 27), Day(2026, 12, 24)])
    }

    func testHolidays2027() {
        let expected = [Day(2027, 1, 1), Day(2027, 1, 18), Day(2027, 2, 15), Day(2027, 3, 26), Day(2027, 5, 31),
                        Day(2027, 6, 18), Day(2027, 7, 5), Day(2027, 9, 6), Day(2027, 11, 25), Day(2027, 12, 24)]
        XCTAssertEqual(cal.holidays(year: 2027).map(\.day), expected)
        // Christmas Eve is the observed holiday, so it is not an early close.
        XCTAssertEqual(cal.earlyCloses(year: 2027), [Day(2027, 11, 26)])
    }

    func testNewYearOnSaturdayIsNotObserved() {
        // 1 Jan 2022 was a Saturday; the NYSE was open on Friday 31 Dec 2021.
        XCTAssertNil(cal.holidays(year: 2022).first { $0.name == "New Year's Day" })
        XCTAssertTrue(cal.isTradingDay(Day(2021, 12, 31)))
        // 1 Jan 2023 was a Sunday, observed on Monday 2 Jan.
        XCTAssertEqual(cal.holidays(year: 2023).first?.day, Day(2023, 1, 2))
    }

    func testEaster() {
        XCTAssertEqual(cal.easter(year: 2026), Day(2026, 4, 5))
        XCTAssertEqual(cal.easter(year: 2024), Day(2024, 3, 31))
        XCTAssertEqual(cal.easter(year: 2025), Day(2025, 4, 20))
    }

    func testTradingDays() {
        XCTAssertTrue(cal.isTradingDay(Day(2026, 9, 23)))   // Wednesday
        XCTAssertFalse(cal.isTradingDay(Day(2026, 9, 26)))  // Saturday
        XCTAssertFalse(cal.isTradingDay(Day(2026, 11, 26))) // Thanksgiving
        XCTAssertTrue(cal.isEarlyClose(Day(2026, 11, 27)))
        XCTAssertFalse(cal.isEarlyClose(Day(2026, 11, 30)))
        XCTAssertEqual(cal.nextTradingDay(onOrAfter: Day(2026, 11, 26)), Day(2026, 11, 27))
        XCTAssertEqual(cal.nextTradingDay(onOrAfter: Day(2026, 9, 26)), Day(2026, 9, 28))
    }

    func testOverrides() {
        let c = NYSECalendar(overrides: .init(closed: ["2026-09-24"], earlyClose: ["2026-09-25"], open: ["2026-11-26"]))
        XCTAssertFalse(c.isTradingDay(Day(2026, 9, 24)))
        XCTAssertTrue(c.isEarlyClose(Day(2026, 9, 25)))
        XCTAssertTrue(c.isTradingDay(Day(2026, 11, 26)))
    }

    func testDayParsingAndArithmetic() {
        XCTAssertEqual(Day(iso: "2026-03-08"), Day(2026, 3, 8))
        XCTAssertNil(Day(iso: "bogus"))
        XCTAssertEqual(Day(2026, 12, 31).adding(days: 1), Day(2027, 1, 1))
        XCTAssertEqual(Day(2026, 9, 23).weekday, 4)
    }
}
