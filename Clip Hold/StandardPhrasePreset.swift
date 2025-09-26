import Foundation

struct PresetCustomColor: Codable {
    var background: String
    var icon: String
}

struct StandardPhrasePreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var phrases: [StandardPhrase]
    var icon: String
    var color: String
    var customColor: PresetCustomColor?
    
    init(id: UUID = UUID(), name: String, phrases: [StandardPhrase] = [], icon: String? = nil, color: String? = nil, customColor: PresetCustomColor? = nil) {
        self.id = id
        self.name = name
        self.phrases = phrases
        // デフォルトプリセットの場合
        if id.uuidString == "00000000-0000-0000-0000-000000000000" {
            self.icon = icon ?? "star.fill"
        } else {
            self.icon = icon ?? "list.bullet.rectangle.portrait"
        }
        self.color = color ?? "accent"
        self.customColor = customColor
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, phrases, icon, color, customColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phrases = try container.decode([StandardPhrase].self, forKey: .phrases)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? (id.uuidString == "00000000-0000-0000-0000-000000000000" ? "star.fill" : "list.bullet.rectangle.portrait")
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "accent"
        customColor = try container.decodeIfPresent(PresetCustomColor.self, forKey: .customColor)
    }
    
    var displayName: String {
        if id.uuidString == "00000000-0000-0000-0000-000000000000" {
            return String(localized: "Default")
        } else {
            return name
        }
    }
}