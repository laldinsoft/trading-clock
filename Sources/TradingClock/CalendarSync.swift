import Foundation
import Observation
import TradingClockCore

/// Optional online check of closures and early closes through Polygon.io (free key).
/// Runs at launch and every six hours; the last good result is cached on disk so an
/// offline launch still has it. The rule-based calendar is always the fallback.
@Observable
@MainActor
final class CalendarSync {
    private(set) var status = "Not configured"
    private(set) var lastChecked: Date?
    private(set) var remote = NYSECalendar.Overrides()
    var onChange: (() -> Void)?
    private var timer: Timer?

    static var cacheURL: URL {
        CalendarOverridesFile.url.deletingLastPathComponent().appendingPathComponent("remote-calendar.json")
    }

    private struct Cache: Codable { var checked: Date; var entries: [RemoteCalendar.Entry] }

    init() {
        if let data = try? Data(contentsOf: Self.cacheURL), let c = try? JSONDecoder().decode(Cache.self, from: data) {
            remote = RemoteCalendar.overrides(from: c.entries)
            lastChecked = c.checked
            status = "Cached \(c.entries.count) entries"
        }
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func refresh() async {
        let key = UserDefaults.standard.string(forKey: "polygonAPIKey")?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !key.isEmpty else { status = "Not configured"; return }
        status = "Checking…"
        var comps = URLComponents(url: RemoteCalendar.endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "apiKey", value: key)]
        do {
            let (data, response) = try await URLSession.shared.data(from: comps.url!)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = "Failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            let entries = try RemoteCalendar.parse(data)
            remote = RemoteCalendar.overrides(from: entries)
            lastChecked = Date()
            status = "\(remote.closed.count) closures, \(remote.earlyClose.count) early closes listed"
            let cache = Cache(checked: Date(), entries: entries)
            try? FileManager.default.createDirectory(at: Self.cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? JSONEncoder().encode(cache).write(to: Self.cacheURL)
            onChange?()
        } catch {
            status = "Failed: \(error.localizedDescription)"
        }
    }
}

