import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    
    // フォルダ容量計算のタイムアウト状態などを追跡するためのフラグ（JSONへ保存する）
    @Published var isPartialSize: Bool = false
    @Published var isSizeCalculated: Bool = false
    
    // 非同期コピー関連のプロパティ (これらはCodableには含めない)
    @Published var isCopying: Bool = false
    @Published var isProgressBarVisible: Bool = false
    @Published var copyProgress: Double = 0.0
    var copyTask: Task<Void, Never>? = nil
    var isCopyCancelled: Bool = false
    var sourceFileURL: URL? = nil // コピー元のファイルURL (セッション中のみ有効)
    
    func cancelCopy() {
        isCopyCancelled = true
        copyTask?.cancel()
    }
    
    // ピン留め表示用の複製アイテムの場合、元のアイテムIDを保持
    var originalPinnedItemID: UUID? = nil
    
    // ピン留め表示用の固定UUID名前空間（決定論的なUUID生成に使用）
    private static let pinnedNamespaceBytes: UInt8 = 0xFF
    
    // ピン留めリスト最先頭表示用の複製アイテムを生成するメソッド
    // 元のアイテムIDから決定論的にUUIDを生成するため、何度呼んでも同じIDになる
    func createPinnedDuplicate() -> ClipboardItem {
        let copy = ClipboardItem(
            text: self.text,
            date: self.date,
            filePath: self.filePath,
            fileSize: self.fileSize,
            fileHash: self.fileHash,
            qrCodeContent: self.qrCodeContent,
            sourceAppPath: self.sourceAppPath,
            isPartialSize: self.isPartialSize,
            isSizeCalculated: self.isSizeCalculated
        )
        copy.richText = self.richText
        copy.cachedThumbnailImage = self.cachedThumbnailImage
        copy.originalPinnedItemID = self.id
        // 元のUUIDの最初のバイトを反転して決定論的な新しいUUIDを作成
        var uuidBytes = self.id.uuid
        uuidBytes.0 = uuidBytes.0 ^ ClipboardItem.pinnedNamespaceBytes
        copy.id = UUID(uuid: uuidBytes)
        return copy
    }
    
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
    
    // 表示用のタイトル（必要に応じてローカライズされる）
    var displayTitle: String {
        if text == "Image File" {
            return String(localized: "Image File")
        } else if text == "PDF File" {
            return String(localized: "PDF File")
        } else {
            return text
        }
    }
    
    // Codableではないため CodingKeys には含めない。
    // @Published にすることで、サムネイルの非同期生成完了時にビュー（ClipboardItemIconView）へ即時再描画を通知
    @Published var cachedThumbnailImage: NSImage?
    
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
        self.isPartialSize = false
        self.isSizeCalculated = false
    }
    
    // 新しいClipboardItemを作成するためのイニシャライザ (ファイルパス、サイズ、ハッシュあり)
    init(text: String, date: Date = Date(), filePath: URL?, fileSize: UInt64?, fileHash: String? = nil, qrCodeContent: String? = nil, sourceAppPath: String? = nil, isPartialSize: Bool = false, isSizeCalculated: Bool = false) {
        self.id = UUID()
        self.text = text
        self.richText = nil // リッチテキストは初期値nil
        self.date = date
        self.filePath = filePath
        self.fileSize = fileSize
        self.fileHash = fileHash // 新しく追加
        self.qrCodeContent = qrCodeContent
        self.sourceAppPath = sourceAppPath
        self.isPartialSize = isPartialSize
        self.isSizeCalculated = isSizeCalculated
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
        self.isPartialSize = false
        self.isSizeCalculated = false
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
        self.isPartialSize = try container.decodeIfPresent(Bool.self, forKey: .isPartialSize) ?? false
        self.isSizeCalculated = try container.decodeIfPresent(Bool.self, forKey: .isSizeCalculated) ?? false
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
        try container.encode(isPartialSize, forKey: .isPartialSize)
        try container.encode(isSizeCalculated, forKey: .isSizeCalculated)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, richText, date, filePath, fileSize, fileHash, qrCodeContent, sourceAppPath, isPartialSize, isSizeCalculated
    }
}

// MARK: - ドラッグ＆ドロップ対応
extension ClipboardItem {
    /// ドラッグ＆ドロップ用の NSItemProvider を生成する
    /// - Parameter forcePlainText: true の場合はリッチテキストを含めずプレーンテキスト（またはファイル）として提供する
    func makeItemProvider(forcePlainText: Bool = false) -> NSItemProvider {
        if let filePath = self.filePath {
            return NSItemProvider(object: filePath as NSURL)
        }
        
        let plainText = self.text
        
        if !forcePlainText, let richText = self.richText {
            let provider = NSItemProvider()
            
            // HTML の場合
            if richText.hasPrefix("<!DOCTYPE html") || richText.hasPrefix("<html") || richText.hasPrefix("<HTML") || richText.hasPrefix("<meta") {
                if let htmlData = richText.data(using: .utf8) {
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.html.identifier, visibility: .all) { completion in
                        completion(htmlData, nil)
                        return nil
                    }
                }
            } else {
                // RTF の場合
                if let rtfData = richText.data(using: .utf8) {
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { completion in
                        completion(rtfData, nil)
                        return nil
                    }
                }
            }
            
            // プレーンテキスト（フォールバック用）も同時に登録
            if let textData = plainText.data(using: .utf8) {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                    completion(textData, nil)
                    return nil
                }
            }
            
            return provider
        } else {
            // プレーンテキストのみ
            return NSItemProvider(object: plainText as NSString)
        }
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
