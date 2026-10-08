import Foundation

public enum Countdown {
    /// "12:34" under an hour, "1:02:03" above, "2d 4h" beyond a day.
    public static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        if s >= 86_400 { return "\(s / 86_400)d \((s % 86_400) / 3600)h" }
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "3h 15m", or "45m" under an hour, rounded up to the minute; for the market chips.
    public static func short(_ seconds: TimeInterval) -> String {
        let m = max(0, Int((seconds / 60).rounded(.up)))
        return m >= 60 ? String(format: "%dh %02dm", m / 60, m % 60) : "\(m)m"
    }

    /// "Open in 12:34", or "Open Mon 09:30" when it is more than a day away.
    public static func line(to event: MarketEvent, from now: Date) -> String {
        let remaining = event.time.timeIntervalSince(now)
        if remaining >= 86_400 {
            let f = DateFormatter()
            f.calendar = NewYork.calendar
            f.timeZone = NewYork.timeZone
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "EEE HH:mm"
            return "\(event.kind.countdownTitle) \(f.string(from: event.time))"
        }
        return "\(event.kind.countdownTitle) in \(format(remaining))"
    }
}
