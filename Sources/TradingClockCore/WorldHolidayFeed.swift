import Foundation

/// The official holiday lists behind London and Tokyo, both free and keyless:
/// GOV.UK's bank holidays (England and Wales, which the LSE follows) and the Japanese
/// Cabinet Office's national holidays CSV. They add one-off days the rules cannot
/// predict, such as a coronation or a state funeral.
public enum WorldHolidayFeed {
    public static let ukURL = URL(string: "https://www.gov.uk/bank-holidays.json")!
    public static let japanURL = URL(string: "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv")!

    /// `{"england-and-wales": {"events": [{"title": "Boxing Day", "date": "2026-12-28"}, …]}, …}`
    public static func parseUK(_ data: Data) throws -> [String] {
        struct Event: Decodable { let date: String }
        struct Division: Decodable { let events: [Event] }
        let all = try JSONDecoder().decode([String: Division].self, from: data)
        guard let ew = all["england-and-wales"] else { throw CocoaError(.coderValueNotFound) }
        return ew.events.compactMap { Day(iso: $0.date)?.description }.sorted()
    }

    /// Shift_JIS CSV, one `2026/9/22,休日` row per holiday after a header row.
    public static func parseJapan(_ data: Data) throws -> [String] {
        guard let text = String(data: data, encoding: .shiftJIS) ?? String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        let days = text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let p = line.split(separator: ",").first?.split(separator: "/").compactMap { Int($0) } ?? []
            return p.count == 3 ? Day(p[0], p[1], p[2]).description : nil
        }
        guard !days.isEmpty else { throw CocoaError(.coderValueNotFound) }
        return days.sorted()
    }

    /// Overrides that make the market follow the feed for every year it covers: the
    /// feed's days are closed, and rule holidays it doesn't list are open. Tokyo's
    /// year-end closure belongs to the exchange, not the national list, so it stays.
    public static func overrides(for exchange: WorldMarket.Exchange, days: [String]) -> NYSECalendar.Overrides {
        let feed = Set(days)
        let years = Set(days.compactMap { Day(iso: $0)?.year })
        let market = WorldMarket(exchange)
        let unlisted = years.flatMap { market.holidays(year: $0) }
            .filter { $0.name != "Year-end Holiday" && !feed.contains($0.day.description) }
            .map(\.day.description)
        return NYSECalendar.Overrides(closed: feed.sorted(), open: unlisted.sorted())
    }
}

extension NYSECalendar.Overrides {
    /// Manual entries on top of online ones: a day the user marks closed or half-day
    /// is never reopened by the feed.
    public func layered(over remote: NYSECalendar.Overrides) -> NYSECalendar.Overrides {
        let mine = Set(closed + earlyClose)
        return NYSECalendar.Overrides(
            closed: Array(Set(closed + remote.closed)).sorted(),
            earlyClose: Array(Set(earlyClose + remote.earlyClose)).sorted(),
            open: Array(Set(open + remote.open.filter { !mine.contains($0) })).sorted())
    }
}
