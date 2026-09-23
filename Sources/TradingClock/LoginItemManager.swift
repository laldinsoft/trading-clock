import Foundation
import ServiceManagement

@MainActor
enum LoginItemManager {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
