import SwiftUI
import Foundation
import ServiceManagement
import UniformTypeIdentifiers
import AppKit

struct CopyHistorySettingsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager

    @AppStorage("maxHistoryToSave") var maxHistoryToSave: Int = 0 // 無制限を0で表す
    @State private var tempSelectedSaveOption: HistoryOption
    @State private var initialSaveOption: HistoryOption

    @AppStorage("maxFileSizeToSave") var maxFileSizeToSave: Int = 1_000_000_000 // デフォルト1GB (1,000,000,000バイト)
    @State private var tempSelectedFileSizeOption: DataSizeOption
    @State private var initialFileSizeOption: DataSizeOption

    @State private var showingCustomSaveHistorySheet = false
    @State private var showingCustomFileSizeSheet = false
    @State private var showingClearHistoryConfirmation = false
    @State private var showingClearFilesConfirmation = false

    @State private var tempCustomSaveHistoryValue: Int = 20
    @State private var tempCustomFileSizeValue: Int = 1
    @State private var tempCustomFileSizeUnit: DataSizeUnit = .megabytes

    @StateObject private var clipboardImporterExporter = ClipboardHistoryImporterExporter()
    @State private var isShowingImportSheet: Bool = false
    @State private var isShowingExportSheet: Bool = false

    @State private var itemCount: Int = 0
    @State private var totalFolderSize: UInt64 = 0
    
    // MARK: - Initialization
    init() {
        let savedMaxHistoryToSave = UserDefaults.standard.integer(forKey: "maxHistoryToSave")
        let savedMaxFileSizeToSave = UserDefaults.standard.integer(forKey: "maxFileSizeToSave")

        // DEBUG print for initial values from UserDefaults (accessing AppStorage directly here is fine)
        print("DEBUG: init() - savedMaxHistoryToSave: \(savedMaxHistoryToSave)")
        print("DEBUG: init() - savedMaxFileSizeToSave: \(savedMaxFileSizeToSave)")

        // MARK: - ローカル変数を宣言し、それらの値を決定するロジック
        // tempSelectedSaveOption の値を決定
        let determinedTempSelectedSaveOption: HistoryOption
        var determinedTempCustomSaveHistoryValue: Int

        if savedMaxHistoryToSave == 0 {
            determinedTempSelectedSaveOption = .unlimited
            determinedTempCustomSaveHistoryValue = 20
        } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == savedMaxHistoryToSave }) {
            determinedTempSelectedSaveOption = savedPreset
            determinedTempCustomSaveHistoryValue = savedMaxHistoryToSave
        } else {
            determinedTempSelectedSaveOption = .custom(savedMaxHistoryToSave)
            determinedTempCustomSaveHistoryValue = savedMaxHistoryToSave
        }
    
        // tempSelectedFileSizeOption の値を決定
        let determinedTempSelectedFileSizeOption: DataSizeOption
        var determinedTempCustomFileSizeValue: Int = 1
        var determinedTempCustomFileSizeUnit: DataSizeUnit = .megabytes

        if savedMaxFileSizeToSave == 0 { // 0は無制限として扱う
            determinedTempSelectedFileSizeOption = .unlimited
        } else {
            // presets から一致するものを探す (バイト値で比較)
            if let preset = DataSizeOption.presets.first(where: { $0.byteValue == savedMaxFileSizeToSave }) {
                determinedTempSelectedFileSizeOption = preset
            } else {
                // カスタム値の場合、単位と値を逆算
                // まずGBで試行
                if savedMaxFileSizeToSave % (1000 * 1000 * 1000) == 0 {
                    determinedTempCustomFileSizeValue = savedMaxFileSizeToSave / (1000 * 1000 * 1000)
                    determinedTempCustomFileSizeUnit = .gigabytes
                }
                // 次にMBで試行
                else if savedMaxFileSizeToSave % (1000 * 1000) == 0 {
                    determinedTempCustomFileSizeValue = savedMaxFileSizeToSave / (1000 * 1000)
                    determinedTempCustomFileSizeUnit = .megabytes
                }
                // 次にKBで試行
                else if savedMaxFileSizeToSave % 1000 == 0 {
                    determinedTempCustomFileSizeValue = savedMaxFileSizeToSave / 1000
                    determinedTempCustomFileSizeUnit = .kilobytes
                }
                // それ以外はバイト
                else {
                    determinedTempCustomFileSizeValue = savedMaxFileSizeToSave
                    determinedTempCustomFileSizeUnit = .bytes
                }
                determinedTempSelectedFileSizeOption = .custom(determinedTempCustomFileSizeValue, determinedTempCustomFileSizeUnit)
            }
        }

        // MARK: - すべての @State プロパティの初期化を一括で行う
        _tempSelectedSaveOption = State(initialValue: determinedTempSelectedSaveOption)
        _tempCustomSaveHistoryValue = State(initialValue: determinedTempCustomSaveHistoryValue)

        _tempSelectedFileSizeOption = State(initialValue: determinedTempSelectedFileSizeOption)
        _tempCustomFileSizeValue = State(initialValue: determinedTempCustomFileSizeValue)
        _tempCustomFileSizeUnit = State(initialValue: determinedTempCustomFileSizeUnit)

        // initialオプションは、対応するtempオプションが確定した後に初期化
        _initialSaveOption = State(initialValue: determinedTempSelectedSaveOption)
        _initialFileSizeOption = State(initialValue: determinedTempSelectedFileSizeOption) // 新しく追加
    }

    var body: some View {
        Form {
            // MARK: - 履歴の設定
            Section(header: Text("履歴の設定").font(.headline)) {
                // 履歴を保存する最大数
                HStack {
                    Text("履歴を保存する最大数:")
                    Spacer()
                    Picker("履歴を保存する最大数", selection: $tempSelectedSaveOption) {
                        ForEach(HistoryOption.presets) { option in
                            Text(option.stringValue)
                                .tag(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("無制限")
                            .tag(HistoryOption.unlimited)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("カスタム...")
                            .tag(HistoryOption.custom(nil))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !HistoryOption.presets.contains(where: { $0.intValue == maxHistoryToSave }) && maxHistoryToSave != 0 && tempSelectedSaveOption != .custom(nil) {
                            Divider()
                            Text("カスタム: \(maxHistoryToSave)")
                                .tag(HistoryOption.custom(maxHistoryToSave))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: tempSelectedSaveOption) {
                        if case .custom(nil) = tempSelectedSaveOption {
                            tempCustomSaveHistoryValue = maxHistoryToSave // 現在の値をカスタムシートの初期値に
                            showingCustomSaveHistorySheet = true
                        } else if tempSelectedSaveOption == .unlimited {
                            maxHistoryToSave = 0 // 無制限を0として保存
                        } else if let intValue = tempSelectedSaveOption.intValue {
                            maxHistoryToSave = intValue
                        }
                        // 保存数の変更がメニュー表示数に影響する場合の処理（例：メニュー表示が「履歴の保存数に合わせる」の場合）
                        if UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
                            UserDefaults.standard.set(maxHistoryToSave, forKey: "maxHistoryInMenu")
                        }
                        // ★修正: 保存数が無制限に設定された場合、かつメニュー表示が「保存数に合わせる」ならデフォルト値に戻す
                        if tempSelectedSaveOption == .unlimited && UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
                            UserDefaults.standard.set(10, forKey: "maxHistoryInMenu")
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    VStack(alignment: .leading) {
                        Text("ファイル1つあたりの最大容量:")
                        Text("ここで設定した容量よりも小さいファイルがコピーされた時だけ、履歴に保存されます。過去の履歴は影響を受けません。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("ファイル1つあたりの最大容量", selection: $tempSelectedFileSizeOption) {
                        ForEach(DataSizeOption.presets) { option in
                            Text(option.stringValue)
                                .tag(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("無制限")
                            .tag(DataSizeOption.unlimited)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("カスタム...")
                            .tag(DataSizeOption.custom(nil, nil))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if case let .custom(val, unit) = tempSelectedFileSizeOption,
                           let value = val, let unit = unit,
                           !DataSizeOption.presets.contains(where: { $0.byteValue == maxFileSizeToSave }) {
                            Divider()
                            Text("カスタム: \(value) \(unit.label)")
                                .tag(DataSizeOption.custom(value, unit)) // tagを正しく設定
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: tempSelectedFileSizeOption) {
                        if case .custom(nil, nil) = tempSelectedFileSizeOption {
                            // 現在のバイト値をカスタムシートの初期値に変換
                            let (value, unit) = tempSelectedFileSizeOption.extractValueAndUnitFromByteValue(byteValue: maxFileSizeToSave)
                            tempCustomFileSizeValue = value
                            tempCustomFileSizeUnit = unit
                            showingCustomFileSizeSheet = true
                        } else if tempSelectedFileSizeOption == .unlimited {
                            maxFileSizeToSave = 0 // 無制限は0として保存
                        } else if let byteValue = tempSelectedFileSizeOption.byteValue {
                            maxFileSizeToSave = byteValue
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: 履歴の設定

            // MARK: - 履歴の管理
            Section(header: Text("履歴の管理").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("クリップボード履歴")
                        Text("現在、インポートとエクスポートはテキストのみサポートしています。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        print("DEBUG: Import button tapped. isShowingImportSheet will be true.")
                        self.isShowingImportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("インポート")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("書き出したクリップボード履歴のJSONファイルを読み込みます。")

                    Button(action: {
                        self.isShowingExportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("エクスポート")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(clipboardManager.clipboardHistory.isEmpty)
                    .help("すべてのクリップボード履歴をJSONファイルとして書き出します。")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    Text("\(clipboardManager.clipboardHistory.count)個の履歴")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        showingClearHistoryConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべての履歴を削除")
                        }
                        .if(!clipboardManager.clipboardHistory.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(clipboardManager.clipboardHistory.isEmpty)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: 履歴の管理
            
            // MARK: - 保存フォルダの管理
            Section {
                HStack {
                    Text("保存フォルダの項目数:")
                    Spacer()
                    Text("\(itemCount)個")
                        .foregroundColor(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    Text("保存フォルダの総容量:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(totalFolderSize), countStyle: .file))
                        .foregroundColor(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    Button(action: {
                        openClipboardFilesFolderInFinder()
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("保存フォルダを開く")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("ファイルの保存先フォルダをFinderで開きます。")
                    
                    Spacer()
                    
                    Button(action: {
                        showingClearFilesConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("保存フォルダを空にする")
                        }
                        .if(itemCount > 0) { view in
                            view.foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(itemCount == 0)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("保存フォルダの管理")
                        .font(.headline)
                    
                    Text("ファイルやフォルダをコピーしたときにデータが保存されるフォルダを管理します。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
            } // End of Section: 保存フォルダの管理

        } // End of Form
        .formStyle(.grouped)
        .onAppear {
            calculateStatistics()
        }
        .onChange(of: clipboardManager.clipboardHistory) {
            calculateStatistics()
        }
        .sheet(isPresented: $showingCustomSaveHistorySheet) {
            CustomNumberInputSheet(
                title: Text("履歴を保存する最大数を設定"),
                description: Text("保存されている履歴の数より少ない値を設定すると、設定値を超えた分は、クリップボード履歴の次回更新時に削除されます。"),
                currentValue: $tempCustomSaveHistoryValue,
                onSave: { newValue in
                    maxHistoryToSave = newValue

                    if newValue == 0 {
                        tempSelectedSaveOption = .unlimited
                    } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == newValue }) {
                        tempSelectedSaveOption = savedPreset
                    } else {
                        tempSelectedSaveOption = .custom(newValue)
                    }

                    if UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
                        UserDefaults.standard.set(maxHistoryToSave, forKey: "maxHistoryInMenu")
                    }
                },
                onCancel: {
                    if maxHistoryToSave == 0 {
                        tempSelectedSaveOption = .unlimited
                    } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == maxHistoryToSave }) {
                        tempSelectedSaveOption = savedPreset
                    } else {
                        tempSelectedSaveOption = .custom(maxHistoryToSave)
                    }
                }
            )
        }
        .sheet(isPresented: $showingCustomFileSizeSheet) {
            CustomNumberInputSheet(
                title: Text("ファイル1つあたりの最大容量を設定"),
                description: nil,
                currentValue: $tempCustomFileSizeValue,
                selectedUnit: Binding<DataSizeUnit?>(get: { tempCustomFileSizeUnit }, set: { tempCustomFileSizeUnit = $0 ?? .megabytes }), // Explicitly convert Binding<DataSizeUnit> to Binding<DataSizeUnit?>
                onSave: { newValue in
                    let newByteValue = tempCustomFileSizeUnit.byteValue(for: newValue)
                    maxFileSizeToSave = newByteValue

                    if newByteValue == 0 { // 0は無制限として扱う
                        tempSelectedFileSizeOption = .unlimited
                    } else if let savedPreset = DataSizeOption.presets.first(where: { $0.byteValue == newByteValue }) {
                        tempSelectedFileSizeOption = savedPreset
                    } else {
                        tempSelectedFileSizeOption = .custom(newValue, tempCustomFileSizeUnit)
                    }
                },
                onCancel: {
                    if maxFileSizeToSave == 0 { // 0は無制限として扱う
                        tempSelectedFileSizeOption = .unlimited
                    } else if let savedPreset = DataSizeOption.presets.first(where: { $0.byteValue == maxFileSizeToSave }) {
                        tempSelectedFileSizeOption = savedPreset
                    } else {
                        // 既存の値をカスタムとして設定し直す
                        let (value, unit) = DataSizeOption.custom(maxFileSizeToSave, nil).extractValueAndUnitFromByteValue(byteValue: maxFileSizeToSave)
                        tempCustomFileSizeValue = value
                        tempCustomFileSizeUnit = unit
                        tempSelectedFileSizeOption = .custom(value, unit)
                    }
                }
            )
        }
        .fileExporter(
            isPresented: $isShowingExportSheet,
            document: ClipboardHistoryDocument(clipboardItems: clipboardManager.clipboardHistory),
            contentType: .json,
            defaultFilename: "Clip Hold Clipboard History \(Date().formattedLocalExportFilename()).json"
        ) { result in
            clipboardImporterExporter.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $isShowingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            print("DEBUG: fileImporter closure called for history import.")
            clipboardImporterExporter.handleImportResult(result, into: clipboardManager)
            self.isShowingImportSheet = false
        }
        .alert(item: $clipboardImporterExporter.currentAlert) { alertContent in
            Alert(
                title: alertContent.title,
                message: alertContent.message,
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("すべてのクリップボード履歴を削除", isPresented: $showingClearHistoryConfirmation) {
            Button("削除", role: .destructive) {
                clipboardManager.clearAllHistory()
            }
            Button("キャンセル", role: .cancel) {
                // 何もしない
            }
        } message: {
            Text("すべてのクリップボード履歴を本当に削除しますか？この操作は元に戻せません。")
        }
        .alert("保存フォルダを空にする", isPresented: $showingClearFilesConfirmation) {
            Button("削除", role: .destructive) {
                clearAllSavedFiles()
            }
            Button("キャンセル", role: .cancel) {
                // 何もしない
            }
        } message: {
            Text("履歴に保存されたすべてのファイルとフォルダを削除しますか？関連する履歴も削除されます。この操作は元に戻せません。")
        }
    }
    
    private func openClipboardFilesFolderInFinder() {
        guard let appSpecificDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ClipHold") else {
            return
        }
        let filesDirectory = appSpecificDirectory.appendingPathComponent("ClipboardFiles", isDirectory: true)
        NSWorkspace.shared.open(filesDirectory)
    }

    private func clearAllSavedFiles() {
        // バックグラウンドスレッドで処理を実行
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            
            guard let appSpecificDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ClipHold") else {
                return
            }
            let filesDirectory = appSpecificDirectory.appendingPathComponent("ClipboardFiles", isDirectory: true)

            guard fileManager.fileExists(atPath: filesDirectory.path) else {
                return
            }

            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
                
                // メインスレッドでUIを更新
                DispatchQueue.main.async {
                    self.clipboardManager.loadClipboardHistory()
                    self.calculateStatistics()
                    print("DEBUG: All saved files cleared and clipboard history reloaded.")
                }
            } catch {
                print("Error clearing clipboard files: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateStatistics() {
        // バックグラウンドスレッドで処理を実行
        DispatchQueue.global(qos: .background).async {
            var itemCount: Int = 0
            var totalFolderSize: UInt64 = 0

            let fileManager = FileManager.default
            
            guard let appSpecificDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ClipHold") else {
                return
            }
            let filesDirectory = appSpecificDirectory.appendingPathComponent("ClipboardFiles", isDirectory: true)

            guard fileManager.fileExists(atPath: filesDirectory.path) else {
                DispatchQueue.main.async {
                    self.itemCount = 0
                    self.totalFolderSize = 0
                }
                return
            }

            do {
                // ファイルとフォルダの合計数をカウント
                let fileURLs = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                itemCount = fileURLs.count
                
                // フォルダ全体のサイズを再帰的に計算
                if let enumerator = fileManager.enumerator(at: filesDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let fileURL as URL in enumerator {
                        if let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                            totalFolderSize += UInt64(fileSize)
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.itemCount = itemCount
                    self.totalFolderSize = totalFolderSize
                }
            } catch {
                print("Error calculating clipboard file statistics: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - DataSizeOption のヘルパー拡張
extension DataSizeOption {
    func extractValueAndUnitFromByteValue(byteValue: Int) -> (value: Int, unit: DataSizeUnit) {
        let gigabyteValue = 1_000_000_000
        let megabyteValue = 1_000_000
        let kilobyteValue = 1_000

        if byteValue >= gigabyteValue && byteValue % gigabyteValue == 0 {
            return (byteValue / gigabyteValue, .gigabytes)
        } else if byteValue >= megabyteValue && byteValue % megabyteValue == 0 {
            return (byteValue / megabyteValue, .megabytes)
        } else if byteValue >= kilobyteValue && byteValue % kilobyteValue == 0 {
            return (byteValue / kilobyteValue, .kilobytes)
        } else {
            return (byteValue, .bytes)
        }
    }
}

extension Date {
    func formattedLocalExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.locale = Locale.current
        formatter.timeZone = .current
        return formatter.string(from: self)
    }
}

#Preview {
    CopyHistorySettingsView()
        .environmentObject(ClipboardManager.shared)
}
