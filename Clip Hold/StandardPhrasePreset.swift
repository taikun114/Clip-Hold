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
}