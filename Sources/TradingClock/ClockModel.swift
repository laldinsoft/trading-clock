import Foundation
import Observation
import TradingClockCore

/// Ticks once a second on the wall-clock boundary, publishes what the view needs,
/// and fires events that fell inside the last tick.
@Observable
@MainActor
final class ClockModel {
    private(set) var now = Date()
    private(set) var phase: SessionPhase = .closed
    private(set) var timeText = "00:00:00"
    private(set) var localTimeText = "00:00"
    /// "Open in 12:34", for the optional countdown.
    private(set) var countdownLine = ""
    /// "Pre-market", "Closed · Thanksgiving Day", "Open · Early close 13:00".
    private(set) var statusLine = ""
    private(set) var nextBoundary: MarketEvent?
    private(set) var range: RangeProgress?
    /// The event that just fired; cleared a few seconds later so the view can flash it.
    private(set) var justFired: EventKind?
    private(set) var holidayName: String?

    /// Simulation: added to the real time so transitions can be previewed.
    var offset: TimeInterval = 0 { didSet { lastTick = nil; tick() } }
    var isSimulating: Bool { offset != 0 }
    /// Snapshots for documentation are simulated but should not carry the badge.
    var hidesSimulationBadge = false

    var calendar = NYSECalendar(overrides: CalendarOverridesFile.load())
    let sync = CalendarSync()
    let settings: AppSettings
    let sounds: SoundPlayer
    private var timer: DispatchSourceTimer?
    private var lastTick: Date?

    private let nyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = NewYork.calendar; f.timeZone = NewYork.timeZone
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm:ss"
        return f
    }()
    private let nyShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = NewYork.calendar; f.timeZone = NewYork.timeZone
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"
        return f
    }()
    private let localFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"
        return f
    }()

    init(settings: AppSettings) {
        self.settings = settings
        self.sounds = SoundPlayer(settings: settings)
        sync.onChange = { [weak self] in self?.reloadCalendar() }
        reloadCalendar()
        tick()
    }

    /// Manual overrides file plus whatever the online check last returned.
    func reloadCalendar() {
        calendar = NYSECalendar(overrides: CalendarOverridesFile.load().merged(with: sync.remote))
        tick()
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        // Fire just after each whole second so the displayed second is always fresh.
        let next = ceil(Date().timeIntervalSince1970) + 0.02
        t.schedule(wallDeadline: DispatchWallTime(timespec: wallTimespec(next)), repeating: 1.0, leeway: .milliseconds(5))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
        sync.start()
    }

    func stop() { timer?.cancel(); timer = nil }

    /// Jump the simulated clock to `seconds` before `kind` on the next day it happens.
    func simulate(_ kind: EventKind, secondsBefore seconds: TimeInterval = 10) {
        let real = Date()
        var day = Day(real)
        for _ in 0..<30 {
            if let e = calendar.events(on: day).first(where: { $0.kind == kind && $0.time > real }) {
                offset = e.time.addingTimeInterval(-seconds).timeIntervalSince(real)
                return
            }
            day = day.adding(days: 1)
        }
    }

    func stopSimulating() { tourTask?.cancel(); tourTask = nil; offset = 0 }

    private var tourTask: Task<Void, Never>?
    var isTouring: Bool { tourTask != nil }

    /// Walks the day in about two minutes: each event ten seconds out, then a pause
    /// to see the state it leaves behind, then real time again.
    func tour() {
        tourTask?.cancel()
        let steps: [(EventKind, TimeInterval)] = [
            (.preMarketOpen, 8), (.open, 10), (.rangeStage(minutes: 5), 8), (.rangeStage(minutes: 10), 8),
            (.rangeStage(minutes: 15), 8), (.rangeStage(minutes: 30), 8), (.close, 8), (.afterHoursClose, 8),
        ]
        tourTask = Task { [weak self] in
            for (kind, lead) in steps {
                guard let self, !Task.isCancelled else { return }
                self.simulate(kind, secondsBefore: lead)
                try? await Task.sleep(for: .seconds(lead + 7))
            }
            guard let self, !Task.isCancelled else { return }
            self.tourTask = nil
            self.offset = 0
        }
    }

    private func tick() {
        let previous = lastTick
        let now = Date().addingTimeInterval(offset)
        self.now = now
        lastTick = now

        timeText = settings.showSeconds ? nyFormatter.string(from: now) : nyShortFormatter.string(from: now)
        localFormatter.timeZone = .current
        localTimeText = localFormatter.string(from: now)

        let day = Day(now)
        let session = calendar.session(on: day)
        phase = session?.phase(at: now) ?? .closed
        holidayName = session == nil && !day.isWeekend ? calendar.holidayName(day) : nil
        range = session.flatMap { RangeProgress(open: $0.open, now: now) }
        nextBoundary = calendar.nextBoundary(after: now)
        countdownLine = nextBoundary.map { Countdown.line(to: $0, from: now) } ?? ""
        statusLine = Self.status(phase: phase, session: session, day: day, holiday: holidayName)

        guard let previous else { return }
        // Only announce what fell inside a normal tick. After sleep or a simulation
        // jump the gap is large, and stale bells would be worse than none.
        guard now.timeIntervalSince(previous) < 5 else { return }
        let fired = calendar.events(after: previous, through: now)
        for event in fired { fire(event.kind) }
        // Optional candle-close tick, skipped when a real event already sounded.
        if fired.isEmpty, settings.candleTickMinutes > 0, phase == .regular, let s = session {
            let step = Double(settings.candleTickMinutes) * 60
            let before = previous.timeIntervalSince(s.open), after = now.timeIntervalSince(s.open)
            if after > 0, floor(after / step) != floor(before / step) { sounds.candleTick() }
        }
    }

    static func status(phase: SessionPhase, session: SessionTimes?, day: Day, holiday: String?) -> String {
        switch phase {
        case .preMarket: return "Pre-market"
        case .regular: return session?.isEarlyClose == true ? "Open · Early close 13:00" : "Open"
        case .afterHours: return "After-hours"
        case .closed:
            if day.isWeekend { return "Closed · Weekend" }
            if session == nil { return "Closed · \(holiday ?? "Market holiday")" }
            return "Closed"
        }
    }

    private func fire(_ kind: EventKind) {
        NSLog("Trading Clock: %@ at %@", kind.title, nyFormatter.string(from: now))
        sounds.announce(kind)
        justFired = kind
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.justFired == kind { self?.justFired = nil }
        }
    }
}

private func wallTimespec(_ interval: TimeInterval) -> timespec {
    var ts = timespec()
    ts.tv_sec = Int(interval)
    ts.tv_nsec = Int((interval - floor(interval)) * 1_000_000_000)
    return ts
}

/// `~/Library/Application Support/TradingClock/calendar-overrides.json`
enum CalendarOverridesFile {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TradingClock/calendar-overrides.json")
    }

    static func load() -> NYSECalendar.Overrides {
        guard let data = try? Data(contentsOf: url),
              let o = try? JSONDecoder().decode(NYSECalendar.Overrides.self, from: data) else { return .init() }
        return o
    }
}
