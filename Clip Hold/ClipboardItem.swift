import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID
    let text: String // テキストとして表示される内容 (ファイルのパスや画像の内容の一部など)
    var date: Date // <-- ここを 'let' から 'var' に変更
    var filePath: URL? // ファイルがコピーされた場合、その保存先のパス
    var imagePath: URL? // 画像がコピーされた場合、その保存先のパス

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    // 新しいClipboardItemを作成するためのイニシャライザ (テキストのみ)
    init(text: String, date: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = nil // ファイルパスがない場合はnil
        self.imagePath = nil // 画像パスがない場合はnil
    }

    // 新しいClipboardItemを作成するためのイニシャライザ (ファイルパスあり)
    init(text: String, date: Date = Date(), filePath: URL?) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = filePath
        self.imagePath = nil
    }
    
    // 新しいClipboardItemを作成するためのイニシャライザ (画像パスあり)
    init(text: String, date: Date = Date(), imagePath: URL?) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = nil
        self.imagePath = imagePath
    }

    // CodableのためのDecodableイニシャライザ
    enum CodingKeys: String, CodingKey {
        case id, text, date, filePath, imagePath // imagePath を追加
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        // filePath と imagePath はオプションなので、存在しない場合はnilを許容
        filePath = try container.decodeIfPresent(URL.self, forKey: .filePath)
        imagePath = try container.decodeIfPresent(URL.self, forKey: .imagePath)
    }

    // Encoded func (required for Codable)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
    }
}
