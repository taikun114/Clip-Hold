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
                DispatchQueue.main.async {
                    self.currentAlert = .error(Text("選択されたファイルがありません。"))
                }
                print("選択されたファイルがありません。")
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
                DispatchQueue.main.async {
                    self.currentAlert = .error(Text("ファイルへのアクセス権限がありません。ファイルパス: \(url.lastPathComponent)"))
                }
                print("DEBUG: Security-scoped resource access failed for URL: \(url.path)")
                return
            }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let importedHistory = try decoder.decode([ClipboardItem].self, from: data)
                
                DispatchQueue.main.async {
                    clipboardManager.importHistory(from: importedHistory)
                    self.currentAlert = .success(Text("クリップボード履歴が正常にインポートされました。"))
                    print("クリップボード履歴が正常にインポートされました: \(url.path)")
                }

            } catch {
                DispatchQueue.main.async {
                    self.currentAlert = .error(Text("履歴ファイルの読み込みまたは解析に失敗しました: \(error.localizedDescription)"))
                }
                print("履歴ファイルの読み込みまたは解析エラー: \(error.localizedDescription)")
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.currentAlert = .error(Text("ファイルの選択に失敗しました: \(error.localizedDescription)"))
            }
            print("ファイルの選択エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - エクスポート結果のハンドリング用メソッド
    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            DispatchQueue.main.async {
                self.currentAlert = .success(Text("クリップボード履歴が正常にエクスポートされました。"))
            }
            print("クリップボード履歴が正常にエクスポートされました: \(url.path)")
        case .failure(let error):
            DispatchQueue.main.async {
                self.currentAlert = .error(Text("履歴のエクスポートに失敗しました: \(error.localizedDescription)"))
            }
            print("履歴のエクスポートエラー: \(error.localizedDescription)")
        }
    }
}
