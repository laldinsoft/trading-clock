import AppKit
import SwiftUI
import TradingClockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings.shared
    private lazy var model = ClockModel(settings: settings)
    private var panel: ClockPanel!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let menu = NSMenu()
    private var muteItem: NSMenuItem!, clickThroughItem: NSMenuItem!, loginItem: NSMenuItem!, showItem: NSMenuItem!, realTimeItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        panel = ClockPanel(model: model, settings: settings, menu: menu)
        panel.ignoresMouseEvents = settings.clickThrough
        panel.orderFrontRegardless()
        model.start()
        applyLaunchArguments()
        snapshotIfRequested()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Trading Clock")
        statusItem.menu = menu

        // Keep the panel in step with settings changed from the Settings window.
        withObservationTracking { _ = settings.clickThrough } onChange: { [weak self] in
            DispatchQueue.main.async { self?.syncClickThrough() }
        }
    }

    /// `--simulate <event key> [seconds before]` starts the clock just before an event,
    /// for screenshots and for checking a transition without waiting for it.
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        if args.contains("--tour") { model.tour(); return }
        guard let i = args.firstIndex(of: "--simulate"), i + 1 < args.count,
              let kind = EventKind.allCases.first(where: { $0.key == args[i + 1] }) else { return }
        let seconds = i + 2 < args.count ? TimeInterval(args[i + 2]) ?? 10 : 10
        model.simulate(kind, secondsBefore: seconds)
    }

    /// `--snapshot <png path> [width height]` renders the clock view to a file and quits.
    /// Used to check the layout at different sizes without screen-recording permission.
    private func snapshotIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let width = i + 2 < args.count ? Double(args[i + 2]) ?? 420 : 420
        let height = i + 3 < args.count ? Double(args[i + 3]) ?? 150 : 150
        model.hidesSimulationBadge = true
        let view = ClockView(model: model, settings: settings).frame(width: width, height: height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let cg = renderer.cgImage {
            let rep = NSBitmapImageRep(cgImage: cg)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1]))
        }
        NSApp.terminate(nil)
    }

    private func syncClickThrough() {
        panel.ignoresMouseEvents = settings.clickThrough
        withObservationTracking { _ = settings.clickThrough } onChange: { [weak self] in
            DispatchQueue.main.async { self?.syncClickThrough() }
        }
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        showItem = add("Hide Clock", #selector(toggleClock), key: "h")
        muteItem = add("Mute", #selector(toggleMute), key: "m")
        clickThroughItem = add("Click-Through", #selector(toggleClickThrough), key: "t")
        menu.addItem(.separator())

        let test = NSMenu()
        for kind in EventKind.allCases {
            let i = NSMenuItem(title: kind.title, action: #selector(testSound(_:)), keyEquivalent: "")
            i.target = self; i.representedObject = kind.key
            test.addItem(i)
        }
        let testItem = NSMenuItem(title: "Test Sounds", action: nil, keyEquivalent: "")
        menu.addItem(testItem); menu.setSubmenu(test, for: testItem)

        let sim = NSMenu()
        for kind in EventKind.allCases {
            let i = NSMenuItem(title: "10 s before \(kind.title.lowercased())", action: #selector(simulate(_:)), keyEquivalent: "")
            i.target = self; i.representedObject = kind.key
            sim.addItem(i)
        }
        sim.addItem(.separator())
        let tour = NSMenuItem(title: "Tour the Day (2 min)", action: #selector(startTour), keyEquivalent: "")
        tour.target = self
        sim.addItem(tour)
        realTimeItem = NSMenuItem(title: "Back to Real Time", action: #selector(stopSimulating), keyEquivalent: "")
        realTimeItem.target = self
        sim.addItem(realTimeItem)
        let simItem = NSMenuItem(title: "Simulate", action: nil, keyEquivalent: "")
        menu.addItem(simItem); menu.setSubmenu(sim, for: simItem)
        menu.addItem(.separator())

        add("Settings…", #selector(openSettings), key: ",")
        loginItem = add("Launch at Login", #selector(toggleLogin), key: "")
        menu.addItem(.separator())
        add("Quit Trading Clock", #selector(quit), key: "q")
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        menu.addItem(i)
        return i
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        showItem.title = panel.isVisible ? "Hide Clock" : "Show Clock"
        muteItem.state = settings.muted ? .on : .off
        clickThroughItem.state = settings.clickThrough ? .on : .off
        loginItem.state = LoginItemManager.isEnabled ? .on : .off
        realTimeItem.isEnabled = model.isSimulating
    }

    @objc private func toggleClock() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }
    @objc private func toggleMute() { settings.muted.toggle() }
    @objc private func toggleClickThrough() { settings.clickThrough.toggle() }
    @objc private func testSound(_ sender: NSMenuItem) {
        if let kind = kind(from: sender) { model.sounds.preview(kind) }
    }
    @objc private func simulate(_ sender: NSMenuItem) {
        if let kind = kind(from: sender) { model.simulate(kind) }
    }
    @objc private func stopSimulating() { model.stopSimulating() }
    @objc private func startTour() { model.tour() }
    @objc private func toggleLogin() {
        do { try LoginItemManager.setEnabled(!LoginItemManager.isEnabled) } catch {
            let a = NSAlert(); a.messageText = "Launch at Login"
            a.informativeText = LoginItemManager.needsApproval
                ? "Allow Trading Clock in System Settings → General → Login Items & Extensions."
                : error.localizedDescription
            a.runModal()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Trading Clock Settings"
            w.contentView = NSHostingView(rootView: SettingsView(settings: settings, model: model))
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func kind(from item: NSMenuItem) -> EventKind? {
        guard let key = item.representedObject as? String else { return nil }
        return EventKind.allCases.first { $0.key == key }
    }
}
