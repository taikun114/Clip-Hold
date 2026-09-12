import Foundation
import AppIntents

@available(macOS 14.0, *)
enum ToggleStateEnum: String, AppEnum {
    case enable
    case disable
    case toggle
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "State"
    static let caseDisplayRepresentations: [ToggleStateEnum: DisplayRepresentation] = [
        .enable: "Enable",
        .disable: "Disable",
        .toggle: "Toggle"
    ]
}
