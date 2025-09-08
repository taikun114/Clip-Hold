import Foundation

struct StandardPhrasePreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var phrases: [StandardPhrase]
    
    init(id: UUID = UUID(), name: String, phrases: [StandardPhrase] = []) {
        self.id = id
        self.name = name
        self.phrases = phrases
    }
    
    var displayName: String {
        if id.uuidString == "00000000-0000-0000-0000-000000000000" {
            return String(localized: "Default")
        } else {
            return name
        }
    }
}