import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct SetClipboardMonitoringStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Clipboard Monitoring State"
    static let description = IntentDescription("Sets or toggles the clipboard monitoring state (pause/resume).")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "State")
    var state: MonitoringStateEnum
    
    static var parameterSummary: some ParameterSummary {
        Switch(\.$state) {
            Case(.toggle) {
                Summary("\(\.$state) Clipboard Monitoring")
            }
            DefaultCase {
                Summary("Set Clipboard Monitoring to \(\.$state)")
            }
        }
    }
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let isCurrentlyPaused = defaults.bool(forKey: "isClipboardMonitoringPaused")
            let newIsPaused: Bool
            
            switch state {
            case .pause:
                newIsPaused = true
            case .resume:
                newIsPaused = false
            case .toggle:
                newIsPaused = !isCurrentlyPaused
            }
            
            if isCurrentlyPaused != newIsPaused {
                defaults.set(newIsPaused, forKey: "isClipboardMonitoringPaused")
                NotificationManager.shared.sendMonitoringStatusNotification(isPaused: newIsPaused)
            }
        }
        
        return .result()
    }
}
