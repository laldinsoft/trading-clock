import SwiftUI
import TradingClockCore

/// Colours chosen for glance-reading during a session: low-arousal cool tones while
/// preparing, the brightest neutral while live, a warm wind-down, and a dim rest.
enum Theme {
    static let background = Color(hex: 0x0F1114)

    static func digits(for phase: SessionPhase) -> Color {
        switch phase {
        case .preMarket: return Color(hex: 0x8FB0D6)   // slate blue: calm, "prepare"
        case .regular: return Color(hex: 0xF4F2EC)     // warm white: maximum legibility, "live"
        case .afterHours: return Color(hex: 0xD9A65A)  // amber: winding down
        case .closed: return Color(hex: 0x6C7178)      // dim grey: rest
        }
    }

    static let secondary = Color(hex: 0x8A9099)
    static let track = Color.white.opacity(0.10)

    /// Each opening-range stage keeps its own hue so the eye learns them:
    /// teal, blue, gold for the one that gets marked, violet for the last.
    static func stage(_ stage: RangeStage) -> Color {
        switch stage.minutes {
        case 5: return Color(hex: 0x4FB8A8)
        case 10: return Color(hex: 0x5C9BE0)
        case 15: return Color(hex: 0xE8BE4F)
        default: return Color(hex: 0xA98BE6)
        }
    }

    static func event(_ kind: EventKind) -> Color {
        switch kind {
        case .preMarketOpen: return digits(for: .preMarket)
        case .open: return digits(for: .regular)
        case .rangeStage(let m): return stage(RangeStage.standard.first { $0.minutes == m } ?? RangeStage(minutes: m, label: ""))
        case .close: return digits(for: .afterHours)
        case .afterHoursClose: return digits(for: .closed)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
