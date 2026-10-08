import XCTest
@testable import TradingClockCore

final class WorldOverridesTests: XCTestCase {
    private func ny(_ d: Day, _ h: Int, _ m: Int) -> Date { d.at(hour: h, minute: m) }

    // MARK: Feeds

    func testParseUKTakesEnglandAndWalesOnly() throws {
        let json = """
        {"england-and-wales":{"division":"england-and-wales","events":[
          {"title":"Bank holiday for the coronation of King Charles III","date":"2023-05-08","notes":"","bunting":true},
          {"title":"New Year’s Day","date":"2023-01-02","notes":"Substitute day","bunting":true}]},
         "scotland":{"division":"scotland","events":[{"title":"St Andrew’s Day","date":"2023-11-30","notes":"","bunting":true}]}}
        """
        XCTAssertEqual(try WorldHolidayFeed.parseUK(Data(json.utf8)), ["2023-01-02", "2023-05-08"])
    }

    func testParseJapanShiftJISCSV() throws {
        let csv = "国民の祝日・休日月日,国民の祝日・休日名称\r\n2026/9/21,敬老の日\r\n2026/9/22,休日\r\n2026/9/23,秋分の日\r\n"
        let data = csv.data(using: .shiftJIS)!
        XCTAssertEqual(try WorldHolidayFeed.parseJapan(data), ["2026-09-21", "2026-09-22", "2026-09-23"])
    }

    func testFeedAddsOneOffAndReopensMovedHoliday() {
        // 2022: the Spring Bank Holiday moved from 30 May to 2 June, with 3 June (Jubilee)
        // and 19 September (the Queen's funeral) added.
        let rules = WorldMarket.londonHolidays(2022).map(\.day.description).filter { $0 != "2022-05-30" }
        let o = WorldHolidayFeed.overrides(for: .london, days: rules + ["2022-06-02", "2022-06-03", "2022-09-19"])
        XCTAssertEqual(o.open, ["2022-05-30"])
        let london = WorldMarket(.london, overrides: o)
        XCTAssertTrue(london.isTradingDay(Day(2022, 5, 30)))
        XCTAssertFalse(london.isTradingDay(Day(2022, 9, 19)))
        XCTAssertEqual(london.chip(at: ny(Day(2022, 9, 19), 6, 0)).label, "holiday, opens 03:00")
    }

    func testTokyoFeedKeepsYearEndClosure() {
        let national = WorldMarket.tokyoHolidays(2026).filter { $0.name != "Year-end Holiday" }.map(\.day.description)
        let o = WorldHolidayFeed.overrides(for: .tokyo, days: national)
        XCTAssertEqual(o.open, [])
        XCTAssertFalse(WorldMarket(.tokyo, overrides: o).isTradingDay(Day(2026, 12, 31)))
    }

    // MARK: Manual

    func testManualClosedIsNotReopenedByFeed() {
        let manual = NYSECalendar.Overrides(closed: ["2022-05-30"])
        let remote = NYSECalendar.Overrides(open: ["2022-05-30"])
        let m = WorldMarket(.london, overrides: manual.layered(over: remote))
        XCTAssertFalse(m.isTradingDay(Day(2022, 5, 30)))
    }

    func testTokyoHalfDayIsMorningOnly() {
        let tokyo = WorldMarket(.tokyo, overrides: .init(earlyClose: ["2026-10-09"]))
        XCTAssertEqual(tokyo.windows(on: Day(2026, 10, 9)).count, 1)
        // Friday 9 Oct in Tokyo opens 20:00 Thursday in New York and stops at the lunch break.
        XCTAssertEqual(tokyo.chip(at: ny(Day(2026, 10, 8), 21, 0)).label, "closes 22:30")
    }

    func testLondonHalfDay() {
        let london = WorldMarket(.london, overrides: .init(earlyClose: ["2026-10-09"]))
        XCTAssertEqual(london.chip(at: ny(Day(2026, 10, 9), 5, 0)).label, "closes 07:30")
    }

    func testOverridesFileListsAreOptional() throws {
        let o = try JSONDecoder().decode(NYSECalendar.Overrides.self, from: Data(#"{"closed":["2026-10-05"]}"#.utf8))
        XCTAssertEqual(o.closed, ["2026-10-05"])
        XCTAssertEqual(o.open, [])
    }
}
