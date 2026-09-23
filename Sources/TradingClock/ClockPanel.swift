import AppKit
import SwiftUI
import TradingClockCore

/// A borderless panel that floats above every window and every Space, including
/// full-screen apps, and never takes focus away from the chart. Moving and resizing
/// are handled by `ClockContentView`.
final class ClockPanel: NSPanel {
    init(model: ClockModel, settings: AppSettings, menu: NSMenu) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 160, height: 44)
        animationBehavior = .none
        titleVisibility = .hidden

        let host = ClockContentView(rootView: ClockView(model: model, settings: settings))
        host.menu = menu
        contentView = host

        setFrameAutosaveName("ClockPanel")
        if !setFrameUsingName("ClockPanel"), let screen = NSScreen.main {
            let v = screen.visibleFrame
            setFrameOrigin(NSPoint(x: v.maxX - frame.width - 24, y: v.maxY - frame.height - 24))
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
