import Foundation

/// Parses Polygon.io's `GET /v1/marketstatus/upcoming` into calendar overrides.
/// The rules in `NYSECalendar` already cover the scheduled holidays; what this adds is
/// anything announced later, such as a national day of mourning.
///
/// Response shape (one entry per exchange per holiday):
/// `[{"date":"2026-11-27","exchange":"NYSE","name":"Thanksgiving","status":"early-close",
///    "open":"2026-11-27T14:30:00.000Z","close":"2026-11-27T18:00:00.000Z"}, …]`
public enum RemoteCalendar {
    public static let endpoint = URL(string: "https://api.polygon.io/v1/marketstatus/upcoming")!

    public struct Entry: Codable, Equatable, Sendable {
        public let date: String
        public let exchange: String
        public let name: String
        public let status: String
    }

    public static func parse(_ data: Data) throws -> [Entry] {
        try JSONDecoder().decode([Entry].self, from: data)
    }

    /// NYSE closures and early closes from the feed, as overrides to merge in.
    public static func overrides(from entries: [Entry]) -> NYSECalendar.Overrides {
        var o = NYSECalendar.Overrides()
        for e in entries where e.exchange.uppercased() == "NYSE" && Day(iso: e.date) != nil {
            switch e.status.lowercased() {
            case "closed": o.closed.append(e.date)
            case "early-close": o.earlyClose.append(e.date)
            default: break
            }
        }
        o.closed = Array(Set(o.closed)).sorted()
        o.earlyClose = Array(Set(o.earlyClose)).sorted()
        return o
    }
}

extension NYSECalendar.Overrides {
    /// The union of two override sets; manual `open` days win over remote closures.
    public func merged(with other: NYSECalendar.Overrides) -> NYSECalendar.Overrides {
        NYSECalendar.Overrides(
            closed: Array(Set(closed + other.closed)).sorted(),
            earlyClose: Array(Set(earlyClose + other.earlyClose)).sorted(),
            open: Array(Set(open + other.open)).sorted())
    }
}
