import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct SetQuickPasteStateIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Quick Paste State"
    static let description = IntentDescription("Sets or toggles the quick paste state (enable/disable).")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "State")
    var state: ToggleStateEnum
    
    static var parameterSummary: some ParameterSummary {
        Switch(\.$state) {
            Case(.toggle) {
                Summary("\(\.$state) Quick Paste")
            }
            DefaultCase {
                Summary("Set Quick Paste to \(\.$state)")
            }
        }
    }
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let isCurrentlyEnabled = defaults.bool(forKey: "quickPaste")
            let newIsEnabled: Bool
            
            switch state {
            case .enable:
                newIsEnabled = true
            case .disable:
                newIsEnabled = false
            case .toggle:
                newIsEnabled = !isCurrentlyEnabled
            }
            
            if isCurrentlyEnabled != newIsEnabled {
                defaults.set(newIsEnabled, forKey: "quickPaste")
            }
        }
        
        return .result()
    }
}
