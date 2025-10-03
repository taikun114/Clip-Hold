import SwiftUI

struct StatisticsSettingsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var todayStats: (totalCount: Int, textCount: Int, fileCount: Int, appCount: Int) {
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // 今日の履歴アイテムのみをフィルタリング
        let todayItems = clipboardManager.clipboardHistory.filter { item in
            item.date >= startOfToday && item.date < endOfToday
        }
        
        // 各種カウントを計算
        let totalCount = todayItems.count
        let textCount = todayItems.filter { $0.filePath == nil }.count
        let fileCount = todayItems.filter { $0.filePath != nil }.count
        
        // アプリカウント（sourceAppPathがnilでないユニークなアプリ数）
        let uniqueApps = Set(todayItems.compactMap { $0.sourceAppPath }).count
        
        return (totalCount, textCount, fileCount, uniqueApps)
    }
    
    // テキストに関する詳細統計
    var todayTextStats: (plainTextCount: Int, richTextCount: Int, linkCount: Int) {
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // 今日の履歴アイテムのみをフィルタリング
        let todayItems = clipboardManager.clipboardHistory.filter { item in
            item.date >= startOfToday && item.date < endOfToday && item.filePath == nil
        }
        
        // プレーンテキスト、リッチテキスト、リンクの数を計算
        let plainTextCount = todayItems.filter { $0.richText == nil && !$0.isURL }.count
        let richTextCount = todayItems.filter { $0.richText != nil }.count
        let linkCount = todayItems.filter { $0.isURL }.count
        
        return (plainTextCount, richTextCount, linkCount)
    }
    
    // ファイルに関する詳細統計
    var todayFileStats: (imageCount: Int, videoCount: Int, pdfCount: Int, folderCount: Int, otherCount: Int) {
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // 今日の履歴アイテムのみをフィルタリング
        let todayItems = clipboardManager.clipboardHistory.filter { item in
            item.date >= startOfToday && item.date < endOfToday && item.filePath != nil
        }
        
        // 画像、動画、PDF、フォルダ、その他の数を計算
        let imageCount = todayItems.filter { $0.isImage }.count
        let videoCount = todayItems.filter { $0.isVideo }.count
        let pdfCount = todayItems.filter { $0.isPDF }.count
        let folderCount = todayItems.filter { $0.isFolder }.count
        let otherCount = todayItems.count - (imageCount + videoCount + pdfCount + folderCount)
        
        return (imageCount, videoCount, pdfCount, folderCount, otherCount)
    }
    
    // アプリに関する詳細統計
    struct AppInfo {
        let name: String
        let path: String
        let count: Int
    }
    
    var todayAppStats: [AppInfo] {
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // 今日の履歴アイテムのみをフィルタリング
        let todayItems = clipboardManager.clipboardHistory.filter { item in
            item.date >= startOfToday && item.date < endOfToday && item.sourceAppPath != nil
        }
        
        // 各アプリの名前とカウントを計算
        var appData: [String: (name: String, count: Int)] = [:]
        for item in todayItems {
            // アプリ名を取得（パスからファイル名を抽出）
            if let appPath = item.sourceAppPath {
                let appName = getLocalizedNameFromAppPath(appPath)
                appData[appPath, default: (name: appName, count: 0)].count += 1
            }
        }
        
        // アプリ情報を個数の多い順にソート
        let sortedAppInfo = appData.map { path, data in
            AppInfo(name: data.name, path: path, count: data.count)
        }.sorted { $0.count > $1.count }
        
        return sortedAppInfo
    }
    
    // アプリパスからローカライズされた名前を取得
    func getLocalizedNameFromAppPath(_ appPath: String) -> String {
        let appURL = URL(fileURLWithPath: appPath)
        let nonLocalizedName = appURL.deletingPathExtension().lastPathComponent

        if let appBundle = Bundle(url: appURL) {
            let appName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ??
                         appBundle.localizedInfoDictionary?["CFBundleName"] as? String ??
                         appBundle.infoDictionary?["CFBundleName"] as? String ??
                         nonLocalizedName
            return appName
        } else {
            return nonLocalizedName
        }
    }
    
    // アプリのアイコンを取得
    func getAppIcon(for appPath: String) -> NSImage? {
        let appURL = URL(fileURLWithPath: appPath)
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    var body: some View {
        Form {
            Section(header: Text("今日")) {
                HStack {
                    VStack(alignment: .leading) {
                        HStack(alignment: .bottom) {
                            Text("\(todayStats.totalCount)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("コピー")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .offset(x: -6, y: -4)
                        }
                    }
                    Spacer()
                    HStack {
                        HStack {
                            Image(systemName: "textformat")
                                .offset(x: 6)
                            Text("×\(todayStats.textCount)")
                        }
                        .foregroundColor(.secondary)
                        
                        HStack {
                            if #available(macOS 15.0, *) {
                                Image(systemName: "document")
                                    .offset(x: 4)
                            } else {
                                Image(systemName: "doc")
                                    .offset(x: 4)
                            }
                            Text("×\(todayStats.fileCount)")
                        }
                        .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "app.badge.clock")
                                .offset(x: 2, y: 1)
                            Text("×\(todayStats.appCount)")
                        }
                        .foregroundColor(.secondary)
                    }
                }
                //.padding()
                // テキスト統計
                VStack(alignment: .leading, spacing: 8) {
                    Text("テキスト")
                    HStack {
                        HStack {
                            Image(systemName: "textformat")
                                .frame(width: 16, height: 16)
                            Text("テキスト")
                                .font(.headline)
                        }
                        Spacer()
                        Text("\(todayStats.textCount)個")
                            .foregroundColor(.secondary)
                    }
                    
                    // テキストの種類を個数の多い順に並べる
                    let textTypes = [
                        ("標準テキスト", "text.page", todayTextStats.plainTextCount),
                        ("リッチテキスト", "richtext.page", todayTextStats.richTextCount),
                        ("リンク", "paperclip", todayTextStats.linkCount)
                    ].sorted { $0.2 > $1.2 }
                    
                    ForEach(textTypes, id: \.0) { type, icon, count in
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 16, height: 16)
                            Text(type)
                            Spacer()
                            Text("\(count)個")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // ファイル統計
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack {
                            if #available(macOS 15.0, *) {
                                Image(systemName: "document")
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "doc")
                                    .frame(width: 16, height: 16)
                            }
                            Text("ファイル")
                                .font(.headline)
                        }
                        Spacer()
                        Text("\(todayStats.fileCount)個")
                            .foregroundColor(.secondary)
                    }
                    
                    // ファイルの種類を個数の多い順に並べる
                    let fileTypes = [
                        ("画像", "photo", todayFileStats.imageCount),
                        ("動画", "movieclapper", todayFileStats.videoCount),
                        ("PDF", "text.document", todayFileStats.pdfCount),
                        ("フォルダ", "folder", todayFileStats.folderCount),
                        ("その他", "document.badge.ellipsis", todayFileStats.otherCount)
                    ].sorted { $0.2 > $1.2 }
                    
                    ForEach(fileTypes, id: \.0) { type, icon, count in
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 16, height: 16)
                            Text(type)
                            Spacer()
                            Text("\(count)個")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // アプリ統計
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("アプリ")
                            .font(.headline)
                        Spacer()
                        Text("\(todayAppStats.count)種類")
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(todayAppStats, id: \.path) { appInfo in
                        HStack {
                            // アプリのアイコンを表示
                            if let appIcon = getAppIcon(for: appInfo.path) {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(appInfo.name)
                            Spacer()
                            Text("\(appInfo.count)個")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    StatisticsSettingsView()
        .environmentObject(ClipboardManager.shared)
}
