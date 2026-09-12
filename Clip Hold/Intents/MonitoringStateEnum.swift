import Foundation
import AppIntents

@available(macOS 14.0, *)
enum MonitoringStateEnum: String, AppEnum {
    case pause
    case resume
    case toggle
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Monitoring State"
    static let caseDisplayRepresentations: [MonitoringStateEnum: DisplayRepresentation] = [
        .pause: "Pause",
        .resume: "Resume",
        .toggle: "Toggle"
    ]
}
