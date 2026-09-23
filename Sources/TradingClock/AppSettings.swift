import Foundation
import Observation
import TradingClockCore

/// User preferences, persisted in UserDefaults as they change.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    var volume: Double { didSet { d.set(volume, forKey: "volume") } }
    var muted: Bool { didSet { d.set(muted, forKey: "muted") } }
    var opacity: Double { didSet { d.set(opacity, forKey: "opacity") } }
    var clickThrough: Bool { didSet { d.set(clickThrough, forKey: "clickThrough") } }
    var showLocalTime: Bool { didSet { d.set(showLocalTime, forKey: "showLocalTime") } }
    var showSeconds: Bool { didSet { d.set(showSeconds, forKey: "showSeconds") } }
    var showInfoLine: Bool { didSet { d.set(showInfoLine, forKey: "showInfoLine") } }
    /// Countdown to the next boundary instead of the session name.
    var showCountdown: Bool { didSet { d.set(showCountdown, forKey: "showCountdown") } }
    /// 0 = off; otherwise a soft tick at every N-minute candle close during regular hours.
    var candleTickMinutes: Int { didSet { d.set(candleTickMinutes, forKey: "candleTickMinutes") } }
    /// Polygon.io key for the optional online holiday check; empty means off.
    var polygonAPIKey: String { didSet { d.set(polygonAPIKey, forKey: "polygonAPIKey") } }
    private var silentEvents: Set<String> { didSet { d.set(Array(silentEvents), forKey: "silentEvents") } }
    private var spokenEvents: Set<String> { didSet { d.set(Array(spokenEvents), forKey: "spokenEvents") } }

    private init() {
        d.register(defaults: ["volume": 0.5, "opacity": 0.85, "showLocalTime": true, "showSeconds": true, "showInfoLine": true,
                              "spokenEvents": EventKind.allCases.filter(\.speaksByDefault).map(\.key)])
        volume = d.double(forKey: "volume")
        muted = d.bool(forKey: "muted")
        opacity = d.double(forKey: "opacity")
        clickThrough = d.bool(forKey: "clickThrough")
        showLocalTime = d.bool(forKey: "showLocalTime")
        showSeconds = d.bool(forKey: "showSeconds")
        showInfoLine = d.bool(forKey: "showInfoLine")
        showCountdown = d.bool(forKey: "showCountdown")
        candleTickMinutes = d.integer(forKey: "candleTickMinutes")
        polygonAPIKey = d.string(forKey: "polygonAPIKey") ?? ""
        silentEvents = Set(d.stringArray(forKey: "silentEvents") ?? [])
        spokenEvents = Set(d.stringArray(forKey: "spokenEvents") ?? [])
    }

    func chimes(_ kind: EventKind) -> Bool { !silentEvents.contains(kind.key) }
    func setChimes(_ kind: EventKind, _ on: Bool) { if on { silentEvents.remove(kind.key) } else { silentEvents.insert(kind.key) } }
    func speaks(_ kind: EventKind) -> Bool { spokenEvents.contains(kind.key) }
    func setSpeaks(_ kind: EventKind, _ on: Bool) { if on { spokenEvents.insert(kind.key) } else { spokenEvents.remove(kind.key) } }
}
