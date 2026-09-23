import XCTest
@testable import TradingClockCore

final class EventsAndRangeTests: XCTestCase {
    let cal = NYSECalendar()
    let wed = Day(2026, 9, 23)

    func testEventsOfADay() {
        let kinds = cal.events(on: wed).map(\.kind)
        XCTAssertEqual(kinds, [.preMarketOpen, .open, .rangeStage(minutes: 5), .rangeStage(minutes: 10),
                               .rangeStage(minutes: 15), .rangeStage(minutes: 30), .close, .afterHoursClose])
        XCTAssertEqual(cal.events(on: wed)[4].time, wed.at(hour: 9, minute: 45))
        XCTAssertTrue(cal.events(on: Day(2026, 9, 26)).isEmpty)
    }

    func testEventsInAWindowAreHalfOpen() {
        let open = wed.at(hour: 9, minute: 30)
        XCTAssertEqual(cal.events(after: open.addingTimeInterval(-1), through: open).map(\.kind), [.open])
        XCTAssertTrue(cal.events(after: open, through: open.addingTimeInterval(1)).isEmpty)
        // Across midnight: Wednesday day close and Thursday pre-market.
        let span = cal.events(after: wed.at(hour: 19, minute: 59), through: wed.adding(days: 1).at(hour: 4, minute: 0))
        XCTAssertEqual(span.map(\.kind), [.afterHoursClose, .preMarketOpen])
    }

    func testNextBoundarySkipsRangeStagesAndWeekends() {
        XCTAssertEqual(cal.nextBoundary(after: wed.at(hour: 9, minute: 31))?.kind, .close)
        let friEvening = Day(2026, 9, 25).at(hour: 21, minute: 0)
        let next = cal.nextBoundary(after: friEvening)!
        XCTAssertEqual(next.kind, .preMarketOpen)
        XCTAssertEqual(next.time, Day(2026, 9, 28).at(hour: 4, minute: 0))
    }

    func testRangeProgress() {
        let open = wed.at(hour: 9, minute: 30)
        XCTAssertNil(RangeProgress(open: open, now: open.addingTimeInterval(-1)))
        XCTAssertNil(RangeProgress(open: open, now: open.addingTimeInterval(30 * 60)))
        let p = RangeProgress(open: open, now: open.addingTimeInterval(7 * 60 + 30))!
        XCTAssertEqual(p.activeIndex, 1)
        XCTAssertEqual(p.active.minutes, 10)
        XCTAssertEqual(p.secondsToStageEnd, 150)
        XCTAssertEqual(p.fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(p.span(of: 3).start, 0.5, accuracy: 0.0001)
        XCTAssertEqual(p.span(of: 3).end, 1.0, accuracy: 0.0001)
        let last = RangeProgress(open: open, now: open.addingTimeInterval(29 * 60 + 59.2))!
        XCTAssertEqual(last.activeIndex, 3)
        XCTAssertEqual(last.secondsToStageEnd, 1)
    }

    func testCountdownFormatting() {
        XCTAssertEqual(Countdown.format(59), "0:59")
        XCTAssertEqual(Countdown.format(3599.2), "1:00:00")
        XCTAssertEqual(Countdown.format(3661), "1:01:01")
        XCTAssertEqual(Countdown.format(2 * 86_400 + 4 * 3600), "2d 4h")
        let open = MarketEvent(kind: .open, time: wed.at(hour: 9, minute: 30))
        XCTAssertEqual(Countdown.line(to: open, from: wed.at(hour: 9, minute: 17, second: 26)), "Open in 12:34")
        XCTAssertEqual(Countdown.line(to: open, from: Day(2026, 9, 21).at(hour: 9, minute: 0)), "Open Wed 09:30")
    }

    func testPhrasesAndKeys() {
        XCTAssertEqual(EventKind.rangeStage(minutes: 15).phrase, "Fifteen minute range set.")
        XCTAssertEqual(EventKind.rangeStage(minutes: 5).phrase, "Five minutes.")
        XCTAssertEqual(EventKind.allCases.map(\.key), ["premarket_open", "market_open", "range_5", "range_10", "range_15", "range_30", "market_close", "day_close"])
    }
}
