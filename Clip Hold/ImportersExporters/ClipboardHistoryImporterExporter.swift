import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI

// アラート表示のためのIdentifiableな構造体
struct AlertContent: Identifiable {
    let id = UUID()
    let title: Text
    let message: Text
    let isSuccess: Bool
    
    static func success(_ message: Text) -> AlertContent {
        AlertContent(title: Text("成功"), message: message, isSuccess: true)
    }
    
    static func error(_ message: Text) -> AlertContent {
        AlertContent(title: Text("エラー"), message: message, isSuccess: false)
    }
}

class ClipboardHistoryImporterExporter: ObservableObject {
    @Published var currentAlert: AlertContent?
    
    func handleImportResult(_ result: Result<[URL], Error>, into clipboardManager: ClipboardManager) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                Task { @MainActor in
                    self.currentAlert = .error(Text("選択されたファイルがありません。"))
                }
                print("No file selected.")
                return
            }
            
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                    print("DEBUG: Security-scoped resource access stopped for URL: \(url.path)")
                }
            }
            
            if !accessed {
                Task { @MainActor in
                    self.currentAlert = .error(Text("ファイルへのアクセス権限がありません。ファイルパス: \(url.lastPathComponent)"))
                }
                print("DEBUG: Security-scoped resource access failed for URL: \(url.path)")
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                var importedHistory = try decoder.decode([ClipboardItem].self, from: data)
                
                // 履歴を古い順に並べ替え
                importedHistory.sort { $0.date < $1.date }
                
                Task { @MainActor in
                    clipboardManager.importHistory(from: importedHistory)
                    self.currentAlert = .success(Text("クリップボード履歴が正常にインポートされました。"))
                    print("Clipboard history imported successfully: \(url.path)")
                }
                
            } catch {
                Task { @MainActor in
                    self.currentAlert = .error(Text("履歴ファイルの読み込みまたは解析に失敗しました: \(error.localizedDescription)"))
                }
                print("History file read or parse error: \(error.localizedDescription)")
            }
        case .failure(let error):
            Task { @MainActor in
                self.currentAlert = .error(Text("ファイルの選択に失敗しました: \(error.localizedDescription)"))
            }
            print("File selection error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - エクスポート結果のハンドリング用メソッド
    func handleExportResult(_ result: Result<URL, Error>, from clipboardManager: ClipboardManager) {
        switch result {
        case .success(let url):
            // エクスポート時は、新しい履歴管理システムからすべての履歴を取得してエクスポート
            let historyToExport = clipboardManager.clipboardHistory
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                
                let data = try encoder.encode(historyToExport)
                try data.write(to: url)
                
                Task { @MainActor in
                    self.currentAlert = .success(Text("クリップボード履歴が正常にエクスポートされました。"))
                }
                print("Clipboard history exported successfully: \(url.path)")
            } catch {
                Task { @MainActor in
                    self.currentAlert = .error(Text("履歴のエクスポートに失敗しました: \(error.localizedDescription)"))
                }
                print("History export error: \(error.localizedDescription)")
            }
        case .failure(let error):
            Task { @MainActor in
                self.currentAlert = .error(Text("ファイルの選択に失敗しました: \(error.localizedDescription)"))
            }
            print("File selection error: \(error.localizedDescription)")
        }
    }
}
