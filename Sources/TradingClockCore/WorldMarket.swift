import Foundation

/// A cash market outside New York, shown as a small chip beside the session line:
/// whether it is open and when that changes. Hours and holidays follow the exchange's
/// own rules and time zone; every time it reports is a `Date`, shown in New York time.
public struct WorldMarket: Sendable, Identifiable {
    public enum Exchange: String, CaseIterable, Sendable {
        case london = "LDN", tokyo = "TYO"
    }

    public let exchange: Exchange
    public var id: String { exchange.rawValue }
    public var name: String { exchange == .london ? "London" : "Tokyo" }
    /// Settings label: city and exchange.
    public var title: String { exchange == .london ? "London (LSE)" : "Tokyo (TSE)" }
    let calendar: Calendar

    public init(_ exchange: Exchange) {
        self.exchange = exchange
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: exchange == .london ? "Europe/London" : "Asia/Tokyo")!
        c.locale = Locale(identifier: "en_US_POSIX")
        calendar = c
    }

    public static let all = Exchange.allCases.map(WorldMarket.init)

    // MARK: Days and windows

    /// The calendar day in the market's own time zone.
    public func localDay(_ date: Date) -> Day {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return Day(c.year!, c.month!, c.day!)
    }

    func at(_ day: Day, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }

    public func isTradingDay(_ day: Day) -> Bool { !day.isWeekend && holidayName(day) == nil }

    /// Continuous trading windows on a local day; two for Tokyo's lunch break, none when closed.
    public func windows(on day: Day) -> [DateInterval] {
        guard isTradingDay(day) else { return [] }
        switch exchange {
        case .london:
            // 08:00–16:30, or 12:30 on Christmas Eve and New Year's Eve.
            let halfDay = (day.month == 12 && (day.day == 24 || day.day == 31))
            return [DateInterval(start: at(day, 8, 0), end: halfDay ? at(day, 12, 30) : at(day, 16, 30))]
        case .tokyo:
            return [DateInterval(start: at(day, 9, 0), end: at(day, 11, 30)),
                    DateInterval(start: at(day, 12, 30), end: at(day, 15, 30))]
        }
    }

    // MARK: Status

    public struct Status: Equatable, Sendable {
        public enum State: Equatable, Sendable { case open, lunch, closed }
        public let state: State
        /// When the state next changes: the close (or lunch) while open, the reopening otherwise.
        public let changeAt: Date
        /// Open, and the next change is the lunch break rather than the close.
        public let breaksForLunch: Bool
        /// Closed on a weekday for this holiday.
        public let holiday: String?
    }

    public func status(at now: Date) -> Status {
        let today = localDay(now)
        // Two weeks ahead covers the longest run of closed days (Golden Week, New Year).
        let windows = (-1...14).flatMap { self.windows(on: today.adding(days: $0)) }
        guard let i = windows.firstIndex(where: { $0.end > now }) else {
            return Status(state: .closed, changeAt: now, breaksForLunch: false, holiday: nil)
        }
        let w = windows[i]
        if w.start <= now {
            let lunch = i + 1 < windows.count && localDay(windows[i + 1].start) == localDay(w.start)
            return Status(state: .open, changeAt: w.end, breaksForLunch: lunch, holiday: nil)
        }
        if i > 0, localDay(windows[i - 1].end) == localDay(w.start), windows[i - 1].end <= now {
            return Status(state: .lunch, changeAt: w.start, breaksForLunch: false, holiday: nil)
        }
        return Status(state: .closed, changeAt: w.start, breaksForLunch: false,
                      holiday: today.isWeekend ? nil : holidayName(today))
    }

    /// Chip text in New York time: "closes 11:30", "lunch 22:30", "back 23:30",
    /// "opens 20:00", or "opens Mon 03:00" with no countdown when it is a day or more away.
    public func chip(at now: Date) -> (label: String, countdown: String?) {
        let s = status(at: now)
        let remaining = s.changeAt.timeIntervalSince(now)
        switch s.state {
        case .open: return ("\(s.breaksForLunch ? "lunch" : "closes") \(Self.nyTime.string(from: s.changeAt))", Countdown.short(remaining))
        case .lunch: return ("back \(Self.nyTime.string(from: s.changeAt))", Countdown.short(remaining))
        case .closed:
            let prefix = s.holiday == nil ? "" : "holiday, "
            if remaining >= 86_400 { return ("\(prefix)opens \(Self.nyDayTime.string(from: s.changeAt))", nil) }
            return ("\(prefix)opens \(Self.nyTime.string(from: s.changeAt))", Countdown.short(remaining))
        }
    }

    private static func nyFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = NewYork.calendar; f.timeZone = NewYork.timeZone
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = format
        return f
    }
    private static let nyTime = nyFormatter("HH:mm")
    private static let nyDayTime = nyFormatter("EEE HH:mm")

    // MARK: Holidays

    public func holidayName(_ day: Day) -> String? {
        holidays(year: day.year).first { $0.day == day }?.name
    }

    public func holidays(year y: Int) -> [NYSECalendar.Holiday] {
        exchange == .london ? Self.londonHolidays(y) : Self.tokyoHolidays(y)
    }

    /// England and Wales bank holidays, the days the LSE closes. One-off holidays
    /// (a coronation, a jubilee) are announced a year ahead and are not predicted.
    static func londonHolidays(_ y: Int) -> [NYSECalendar.Holiday] {
        let rules = NYSECalendar()
        func nextWeekday(_ d: Day) -> Day { var d = d; while d.isWeekend { d = d.adding(days: 1) }; return d }
        let christmas = nextWeekday(Day(y, 12, 25))
        let easter = rules.easter(year: y)
        return [
            .init(day: nextWeekday(Day(y, 1, 1)), name: "New Year's Day"),
            .init(day: easter.adding(days: -2), name: "Good Friday"),
            .init(day: easter.adding(days: 1), name: "Easter Monday"),
            .init(day: rules.nth(1, weekday: 2, month: 5, year: y), name: "Early May Bank Holiday"),
            .init(day: rules.last(weekday: 2, month: 5, year: y), name: "Spring Bank Holiday"),
            .init(day: rules.last(weekday: 2, month: 8, year: y), name: "Summer Bank Holiday"),
            .init(day: christmas, name: "Christmas Day"),
            .init(day: nextWeekday(christmas.adding(days: 1)), name: "Boxing Day"),
        ].sorted { $0.day < $1.day }
    }

    /// Japanese national holidays plus the exchange's own year-end closure
    /// (31 December to 3 January).
    static func tokyoHolidays(_ y: Int) -> [NYSECalendar.Holiday] {
        let rules = NYSECalendar()
        // Equinox days by the standard approximation, good from 1980 to 2099.
        let n = Double(y - 1980), leap = Double((y - 1980) / 4)
        let vernal = Int(20.8431 + 0.242194 * n - leap), autumnal = Int(23.2488 + 0.242194 * n - leap)
        var national: [Day: String] = [
            Day(y, 1, 1): "New Year's Day",
            rules.nth(2, weekday: 2, month: 1, year: y): "Coming of Age Day",
            Day(y, 2, 11): "National Foundation Day",
            Day(y, 2, 23): "Emperor's Birthday",
            Day(y, 3, vernal): "Vernal Equinox Day",
            Day(y, 4, 29): "Showa Day",
            Day(y, 5, 3): "Constitution Memorial Day",
            Day(y, 5, 4): "Greenery Day",
            Day(y, 5, 5): "Children's Day",
            rules.nth(3, weekday: 2, month: 7, year: y): "Marine Day",
            Day(y, 8, 11): "Mountain Day",
            rules.nth(3, weekday: 2, month: 9, year: y): "Respect for the Aged Day",
            Day(y, 9, autumnal): "Autumnal Equinox Day",
            rules.nth(2, weekday: 2, month: 10, year: y): "Sports Day",
            Day(y, 11, 3): "Culture Day",
            Day(y, 11, 23): "Labour Thanksgiving Day",
        ]
        // A weekday between two holidays is a holiday too.
        for (d, _) in national {
            let mid = d.adding(days: 1)
            if national[mid] == nil, mid.weekday != 1, national[d.adding(days: 2)] != nil {
                national[mid] = "Citizens' Holiday"
            }
        }
        // A holiday on a Sunday moves to the next day that isn't already a holiday.
        for (d, _) in national where d.weekday == 1 {
            var sub = d.adding(days: 1)
            while national[sub] != nil { sub = sub.adding(days: 1) }
            national[sub] = "Substitute Holiday"
        }
        for d in [Day(y, 1, 2), Day(y, 1, 3), Day(y, 12, 31)] where national[d] == nil {
            national[d] = "Year-end Holiday"
        }
        return national.map { NYSECalendar.Holiday(day: $0.key, name: $0.value) }.sorted { $0.day < $1.day }
    }
}
