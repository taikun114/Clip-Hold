import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID
    let text: String
    let date: Date

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    // 新しいClipboardItemを作成するためのイニシャライザ
    init(text: String, date: Date = Date()) {
        self.id = UUID() //
        self.text = text
        self.date = date
    }

    // CodableのためのDecodableイニシャライザ
    // これにより、JSONなどからデコードされる際にidも適切に読み込まれる
    enum CodingKeys: String, CodingKey {
        case id, text, date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
    }
}
