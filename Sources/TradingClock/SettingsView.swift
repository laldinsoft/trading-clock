import SwiftUI
import TradingClockCore

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let model: ClockModel

    @State private var keyCheck: Task<Void, Never>?

    private var syncStatus: String {
        guard let t = model.sync.lastChecked else { return model.sync.status }
        return "\(model.sync.status) · checked \(t.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Mute everything", isOn: $settings.muted)
                Slider(value: $settings.volume, in: 0...1) { Text("Volume") }
                Picker("Candle-close tick", selection: $settings.candleTickMinutes) {
                    Text("Off").tag(0); Text("Every 5 min").tag(5); Text("Every 15 min").tag(15)
                }
                Text("A soft tick at each candle close during regular hours.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Events") {
                Grid(alignment: .leading, verticalSpacing: 6) {
                    GridRow {
                        Text("").gridCellUnsizedAxes(.horizontal)
                        Text("Chime").font(.caption).foregroundStyle(.secondary)
                        Text("Speak").font(.caption).foregroundStyle(.secondary)
                        Text("").gridCellUnsizedAxes(.horizontal)
                    }
                    ForEach(EventKind.allCases, id: \.key) { kind in
                        GridRow {
                            Text(kind.title).frame(minWidth: 150, alignment: .leading)
                            Toggle("", isOn: Binding(get: { settings.chimes(kind) }, set: { settings.setChimes(kind, $0) })).labelsHidden()
                            Toggle("", isOn: Binding(get: { settings.speaks(kind) }, set: { settings.setSpeaks(kind, $0) })).labelsHidden()
                            Button("Play") { model.sounds.preview(kind) }.controlSize(.small)
                        }
                    }
                }
                Text("Spoken: “\(EventKind.rangeStage(minutes: 15).phrase)” and similar short phrases.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Window") {
                Slider(value: $settings.opacity, in: 0.2...1) { Text("Background opacity") }
                Toggle("Click-through (clicks go to the window beneath)", isOn: $settings.clickThrough)
                Toggle("Show seconds", isOn: $settings.showSeconds)
                Toggle("Show local time", isOn: $settings.showLocalTime)
                Toggle("Show session line and range bar", isOn: $settings.showInfoLine)
                Toggle("Countdown to the next boundary instead of the session name", isOn: $settings.showCountdown)
                    .disabled(!settings.showInfoLine)
                Text("Drag anywhere to move; drag an edge to resize. Right-click for the menu.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Calendar") {
                Text("NYSE holidays and 13:00 closes are computed from the exchange rules, so nothing needs updating each year. Two optional layers catch unscheduled closures:")
                    .font(.caption).foregroundStyle(.secondary)
                SecureField("Polygon.io API key", text: $settings.polygonAPIKey, prompt: Text("paste your free Polygon.io key here"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.sync.refresh() } }
                    .onChange(of: settings.polygonAPIKey) { _, _ in
                        // Check shortly after the key stops changing, so a paste checks itself.
                        keyCheck?.cancel()
                        keyCheck = Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            guard !Task.isCancelled else { return }
                            await model.sync.refresh()
                        }
                    }
                HStack {
                    Text(syncStatus).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Check now") { Task { await model.sync.refresh() } }.controlSize(.small)
                        .disabled(settings.polygonAPIKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Polygon's free plan lists closures and early closes as the exchange announces them. The key is stored only on this Mac and checked at launch and every six hours.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Manual overrides") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(CalendarOverridesFile.url.path).font(.caption.monospaced()).textSelection(.enabled)
                        Button("Reload") { model.reloadCalendar() }.controlSize(.small)
                    }
                }
                Text("A JSON file with \"closed\", \"earlyClose\" and \"open\" lists of ISO dates.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
    }
}
