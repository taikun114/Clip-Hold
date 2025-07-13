// ClipboardItem.swift
import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    var id: UUID
    let text: String // テキストとして表示される内容 (ファイルのパスや画像の内容の一部など)
    var date: Date
    var filePath: URL?
    var fileSize: UInt64?
    var qrCodeContent: String? // 追加: QRコードの内容を格納するプロパティ

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    // 新しいClipboardItemを作成するためのイニシャライザ (テキストのみ)
    init(text: String, date: Date = Date(), qrCodeContent: String? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = nil
        self.fileSize = nil
        self.qrCodeContent = qrCodeContent
    }

    // 新しいClipboardItemを作成するためのイニシャライザ (ファイルパスとサイズあり)
    init(text: String, date: Date = Date(), filePath: URL?, fileSize: UInt64?, qrCodeContent: String? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = filePath
        self.fileSize = fileSize
        self.qrCodeContent = qrCodeContent
    }

    // CodableのためのDecodableイニシャライザ
    enum CodingKeys: String, CodingKey {
        case id, text, date, filePath, fileSize, qrCodeContent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        filePath = try container.decodeIfPresent(URL.self, forKey: .filePath)
        fileSize = try container.decodeIfPresent(UInt64.self, forKey: .fileSize)
        qrCodeContent = try container.decodeIfPresent(String.self, forKey: .qrCodeContent)
    }
    
    // Encoded func (required for Codable)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(qrCodeContent, forKey: .qrCodeContent)
    }
}
