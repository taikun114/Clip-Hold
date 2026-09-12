import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let clipholdArchive = UTType(exportedAs: "design.taikun.Clip-Hold.exports")
}

struct ClipboardHistoryDocument: FileDocument {
    var clipboardItems: [ClipboardItem]
    
    static var readableContentTypes: [UTType] { [.json, .clipholdArchive] }
    static var writableContentTypes: [UTType] { [.json, .clipholdArchive] }
    
    init(clipboardItems: [ClipboardItem] = []) {
        self.clipboardItems = clipboardItems
    }
    
    // ファイルから読み込む際のイニシャライザ
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.clipboardItems = try decoder.decode([ClipboardItem].self, from: data)
    }
    
    // ファイルに書き込む際のメソッド
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted // 可読性を高めるために整形
        let data = try encoder.encode(clipboardItems)
        return FileWrapper(regularFileWithContents: data)
    }
}
