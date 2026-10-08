import Foundation
import Observation
import TradingClockCore

/// Optional daily check of the official UK and Japanese holiday lists, so one-off days
/// (a coronation, a state funeral) reach the London and Tokyo chips. No key needed.
/// The last good result is cached on disk; the rules are always the fallback.
@Observable
@MainActor
final class WorldHolidaySync {
    private(set) var status = "Off"
    private(set) var lastChecked: Date?
    private(set) var remote: [WorldMarket.Exchange: NYSECalendar.Overrides] = [:]
    var onChange: (() -> Void)?
    private var timer: Timer?
    private var cache = Cache()

    static var cacheURL: URL {
        CalendarOverridesFile.url.deletingLastPathComponent().appendingPathComponent("world-holidays.json")
    }

    private struct Cache: Codable { var checked: Date?; var uk: [String] = []; var japan: [String] = [] }

    private var enabled: Bool { UserDefaults.standard.bool(forKey: "checkWorldHolidays") }

    init() {
        if let data = try? Data(contentsOf: Self.cacheURL), let c = try? JSONDecoder().decode(Cache.self, from: data) {
            cache = c
            lastChecked = c.checked
        }
        apply()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    /// Turning the check off drops the online days straight away; turning it on fetches.
    func enabledChanged() {
        apply()
        onChange?()
        Task { await refresh() }
    }

    func refresh() async {
        guard enabled else { status = "Off"; return }
        status = "Checking…"
        async let uk = fetch(WorldHolidayFeed.ukURL) { try WorldHolidayFeed.parseUK($0) }
        async let japan = fetch(WorldHolidayFeed.japanURL) { try WorldHolidayFeed.parseJapan($0) }
        let (u, j) = await (uk, japan)
        // Keep the previous list for a feed that failed this time.
        if case .success(let days) = u { cache.uk = days }
        if case .success(let days) = j { cache.japan = days }
        let failures = [("GOV.UK", u), ("Japan", j)].compactMap { name, r -> String? in
            if case .failure(let e) = r { return "\(name): \(e.localizedDescription)" } else { return nil }
        }
        if failures.count < 2 {
            cache.checked = Date()
            lastChecked = cache.checked
            try? FileManager.default.createDirectory(at: Self.cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? JSONEncoder().encode(cache).write(to: Self.cacheURL)
        }
        apply()
        onChange?()
        if !failures.isEmpty { status = "Failed: " + failures.joined(separator: "; ") }
    }

    private func apply() {
        guard enabled else { remote = [:]; status = "Off"; return }
        remote = [.london: WorldHolidayFeed.overrides(for: .london, days: cache.uk),
                  .tokyo: WorldHolidayFeed.overrides(for: .tokyo, days: cache.japan)]
        status = "\(cache.uk.count) UK and \(cache.japan.count) Japanese holidays listed"
    }

    private func fetch(_ url: URL, _ parse: @Sendable (Data) throws -> [String]) async -> Result<[String], Error> {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            return .success(try parse(data))
        } catch {
            return .failure(error)
        }
    }
}
