import Foundation

/// Something the clock announces.
public enum EventKind: Hashable, Sendable, CaseIterable {
    case preMarketOpen
    case open
    case rangeStage(minutes: Int)
    case close
    case afterHoursClose

    public static var allCases: [EventKind] {
        [.preMarketOpen, .open] + RangeStage.standard.map { .rangeStage(minutes: $0.minutes) } + [.close, .afterHoursClose]
    }

    /// Stable key for settings and sound files.
    public var key: String {
        switch self {
        case .preMarketOpen: return "premarket_open"
        case .open: return "market_open"
        case .rangeStage(let m): return "range_\(m)"
        case .close: return "market_close"
        case .afterHoursClose: return "day_close"
        }
    }

    public var title: String {
        switch self {
        case .preMarketOpen: return "Pre-market open"
        case .open: return "Market open"
        case .rangeStage(let m): return "\(m)-minute range"
        case .close: return "Market close"
        case .afterHoursClose: return "After-hours close"
        }
    }

    /// The short word used in the countdown line: "Open in 12:34".
    public var countdownTitle: String {
        switch self {
        case .preMarketOpen: return "Pre-market"
        case .open: return "Open"
        case .rangeStage(let m): return "\(m)m"
        case .close: return "Close"
        case .afterHoursClose: return "Day close"
        }
    }

    /// What is said aloud when speech is on for this event.
    public var phrase: String {
        switch self {
        case .preMarketOpen: return "Pre-market open."
        case .open: return "Market open."
        case .rangeStage(15): return "Fifteen minute range set."
        case .rangeStage(let m): return "\(spelled(m)) minutes."
        case .close: return "Market close."
        case .afterHoursClose: return "After-hours close."
        }
    }

    /// Speech is on by default for the open and the range stages only; the rest are chimes.
    public var speaksByDefault: Bool {
        switch self {
        case .open, .rangeStage: return true
        default: return false
        }
    }

    private func spelled(_ n: Int) -> String {
        let words = [5: "Five", 10: "Ten", 15: "Fifteen", 20: "Twenty", 30: "Thirty", 45: "Forty-five", 60: "Sixty"]
        return words[n] ?? String(n)
    }
}

public struct MarketEvent: Equatable, Sendable {
    public let kind: EventKind
    public let time: Date
}

extension NYSECalendar {
    /// Every event of a day, in time order; empty when the market is closed.
    public func events(on day: Day, stages: [RangeStage] = RangeStage.standard) -> [MarketEvent] {
        guard let s = session(on: day) else { return [] }
        var list = [MarketEvent(kind: .preMarketOpen, time: s.preMarketOpen), MarketEvent(kind: .open, time: s.open)]
        for stage in stages {
            list.append(MarketEvent(kind: .rangeStage(minutes: stage.minutes), time: s.open.addingTimeInterval(Double(stage.minutes) * 60)))
        }
        list.append(MarketEvent(kind: .close, time: s.close))
        list.append(MarketEvent(kind: .afterHoursClose, time: s.afterHoursClose))
        return list.sorted { $0.time < $1.time }
    }

    /// Events with `from < time <= to`, across day boundaries.
    public func events(after from: Date, through to: Date, stages: [RangeStage] = RangeStage.standard) -> [MarketEvent] {
        guard to > from else { return [] }
        var day = Day(from)
        let lastDay = Day(to)
        var found: [MarketEvent] = []
        while day <= lastDay {
            found += events(on: day, stages: stages).filter { $0.time > from && $0.time <= to }
            day = day.adding(days: 1)
        }
        return found
    }

    /// The next session boundary (not a range stage) strictly after `date`.
    public func nextBoundary(after date: Date) -> MarketEvent? {
        var day = Day(date)
        for _ in 0..<30 {
            if let e = events(on: day, stages: []).first(where: { $0.time > date }) { return e }
            day = day.adding(days: 1)
        }
        return nil
    }
}
