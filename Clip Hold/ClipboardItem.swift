import Foundation
import SwiftUI

class ClipboardItem: ObservableObject, Identifiable, Codable, Equatable {
    var id: UUID
    @Published var text: String
    @Published var date: Date
    @Published var filePath: URL?
    @Published var fileSize: UInt64?
    @Published var qrCodeContent: String?
    @Published var sourceAppPath: String?

    // ファイルが画像かどうかを判断するヘルパープロパティ
    var isImage: Bool {
        guard let filePath = filePath else { return false }
        if filePath.isFileURL {
            let pathExtension = filePath.pathExtension.lowercased()
            let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "heic", "webp", "tiff", "tif"]
            if imageExtensions.contains(pathExtension) {
                return true
            }
        }
        return false
    }

    // テキストが有効なURLであるかどうかを判断するヘルパープロパティ
    var isURL: Bool {
        guard !text.isEmpty,
              let url = URL(string: text) else {
            return false
        }
        // URLスキームがhttpまたはhttpsであることを確認
        return url.scheme == "http" || url.scheme == "https"
    }

    // Codableではないため @Published にできない。
    // UIの自動更新は、このプロパティの変更後に親のObservableObject (ClipboardManager) の変更を通知することで実現
    var cachedThumbnailImage: NSImage?
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // 新しいClipboardItemを作成するためのイニシャライザ (テキストのみ)
    init(text: String, date: Date = Date(), qrCodeContent: String? = nil, sourceAppPath: String? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = nil
        self.fileSize = nil
        self.qrCodeContent = qrCodeContent
        self.sourceAppPath = sourceAppPath
    }

    // 新しいClipboardItemを作成するためのイニシャライザ (ファイルパスとサイズあり)
    init(text: String, date: Date = Date(), filePath: URL?, fileSize: UInt64?, qrCodeContent: String? = nil, sourceAppPath: String? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.filePath = filePath
        self.fileSize = fileSize
        self.qrCodeContent = qrCodeContent
        self.sourceAppPath = sourceAppPath
    }

    // CodableのためのDecodableイニシャライザ
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.date = try container.decode(Date.self, forKey: .date)
        self.filePath = try container.decodeIfPresent(URL.self, forKey: .filePath)
        self.fileSize = try container.decodeIfPresent(UInt64.self, forKey: .fileSize)
        self.qrCodeContent = try container.decodeIfPresent(String.self, forKey: .qrCodeContent)
        self.sourceAppPath = try container.decodeIfPresent(String.self, forKey: .sourceAppPath)
    }
    
    // CodableのためのEncoded関数
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(qrCodeContent, forKey: .qrCodeContent)
        try container.encodeIfPresent(sourceAppPath, forKey: .sourceAppPath)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, date, filePath, fileSize, qrCodeContent, sourceAppPath
    }
}
