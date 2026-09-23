import Foundation

/// A calendar day in New York, independent of the wall-clock time.
public struct Day: Hashable, Comparable, CustomStringConvertible, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    public init(_ date: Date) {
        let c = NewYork.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(c.year!, c.month!, c.day!)
    }

    /// The instant this day starts, in New York.
    public var start: Date { at(hour: 0, minute: 0) }

    /// The instant at `hour:minute` on this day, in New York (DST-aware).
    public func at(hour: Int, minute: Int, second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute; c.second = second
        return NewYork.calendar.date(from: c)!
    }

    /// 1 = Sunday … 7 = Saturday, as `Calendar` numbers them.
    public var weekday: Int { NewYork.calendar.component(.weekday, from: start) }
    public var isWeekend: Bool { weekday == 1 || weekday == 7 }

    public func adding(days: Int) -> Day {
        Day(NewYork.calendar.date(byAdding: .day, value: days, to: start)!)
    }

    public static func < (a: Day, b: Day) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    /// ISO form, `2026-09-23`.
    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// Parses the ISO form; anything else returns nil.
    public init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(parts[0], parts[1], parts[2])
    }
}

public enum NewYork {
    public static let timeZone = TimeZone(identifier: "America/New_York")!
    public static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()
}
