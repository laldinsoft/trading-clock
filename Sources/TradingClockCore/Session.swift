import Foundation

public enum SessionPhase: String, CaseIterable, Sendable {
    case preMarket, regular, afterHours, closed

    public var title: String {
        switch self {
        case .preMarket: return "Pre-market"
        case .regular: return "Regular hours"
        case .afterHours: return "After-hours"
        case .closed: return "Closed"
        }
    }
}

/// The four boundaries of one trading day in New York.
public struct SessionTimes: Equatable, Sendable {
    public let day: Day
    public let preMarketOpen: Date   // 04:00
    public let open: Date            // 09:30
    public let close: Date           // 16:00, or 13:00 on an early-close day
    public let afterHoursClose: Date // 20:00, or 17:00 on an early-close day
    public let isEarlyClose: Bool

    public init(day: Day, earlyClose: Bool) {
        self.day = day
        self.isEarlyClose = earlyClose
        preMarketOpen = day.at(hour: 4, minute: 0)
        open = day.at(hour: 9, minute: 30)
        close = day.at(hour: earlyClose ? 13 : 16, minute: 0)
        afterHoursClose = day.at(hour: earlyClose ? 17 : 20, minute: 0)
    }

    public func phase(at date: Date) -> SessionPhase {
        if date < preMarketOpen { return .closed }
        if date < open { return .preMarket }
        if date < close { return .regular }
        if date < afterHoursClose { return .afterHours }
        return .closed
    }
}

extension NYSECalendar {
    /// Session times for a day, or nil when the market is closed all day.
    public func session(on day: Day) -> SessionTimes? {
        guard isTradingDay(day) else { return nil }
        return SessionTimes(day: day, earlyClose: isEarlyClose(day))
    }

    public func phase(at date: Date) -> SessionPhase {
        session(on: Day(date))?.phase(at: date) ?? .closed
    }
}
