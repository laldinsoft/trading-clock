import Foundation

/// One stage of the opening range: the bar segment that ends `minutes` after the open.
public struct RangeStage: Equatable, Identifiable, Sendable {
    public let minutes: Int
    /// Short label drawn on the bar.
    public let label: String
    /// True for the stage the trader marks on the chart; drawn more prominently.
    public let isPrimary: Bool
    public var id: Int { minutes }

    public init(minutes: Int, label: String, isPrimary: Bool = false) {
        self.minutes = minutes; self.label = label; self.isPrimary = isPrimary
    }

    /// 5, 10, 15 (the ORB that gets marked) and 30 minutes after the open.
    public static let standard: [RangeStage] = [
        RangeStage(minutes: 5, label: "5m"),
        RangeStage(minutes: 10, label: "10m"),
        RangeStage(minutes: 15, label: "15m ORB", isPrimary: true),
        RangeStage(minutes: 30, label: "30m"),
    ]
}

/// Where we are inside the opening range at a given instant.
public struct RangeProgress: Equatable, Sendable {
    public let stages: [RangeStage]
    /// Index into `stages` of the stage currently filling.
    public let activeIndex: Int
    /// 0…1 across the whole bar.
    public let fraction: Double
    /// Whole seconds until the active stage ends.
    public let secondsToStageEnd: Int
    /// Seconds since the open.
    public let elapsed: TimeInterval

    public var active: RangeStage { stages[activeIndex] }
    public var totalMinutes: Int { stages.last!.minutes }

    /// The fraction of the bar where each stage begins and ends.
    public func span(of index: Int) -> (start: Double, end: Double) {
        let total = Double(totalMinutes)
        let start = index == 0 ? 0 : Double(stages[index - 1].minutes) / total
        return (start, Double(stages[index].minutes) / total)
    }

    /// Nil before the open and once the last stage has ended.
    public init?(open: Date, now: Date, stages: [RangeStage] = RangeStage.standard) {
        guard let last = stages.last, !stages.isEmpty else { return nil }
        let elapsed = now.timeIntervalSince(open)
        guard elapsed >= 0, elapsed < Double(last.minutes) * 60 else { return nil }
        let activeIndex = stages.firstIndex { elapsed < Double($0.minutes) * 60 }!
        self.stages = stages
        self.activeIndex = activeIndex
        self.elapsed = elapsed
        self.fraction = elapsed / (Double(last.minutes) * 60)
        self.secondsToStageEnd = Int((Double(stages[activeIndex].minutes) * 60 - elapsed).rounded(.up))
    }
}
