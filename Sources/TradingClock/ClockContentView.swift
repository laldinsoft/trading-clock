import AppKit
import SwiftUI

/// Hosts the SwiftUI clock and owns the mouse: a drag anywhere moves the panel, a drag
/// within `edge` points of a side or corner resizes it. NSHostingView keeps mouse
/// events for SwiftUI, so a borderless panel gets neither behaviour for free.
final class ClockContentView: NSHostingView<ClockView> {
    private let edge: CGFloat = 10
    private var resizeEdges: NSRectEdgeSet = []
    private var startFrame = NSRect.zero
    private var startMouse = NSPoint.zero
    private var trackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        resizeEdges = edges(at: convert(event.locationInWindow, from: nil))
        if resizeEdges.isEmpty {
            window.performDrag(with: event)
            return
        }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, !resizeEdges.isEmpty else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - startMouse.x, dy = mouse.y - startMouse.y
        var f = startFrame
        let minW = window.minSize.width, minH = window.minSize.height
        if resizeEdges.contains(.right) { f.size.width = max(minW, startFrame.width + dx) }
        if resizeEdges.contains(.left) {
            let w = max(minW, startFrame.width - dx)
            f.origin.x = startFrame.maxX - w; f.size.width = w
        }
        if resizeEdges.contains(.top) { f.size.height = max(minH, startFrame.height + dy) }
        if resizeEdges.contains(.bottom) {
            let h = max(minH, startFrame.height - dy)
            f.origin.y = startFrame.maxY - h; f.size.height = h
        }
        window.setFrame(f, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if !resizeEdges.isEmpty { window?.saveFrame(usingName: "ClockPanel") }
        resizeEdges = []
    }

    // Resize cursors near the edges.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        cursor(for: edges(at: convert(event.locationInWindow, from: nil))).set()
    }

    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    private func cursor(for e: NSRectEdgeSet) -> NSCursor {
        if #available(macOS 15, *) {
            switch e {
            case [.top, .left]: return .frameResize(position: .topLeft, directions: .all)
            case [.top, .right]: return .frameResize(position: .topRight, directions: .all)
            case [.bottom, .left]: return .frameResize(position: .bottomLeft, directions: .all)
            case [.bottom, .right]: return .frameResize(position: .bottomRight, directions: .all)
            case [.left]: return .frameResize(position: .left, directions: .all)
            case [.right]: return .frameResize(position: .right, directions: .all)
            case [.top]: return .frameResize(position: .top, directions: .all)
            case [.bottom]: return .frameResize(position: .bottom, directions: .all)
            default: return .arrow
            }
        }
        let horizontal = !e.isDisjoint(with: [.left, .right]), vertical = !e.isDisjoint(with: [.top, .bottom])
        switch (horizontal, vertical) {
        case (true, true): return .crosshair
        case (true, false): return .resizeLeftRight
        case (false, true): return .resizeUpDown
        default: return .arrow
        }
    }

    /// Edges under a point in this view's coordinates. NSHostingView is flipped
    /// (y grows downward), so the small y values are at the top.
    private func edges(at p: NSPoint) -> NSRectEdgeSet {
        var e: NSRectEdgeSet = []
        if p.x <= edge { e.insert(.left) }
        if p.x >= bounds.width - edge { e.insert(.right) }
        let nearLowY = p.y <= edge, nearHighY = p.y >= bounds.height - edge
        if isFlipped ? nearLowY : nearHighY { e.insert(.top) }
        if isFlipped ? nearHighY : nearLowY { e.insert(.bottom) }
        return e
    }
}

struct NSRectEdgeSet: OptionSet, Equatable {
    let rawValue: Int
    static let left = NSRectEdgeSet(rawValue: 1), right = NSRectEdgeSet(rawValue: 2)
    static let top = NSRectEdgeSet(rawValue: 4), bottom = NSRectEdgeSet(rawValue: 8)
}
