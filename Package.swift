// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TradingClock",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TradingClock", targets: ["TradingClock"])],
    targets: [
        // Pure logic: the NYSE calendar, session phases, events and the opening-range stages.
        // No AppKit, so it is fully unit-tested.
        .target(name: "TradingClockCore"),
        .executableTarget(name: "TradingClock", dependencies: ["TradingClockCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("SwiftUI"),
            .linkedFramework("AVFoundation"), .linkedFramework("ServiceManagement")
        ]),
        .testTarget(name: "TradingClockCoreTests", dependencies: ["TradingClockCore"])
    ]
)
