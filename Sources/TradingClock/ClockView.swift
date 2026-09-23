import SwiftUI
import TradingClockCore

/// The whole window: big New York time, tiny local time beside it, and one info line
/// underneath that is either the countdown to the next boundary or the opening-range bar.
struct ClockView: View {
    @Bindable var model: ClockModel
    @Bindable var settings: AppSettings

    var body: some View {
        GeometryReader { geo in
            let layout = Layout(size: geo.size, showInfo: settings.showInfoLine, showLocal: settings.showLocalTime, showSeconds: settings.showSeconds)
            VStack(spacing: layout.gap) {
                HStack(alignment: .center, spacing: layout.digit * 0.35) {
                    Text(model.timeText)
                        .font(.system(size: layout.digit, weight: .medium, design: .default).monospacedDigit())
                        .foregroundStyle(digitColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .shadow(color: flashColor.opacity(model.justFired == nil ? 0 : 0.9), radius: layout.digit * 0.25)
                        .animation(.easeOut(duration: 0.6), value: model.justFired)
                    if settings.showLocalTime { localTime(layout) }
                }
                if settings.showInfoLine {
                    infoLine(layout)
                        .frame(height: layout.info)
                }
            }
            .padding(.horizontal, layout.padding)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Theme.background.opacity(settings.opacity))
        .overlay(alignment: .topTrailing) {
            if model.isSimulating && !model.hidesSimulationBadge {
                Text("SIM")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: 0xE06060))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color(hex: 0xE06060).opacity(0.15), in: Capsule())
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var digitColor: Color {
        model.isSimulating ? Theme.digits(for: model.phase).opacity(0.9) : Theme.digits(for: model.phase)
    }

    private var flashColor: Color { model.justFired.map(Theme.event) ?? .clear }

    private func localTime(_ layout: Layout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LOCAL")
                .font(.system(size: layout.digit * 0.13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.secondary.opacity(0.7))
            Text(model.localTimeText)
                .font(.system(size: layout.digit * 0.28, weight: .regular).monospacedDigit())
                .foregroundStyle(Theme.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.3)
    }

    @ViewBuilder
    private func infoLine(_ layout: Layout) -> some View {
        if let range = model.range {
            RangeBar(progress: range, height: layout.info)
        } else if settings.showCountdown {
            Text(model.countdownLine)
                .foregroundStyle(Theme.secondary)
                .font(.system(size: layout.info * 0.62, weight: .medium).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        } else {
            Text(model.statusLine)
                .foregroundStyle(Theme.digits(for: model.phase).opacity(0.55))
                .font(.system(size: layout.info * 0.58, weight: .semibold))
                .tracking(layout.info * 0.04)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
    }

    /// Font and row sizes derived from the window so the clock fills whatever size it is given.
    struct Layout {
        let digit: CGFloat, info: CGFloat, gap: CGFloat, padding: CGFloat
        init(size: CGSize, showInfo: Bool, showLocal: Bool, showSeconds: Bool) {
            // Width in ems the time needs: eight monospaced glyphs (six digits + two colons) and the local block.
            let ems: CGFloat = (showSeconds ? 4.1 : 2.6) + (showLocal ? 1.1 : 0)
            let infoShare: CGFloat = showInfo ? 0.32 : 0
            let byHeight = size.height * 0.92 / (1.05 + infoShare)
            let byWidth = (size.width - 24) / ems
            digit = max(12, min(byHeight, byWidth))
            info = showInfo ? digit * 0.28 : 0
            gap = showInfo ? digit * 0.02 : 0
            padding = 12
        }
    }
}

/// Four segments, 5 / 10 / 15 / 30 minutes wide in proportion, each with its own colour.
/// The sweep fills left to right; the active segment carries its countdown.
struct RangeBar: View {
    let progress: RangeProgress
    let height: CGFloat

    var body: some View {
        let barH = max(4, height * 0.28)
        let labelSize = height * 0.5
        VStack(spacing: height * 0.1) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track, split into the four stage segments.
                    HStack(spacing: 2) {
                        ForEach(Array(progress.stages.enumerated()), id: \.element.id) { i, stage in
                            let span = progress.span(of: i)
                            Capsule()
                                .fill(Theme.stage(stage).opacity(i == progress.activeIndex ? 0.28 : 0.14))
                                .frame(width: max(0, w * (span.end - span.start) - 2))
                        }
                    }
                    // Fill.
                    ForEach(Array(progress.stages.enumerated()), id: \.element.id) { i, stage in
                        let span = progress.span(of: i)
                        let filled = min(max(progress.fraction, span.start), span.end) - span.start
                        if filled > 0 {
                            Capsule()
                                .fill(Theme.stage(stage))
                                .frame(width: max(0, w * filled - (filled >= span.end - span.start ? 2 : 0)))
                                .offset(x: w * span.start)
                        }
                    }
                }
                .frame(height: barH)
                .animation(.linear(duration: 1), value: progress.fraction)
            }
            .frame(height: barH)

            // Labels under each segment's right edge; the active one shows the countdown.
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(Array(progress.stages.enumerated()), id: \.element.id) { i, stage in
                        let span = progress.span(of: i)
                        let isActive = i == progress.activeIndex
                        let done = i < progress.activeIndex
                        let width = w * (span.end - span.start)
                        Text(isActive ? "\(stage.label) in \(Countdown.format(Double(progress.secondsToStageEnd)))" : stage.label)
                            .font(.system(size: labelSize, weight: isActive || stage.isPrimary ? .semibold : .regular).monospacedDigit())
                            .foregroundStyle(Theme.stage(stage).opacity(done ? 0.45 : isActive ? 1 : 0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: max(0, width), alignment: isActive ? .center : .trailing)
                            .offset(x: w * span.start)
                    }
                }
            }
            .frame(height: labelSize * 1.2)
        }
    }
}
