import Foundation

/// NYSE holidays and early closes, computed from the exchange's published rules
/// so no yearly update is needed. Unscheduled closures (a day of mourning, a
/// storm) cannot be predicted; `Overrides` lets the user add those.
public struct NYSECalendar: Sendable {
    public struct Overrides: Codable, Equatable, Sendable {
        /// Extra full-day closures, ISO dates.
        public var closed: [String] = []
        /// Extra 13:00 closes, ISO dates.
        public var earlyClose: [String] = []
        /// Days that would be holidays by rule but are open (rare), ISO dates.
        public var open: [String] = []
        public init(closed: [String] = [], earlyClose: [String] = [], open: [String] = []) {
            self.closed = closed; self.earlyClose = earlyClose; self.open = open
        }
    }

    public let overrides: Overrides

    public init(overrides: Overrides = Overrides()) { self.overrides = overrides }

    // MARK: Trading-day queries

    public func isTradingDay(_ day: Day) -> Bool {
        if overrides.open.contains(day.description) { return !day.isWeekend }
        if overrides.closed.contains(day.description) { return false }
        return !day.isWeekend && holidayName(day) == nil
    }

    /// 13:00 close instead of 16:00.
    public func isEarlyClose(_ day: Day) -> Bool {
        guard isTradingDay(day) else { return false }
        if overrides.earlyClose.contains(day.description) { return true }
        return earlyCloses(year: day.year).contains(day)
    }

    /// The name of the holiday observed on this day, or nil.
    public func holidayName(_ day: Day) -> String? {
        holidays(year: day.year).first { $0.day == day }?.name
    }

    /// The first trading day on or after `day`.
    public func nextTradingDay(onOrAfter day: Day) -> Day {
        var d = day
        for _ in 0..<30 { if isTradingDay(d) { return d }; d = d.adding(days: 1) }
        return d
    }

    // MARK: Rules

    public struct Holiday: Equatable, Sendable {
        public let day: Day
        public let name: String
    }

    /// Observed holidays for a year, in date order.
    public func holidays(year y: Int) -> [Holiday] {
        var list: [Holiday] = []
        // New Year's Day: Sunday moves to Monday; a Saturday is not observed (NYSE rule).
        let newYear = Day(y, 1, 1)
        if newYear.weekday == 1 { list.append(Holiday(day: newYear.adding(days: 1), name: "New Year's Day")) }
        else if newYear.weekday != 7 { list.append(Holiday(day: newYear, name: "New Year's Day")) }
        list.append(Holiday(day: nth(3, weekday: 2, month: 1, year: y), name: "Martin Luther King Jr. Day"))
        list.append(Holiday(day: nth(3, weekday: 2, month: 2, year: y), name: "Washington's Birthday"))
        list.append(Holiday(day: easter(year: y).adding(days: -2), name: "Good Friday"))
        list.append(Holiday(day: last(weekday: 2, month: 5, year: y), name: "Memorial Day"))
        list.append(Holiday(day: observed(Day(y, 6, 19)), name: "Juneteenth"))
        list.append(Holiday(day: observed(Day(y, 7, 4)), name: "Independence Day"))
        list.append(Holiday(day: nth(1, weekday: 2, month: 9, year: y), name: "Labor Day"))
        list.append(Holiday(day: nth(4, weekday: 5, month: 11, year: y), name: "Thanksgiving Day"))
        list.append(Holiday(day: observed(Day(y, 12, 25)), name: "Christmas Day"))
        return list.sorted { $0.day < $1.day }
    }

    /// 13:00 closes for a year: the day after Thanksgiving, July 3 and December 24
    /// when they are weekdays and the following holiday is also a weekday.
    public func earlyCloses(year y: Int) -> [Day] {
        var list = [nth(4, weekday: 5, month: 11, year: y).adding(days: 1)]
        for (eve, holiday) in [(Day(y, 7, 3), Day(y, 7, 4)), (Day(y, 12, 24), Day(y, 12, 25))] {
            if !eve.isWeekend && !holiday.isWeekend { list.append(eve) }
        }
        return list
    }

    /// Saturday holidays are observed on Friday, Sunday holidays on Monday.
    private func observed(_ day: Day) -> Day {
        switch day.weekday {
        case 7: return day.adding(days: -1)
        case 1: return day.adding(days: 1)
        default: return day
        }
    }

    private func nth(_ n: Int, weekday: Int, month: Int, year: Int) -> Day {
        let first = Day(year, month, 1)
        let offset = (weekday - first.weekday + 7) % 7
        return first.adding(days: offset + (n - 1) * 7)
    }

    private func last(weekday: Int, month: Int, year: Int) -> Day {
        let nextMonthStart = month == 12 ? Day(year + 1, 1, 1) : Day(year, month + 1, 1)
        let lastDay = nextMonthStart.adding(days: -1)
        let back = (lastDay.weekday - weekday + 7) % 7
        return lastDay.adding(days: -back)
    }

    /// Gregorian Easter Sunday (anonymous algorithm).
    func easter(year y: Int) -> Day {
        let a = y % 19, b = y / 100, c = y % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return Day(y, month, day)
    }
}
