import XCTest
@testable import TradingClockCore

final class WorldMarketTests: XCTestCase {
    let london = WorldMarket(.london)
    let tokyo = WorldMarket(.tokyo)

    private func ny(_ d: Day, _ h: Int, _ m: Int) -> Date { d.at(hour: h, minute: m) }

    // MARK: London

    func testLondonOpensAt0300NewYorkMostOfTheYear() {
        let thu = Day(2026, 10, 8)
        XCTAssertEqual(london.status(at: ny(thu, 2, 59)).state, .closed)
        XCTAssertEqual(london.status(at: ny(thu, 3, 0)).state, .open)
        XCTAssertEqual(london.chip(at: ny(thu, 8, 15)).label, "closes 11:30")
        XCTAssertEqual(london.chip(at: ny(thu, 8, 15)).countdown, "3h 15m")
        XCTAssertEqual(london.chip(at: ny(thu, 12, 0)).label, "opens 03:00")
    }

    func testLondonOpensAt0400WhileUKAndUSClocksDisagree() {
        // The UK leaves summer time on 25 Oct 2026, the US on 1 Nov.
        let tue = Day(2026, 10, 27)
        XCTAssertEqual(london.status(at: ny(tue, 3, 30)).state, .closed)
        XCTAssertEqual(london.chip(at: ny(tue, 3, 30)).label, "opens 04:00")
        XCTAssertEqual(london.chip(at: ny(tue, 10, 0)).label, "closes 12:30")
    }

    func testLondonWeekendShowsTheDay() {
        let chip = london.chip(at: ny(Day(2026, 10, 9), 12, 0))   // Friday after the close
        XCTAssertEqual(chip.label, "opens Mon 03:00")
        XCTAssertNil(chip.countdown)
    }

    func testLondonBankHolidays2026() {
        let days = WorldMarket.londonHolidays(2026).map(\.day.description)
        XCTAssertEqual(days, ["2026-01-01", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25",
                              "2026-08-31", "2026-12-25", "2026-12-28"])
    }

    func testLondonChristmasOnASaturday() {
        // 25 Dec 2027 is a Saturday: Christmas moves to Monday 27, Boxing Day to Tuesday 28.
        let xmas = WorldMarket.londonHolidays(2027).filter { $0.day.month == 12 }.map(\.day.description)
        XCTAssertEqual(xmas, ["2027-12-27", "2027-12-28"])
    }

    func testLondonHolidayChip() {
        let chip = london.chip(at: ny(Day(2026, 8, 31), 10, 0))
        XCTAssertEqual(chip.label, "holiday, opens 03:00")
        XCTAssertEqual(london.status(at: ny(Day(2026, 8, 31), 10, 0)).holiday, "Summer Bank Holiday")
    }

    func testLondonHalfDayOnChristmasEve() {
        let eve = Day(2026, 12, 24)
        XCTAssertEqual(london.chip(at: ny(eve, 5, 0)).label, "closes 07:30")
        XCTAssertEqual(london.status(at: ny(eve, 7, 30)).state, .closed)
    }

    // MARK: Tokyo

    func testTokyoSessionsInSummer() {
        let thu = Day(2026, 10, 8)
        XCTAssertEqual(tokyo.chip(at: ny(thu, 19, 0)).label, "opens 20:00")
        XCTAssertEqual(tokyo.chip(at: ny(thu, 21, 0)).label, "lunch 22:30")
        XCTAssertEqual(tokyo.status(at: ny(thu, 23, 0)).state, .lunch)
        XCTAssertEqual(tokyo.chip(at: ny(thu, 23, 0)).label, "back 23:30")
        XCTAssertEqual(tokyo.chip(at: ny(Day(2026, 10, 9), 1, 0)).label, "closes 02:30")
    }

    func testTokyoOpensAt1900NewYorkInWinter() {
        let tue = Day(2027, 1, 12)
        XCTAssertEqual(tokyo.status(at: ny(tue, 19, 0)).state, .open)
        XCTAssertEqual(tokyo.chip(at: ny(tue, 23, 0)).label, "closes 01:30")
    }

    func testTokyoHolidays2026() {
        let h = Dictionary(uniqueKeysWithValues: WorldMarket.tokyoHolidays(2026).map { ($0.day.description, $0.name) })
        XCTAssertEqual(h["2026-03-20"], "Vernal Equinox Day")
        XCTAssertEqual(h["2026-05-06"], "Substitute Holiday")   // Constitution Day falls on a Sunday
        XCTAssertEqual(h["2026-09-21"], "Respect for the Aged Day")
        XCTAssertEqual(h["2026-09-22"], "Citizens' Holiday")
        XCTAssertEqual(h["2026-09-23"], "Autumnal Equinox Day")
        XCTAssertEqual(h["2026-10-12"], "Sports Day")
        XCTAssertEqual(h["2026-12-31"], "Year-end Holiday")
        XCTAssertEqual(h["2026-01-02"], "Year-end Holiday")
        XCTAssertNil(h["2026-12-30"])
    }

    func testTokyoReopensAfterGoldenWeek() {
        // Golden Week 2026 runs 29 Apr and 2–6 May; Tokyo trades again on Thursday 7 May,
        // which is the evening of Wednesday 6 May in New York.
        let chip = tokyo.chip(at: ny(Day(2026, 5, 4), 12, 0))
        XCTAssertEqual(chip.label, "holiday, opens Wed 20:00")
    }

    // MARK: Countdown

    func testShortCountdown() {
        XCTAssertEqual(Countdown.short(45 * 60), "45m")
        XCTAssertEqual(Countdown.short(44 * 60 + 1), "45m")
        XCTAssertEqual(Countdown.short(3 * 3600 + 15 * 60), "3h 15m")
        XCTAssertEqual(Countdown.short(3600), "1h 00m")
    }
}
