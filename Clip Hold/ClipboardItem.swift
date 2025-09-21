import Foundation
import SwiftUI

class ClipboardItem: ObservableObject, Identifiable, Codable, Equatable {
    var id: UUID
    @Published var text: String
    @Published var richText: String? // リッチテキストを保持する新しいプロパティ
    @Published var date: Date
    @Published var filePath: URL?
    @Published var fileSize: UInt64?
    @Published var fileHash: String? // 新しく追加
    @Published var qrCodeContent: String?
    @Published var sourceAppPath: String?

    // ファイルが画像かどうかを判断するヘルパープロパティ
    var isImage: Bool {
        guard let filePath = filePath else { return false }
        if filePath.isFileURL {
            let pathExtension = filePath.pathExtension.lowercased()
            let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "heic", "webp", "tiff", "tif", "ico", "icns", "svg", "eps", "ai", "psd"]
            if imageExtensions.contains(pathExtension) {
                return true
            }
        }
        return false
    }
    
    // ファイルが動画かどうかを判断するヘルパープロパティ
    var isVideo: Bool {
        guard let filePath = filePath else { return false }
        if filePath.isFileURL {
            let pathExtension = filePath.pathExtension.lowercased()
            let videoExtensions = ["mov", "mp4", "avi", "mkv", "wmv", "flv", "webm", "m4v", "qt"]
            if videoExtensions.contains(pathExtension) {
                return true
            }
        }
        return false
    }
    
    // ファイルがPDFかどうかを判断するヘルパープロパティ
    var isPDF: Bool {
        guard let filePath = filePath else { return false }
        if filePath.isFileURL {
            return filePath.pathExtension.lowercased() == "pdf"
        }
        return false
    }

    // ファイルがフォルダかどうかを判断するヘルパープロパティ
    var isFolder: Bool {
        guard let filePath = filePath else { return false }
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: filePath.path, isDirectory: &isDirectory)
        return fileExists && isDirectory.boolValue
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
        self.richText = nil // リッチテキストは初期値nil
        self.date = date
        self.filePath = nil
        self.fileSize = nil
        self.fileHash = nil // 新しく追加
        self.qrCodeContent = qrCodeContent
        self.sourceAppPath = sourceAppPath
    }

    // 新しいClipboardItemを作成するためのイニシャライザ (ファイルパス、サイズ、ハッシュあり)
    init(text: String, date: Date = Date(), filePath: URL?, fileSize: UInt64?, fileHash: String? = nil, qrCodeContent: String? = nil, sourceAppPath: String? = nil) {
        self.id = UUID()
        self.text = text
        self.richText = nil // リッチテキストは初期値nil
        self.date = date
        self.filePath = filePath
        self.fileSize = fileSize
        self.fileHash = fileHash // 新しく追加
        self.qrCodeContent = qrCodeContent
        self.sourceAppPath = sourceAppPath
    }
    
    // 新しいClipboardItemを作成するためのイニシャライザ (リッチテキスト用)
    init(richText: String, text: String, date: Date = Date(), qrCodeContent: String? = nil, sourceAppPath: String? = nil) {
        self.id = UUID()
        self.text = text // プレーンテキストも保持
        self.richText = richText // リッチテキストを設定
        self.date = date
        self.filePath = nil
        self.fileSize = nil
        self.fileHash = nil
        self.qrCodeContent = qrCodeContent
        self.sourceAppPath = sourceAppPath
    }

    // CodableのためのDecodableイニシャライザ
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.richText = try container.decodeIfPresent(String.self, forKey: .richText) // リッチテキストをデコード
        self.date = try container.decode(Date.self, forKey: .date)
        self.filePath = try container.decodeIfPresent(URL.self, forKey: .filePath)
        self.fileSize = try container.decodeIfPresent(UInt64.self, forKey: .fileSize)
        self.fileHash = try container.decodeIfPresent(String.self, forKey: .fileHash) // 新しく追加
        self.qrCodeContent = try container.decodeIfPresent(String.self, forKey: .qrCodeContent)
        self.sourceAppPath = try container.decodeIfPresent(String.self, forKey: .sourceAppPath)
    }
    
    // CodableのためのEncoded関数
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(richText, forKey: .richText) // リッチテキストをエンコード
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(fileHash, forKey: .fileHash) // 新しく追加
        try container.encodeIfPresent(qrCodeContent, forKey: .qrCodeContent)
        try container.encodeIfPresent(sourceAppPath, forKey: .sourceAppPath)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, richText, date, filePath, fileSize, fileHash, qrCodeContent, sourceAppPath // richTextとfileHashを追加
    }
}

// NSImageのエクステンション
extension NSImage {
    var imageData: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
