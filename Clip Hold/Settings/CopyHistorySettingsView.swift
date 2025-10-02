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

    @AppStorage("maxFileSizeToSave") var maxFileSizeToSave: Int = 0 // デフォルトは無制限
    @State private var tempSelectedFileSizeOption: DataSizeOption
    @State private var initialFileSizeOption: DataSizeOption

    @AppStorage("largeFileAlertThreshold") var largeFileAlertThreshold: Int = 1_000_000_000
    @State private var tempSelectedAlertOption: DataSizeAlertOption
    @State private var initialAlertOption: DataSizeAlertOption
    @State private var showingCustomAlertSheet = false

    @AppStorage("ignoreStandardPhrases") var ignoreStandardPhrases: Bool = false

    @State private var tempCustomAlertValue: Int = 1 // カスタム入力シート用の値
    @State private var tempCustomAlertUnit: DataSizeUnit = .gigabytes // カスタム入力シート用の単位

    @State private var showingCustomSaveHistorySheet = false
    @State private var showingCustomFileSizeSheet = false
    @State private var showingClearHistoryConfirmation = false
    @State private var showingClearFilesConfirmation = false

    @State private var customSaveHistoryWasSaved = false
    @State private var customFileSizeWasSaved = false
    @State private var customAlertWasSaved = false

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
        // UserDefaultsから現在の設定値を取得 (Optional Intとして取得し、未設定と0を区別する)
        let savedMaxHistoryToSaveRaw = UserDefaults.standard.object(forKey: "maxHistoryToSave") as? Int
        let savedMaxFileSizeToSaveRaw = UserDefaults.standard.object(forKey: "maxFileSizeToSave") as? Int
        let savedLargeFileAlertThresholdRaw = UserDefaults.standard.object(forKey: "largeFileAlertThreshold") as? Int

        // maxHistoryToSaveは0が無制限を表すため、raw値をそのまま使用。nilの場合は0をデフォルトとする。
        let savedMaxHistoryToSave = savedMaxHistoryToSaveRaw ?? 0

        // largeFileAlertThresholdは、UserDefaultsに値がない場合（nil）にAppStorageのデフォルト値（1GB）を使用。
        // 0が明示的に設定されている場合は0として扱う。
        let savedMaxFileSizeToSave = savedMaxFileSizeToSaveRaw ?? 0
        let savedLargeFileAlertThreshold = savedLargeFileAlertThresholdRaw ?? 1_000_000_000


        // DEBUG print for initial values from UserDefaults
        print("DEBUG: init() - savedMaxHistoryToSaveRaw: \(savedMaxHistoryToSaveRaw ?? -1) (using \(savedMaxHistoryToSave))")
        print("DEBUG: init() - savedMaxFileSizeToSaveRaw: \(savedMaxFileSizeToSaveRaw ?? -1) (using \(savedMaxFileSizeToSave))")
        print("DEBUG: init() - savedLargeFileAlertThresholdRaw: \(savedLargeFileAlertThresholdRaw ?? -1) (using \(savedLargeFileAlertThreshold))")

        // Initialize tempSelectedSaveOption and tempCustomSaveHistoryValue
        let determinedSaveOptions = Self.determineHistorySaveOptions(savedMaxHistoryToSave: savedMaxHistoryToSave)
        _tempSelectedSaveOption = State(initialValue: determinedSaveOptions.option)
        _tempCustomSaveHistoryValue = State(initialValue: determinedSaveOptions.customValue)

        // Initialize tempSelectedFileSizeOption, tempCustomFileSizeValue, and tempCustomFileSizeUnit
        let determinedFileSizeOptions = Self.determineFileSizeOptions(savedMaxFileSizeToSave: savedMaxFileSizeToSave)
        _tempSelectedFileSizeOption = State(initialValue: determinedFileSizeOptions.option)
        _tempCustomFileSizeValue = State(initialValue: determinedFileSizeOptions.customValue)
        _tempCustomFileSizeUnit = State(initialValue: determinedFileSizeOptions.customUnit)

        // Initialize tempSelectedAlertOption, tempCustomAlertValue, and tempCustomAlertUnit
        let determinedAlertOptions = Self.determineAlertOptions(savedLargeFileAlertThreshold: savedLargeFileAlertThreshold)
        _tempSelectedAlertOption = State(initialValue: determinedAlertOptions.option)
        _tempCustomAlertValue = State(initialValue: determinedAlertOptions.customValue)
        _tempCustomAlertUnit = State(initialValue: determinedAlertOptions.customUnit)

        // Initialize initial options after temp options are determined
        _initialSaveOption = State(initialValue: determinedSaveOptions.option)
        _initialFileSizeOption = State(initialValue: determinedFileSizeOptions.option)
        _initialAlertOption = State(initialValue: determinedAlertOptions.option)
    }

    // MARK: - Helper methods for initialization logic
    private static func determineHistorySaveOptions(savedMaxHistoryToSave: Int) -> (option: HistoryOption, customValue: Int) {
        // maxHistoryToSaveは0が無制限を表すため、このロジックは変更しない
        if savedMaxHistoryToSave == 0 {
            return (.unlimited, 20)
        } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == savedMaxHistoryToSave }) {
            return (savedPreset, savedMaxHistoryToSave)
        } else {
            return (.custom(savedMaxHistoryToSave), savedMaxHistoryToSave)
        }
    }

    private static func determineFileSizeOptions(savedMaxFileSizeToSave: Int) -> (option: DataSizeOption, customValue: Int, customUnit: DataSizeUnit) {
        // savedMaxFileSizeToSaveが0の場合、それはユーザーが明示的に「無制限」を選択したことを意味する
        if savedMaxFileSizeToSave == 0 {
            return (.unlimited, 1, .megabytes)
        } else {
            if let preset = DataSizeOption.presets.first(where: { $0.byteValue == savedMaxFileSizeToSave }) {
                return (preset, 1, .megabytes) // Custom values not relevant for presets
            } else {
                let (value, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: savedMaxFileSizeToSave)
                return (.custom(value, unit), value, unit)
            }
        }
    }

    private static func determineAlertOptions(savedLargeFileAlertThreshold: Int) -> (option: DataSizeAlertOption, customValue: Int, customUnit: DataSizeUnit) {
        // savedLargeFileAlertThresholdが0の場合、それはユーザーが明示的に「表示しない」を選択したことを意味する
        if savedLargeFileAlertThreshold == 0 {
            return (.noAlert, 1, .gigabytes)
        } else {
            if let preset = DataSizeAlertOption.presets.first(where: { $0.byteValue == savedLargeFileAlertThreshold }) {
                return (preset, 1, .gigabytes) // Custom values not relevant for presets
            } else {
                let (value, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: savedLargeFileAlertThreshold)
                return (.custom(value, unit), value, unit)
            }
        }
    }

    // MARK: - Helper methods for Picker custom option display
    private func getCustomFileSizeOptionDisplay() -> (value: Int, unit: DataSizeUnit)? {
        let (val, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: maxFileSizeToSave)
        if !DataSizeOption.presets.contains(where: { $0.byteValue == maxFileSizeToSave }) && maxFileSizeToSave != 0 {
            return (val, unit)
        }
        return nil
    }

    private func getCustomAlertOptionDisplay() -> (value: Int, unit: DataSizeUnit)? {
        let (val, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: largeFileAlertThreshold)
        if !DataSizeAlertOption.presets.contains(where: { $0.byteValue == largeFileAlertThreshold }) && largeFileAlertThreshold != 0 {
            return (val, unit)
        }
        return nil
    }

    // MARK: - Picker Custom Option Views
    private var fileSizeCustomOptionView: some View {
        Group {
            if let customOption = getCustomFileSizeOptionDisplay() {
                Divider()
                Text("カスタム: \(customOption.value) \(customOption.unit.label)")
                    .tag(DataSizeOption.custom(customOption.value, customOption.unit))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var alertCustomOptionView: some View {
        Group {
            if let customOption = getCustomAlertOptionDisplay() {
                Divider()
                Text("カスタム: \(customOption.value) \(customOption.unit.label)")
                    .tag(DataSizeAlertOption.custom(customOption.value, customOption.unit))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var body: some View {
        Form {
            // MARK: - 履歴の設定
            Section(header: Text("履歴の設定").font(.headline)) {
                // 履歴の最大保存数
                HStack {
                    VStack(alignment: .leading) {
                        Text("履歴の最大保存数")
                        Text("Clip Holdに保存する履歴の最大数を設定します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("履歴の最大保存数", selection: $tempSelectedSaveOption) {
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

                        // If the current maxHistoryToSave is a custom value not in presets, show it
                        if !HistoryOption.presets.contains(where: { $0.intValue == maxHistoryToSave }) && maxHistoryToSave != 0 {
                            Divider()
                            Text("カスタム: \(maxHistoryToSave)")
                                .tag(HistoryOption.custom(maxHistoryToSave))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    // Updated onChange syntax to use a two-parameter closure
                    .onChange(of: tempSelectedSaveOption) { _, newValue in
                        handleSaveOptionChange(newValue: newValue)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    VStack(alignment: .leading) {
                        Text("コピーアラートを表示する容量")
                        Text("ここで設定した容量よりも大きいファイルをコピーしようとした際に、コピーしたファイルを履歴に保存するかどうかを求めるアラートが表示されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("コピーアラートを表示する容量", selection: $tempSelectedAlertOption) {
                        ForEach(DataSizeAlertOption.presets) { option in
                            Text(option.stringValue)
                                .tag(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text("表示しない")
                            .tag(DataSizeAlertOption.noAlert)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("カスタム...")
                            .tag(DataSizeAlertOption.custom(nil, nil))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Use the extracted custom option view
                        alertCustomOptionView
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    // Updated onChange syntax to use a two-parameter closure
                    .onChange(of: tempSelectedAlertOption) { _, newValue in
                        handleAlertOptionChange(newValue: newValue)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    VStack(alignment: .leading) {
                        Text("各ファイルの最大容量")
                        Text("ここで設定した容量よりも小さいファイルがコピーされた時だけ、履歴に保存されます。過去の履歴は影響を受けません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("各ファイルの最大容量", selection: $tempSelectedFileSizeOption) {
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

                        // Use the extracted custom option view
                        fileSizeCustomOptionView
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    // Updated onChange syntax to use a two-parameter closure
                    .onChange(of: tempSelectedFileSizeOption) { _, newValue in
                        handleFileSizeOptionChange(newValue: newValue)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    VStack(alignment: .leading) {
                        Text("定型文を無視する")
                        Text("コピーした定型文を履歴に追加しないようにします。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $ignoreStandardPhrases) {
                        Text("定型文を無視する")
                        Text("オンにすると、コピーした定型文を履歴に追加しないようにします。")
                    }
                    .labelsHidden()
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
                            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    Text("保存フォルダの総容量:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(totalFolderSize), countStyle: .file))
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
            } // End of Section: 保存フォルダの管理

        } // End of Form
        .formStyle(.grouped)
        .onAppear {
            calculateStatistics()
        }
        // Updated onChange syntax to use a zero-parameter closure
        .onChange(of: clipboardManager.clipboardHistory) {
            calculateStatistics()
        }
        .sheet(isPresented: $showingCustomSaveHistorySheet, onDismiss: {
            if !customSaveHistoryWasSaved {
                handleCustomSaveHistorySheetCancel()
            }
        }) {
            CustomNumberInputSheet(
                title: Text("履歴を保存する最大数を設定"),
                description: Text("保存されている履歴の数より少ない値を設定すると、設定値を超えた分は、クリップボード履歴の次回更新時に削除されます。"),
                currentValue: $tempCustomSaveHistoryValue,
                onSave: handleCustomSaveHistorySheetSave,
                onCancel: {}
            )
        }
        .sheet(isPresented: $showingCustomFileSizeSheet, onDismiss: {
            if !customFileSizeWasSaved {
                handleCustomFileSizeSheetCancel()
            }
        }) {
            CustomNumberInputSheet(
                title: Text("ファイル1つあたりの最大容量を設定"),
                description: nil,
                currentValue: $tempCustomFileSizeValue,
                selectedUnit: Binding<DataSizeUnit?>(get: { tempCustomFileSizeUnit }, set: { tempCustomFileSizeUnit = $0 ?? .megabytes }),
                onSave: handleCustomFileSizeSheetSave,
                onCancel: {}
            )
        }
        .sheet(isPresented: $showingCustomAlertSheet, onDismiss: {
            if !customAlertWasSaved {
                handleCustomAlertSheetCancel()
            }
        }) {
            CustomNumberInputSheet(
                title: Text("アラートを表示する容量を設定"),
                description: nil,
                currentValue: $tempCustomAlertValue,
                selectedUnit: Binding<DataSizeUnit?>(get: { tempCustomAlertUnit }, set: { tempCustomAlertUnit = $0 ?? .megabytes }),
                onSave: handleCustomAlertSheetSave,
                onCancel: {}
            )
        }
        .fileExporter(
            isPresented: $isShowingExportSheet,
            document: ClipboardHistoryDocument(clipboardItems: clipboardManager.clipboardHistory),
            contentType: .json,
            defaultFilename: "Clip Hold Clipboard History \(Date().formattedLocalExportFilename()).json"
        ) { result in
            clipboardImporterExporter.handleExportResult(result, from: clipboardManager)
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

    // MARK: - Picker onChange Handlers
    // Modified to accept a single newValue parameter, as oldValue is not used in the logic
    private func handleSaveOptionChange(newValue: HistoryOption) {
        if case .custom(nil) = newValue {
            tempCustomSaveHistoryValue = maxHistoryToSave // 現在の値をカスタムシートの初期値に
            customSaveHistoryWasSaved = false // シート表示前にリセット
            showingCustomSaveHistorySheet = true
        } else if newValue == .unlimited {
            maxHistoryToSave = 0 // 無制限を0として保存
        } else if let intValue = newValue.intValue {
            maxHistoryToSave = intValue
        }
        // 保存数の変更がメニュー表示数に影響する場合の処理（例：メニュー表示が「履歴の保存数に合わせる」の場合）
        if UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
            UserDefaults.standard.set(maxHistoryToSave, forKey: "maxHistoryInMenu")
        }
        // ★修正: 保存数が無制限に設定された場合、かつメニュー表示が「保存数に合わせる」ならデフォルト値に戻す
        if newValue == .unlimited && UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
            UserDefaults.standard.set(10, forKey: "maxHistoryInMenu")
        }
    }

    // Modified to accept a single newValue parameter, as oldValue is not used in the logic
    private func handleFileSizeOptionChange(newValue: DataSizeOption) {
        if case .custom(nil, nil) = newValue {
            // 現在のバイト値をカスタムシートの初期値に変換
            let (value, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: maxFileSizeToSave)
            tempCustomFileSizeValue = value
            tempCustomFileSizeUnit = unit
            customFileSizeWasSaved = false // シート表示前にリセット
            showingCustomFileSizeSheet = true
        } else if newValue == .unlimited {
            maxFileSizeToSave = 0 // 無制限は0として保存
        } else if let byteValue = newValue.byteValue {
            maxFileSizeToSave = byteValue
        }
    }

    // Modified to accept a single newValue parameter, as oldValue is not used in the logic
    private func handleAlertOptionChange(newValue: DataSizeAlertOption) {
        if case .custom(nil, nil) = newValue {
            let (value, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: largeFileAlertThreshold)
            tempCustomAlertValue = value
            tempCustomAlertUnit = unit
            customAlertWasSaved = false // シート表示前にリセット
            showingCustomAlertSheet = true
        } else if newValue == .noAlert {
            largeFileAlertThreshold = 0
        } else if let byteValue = newValue.byteValue {
            largeFileAlertThreshold = byteValue
        }
    }

    // MARK: - Custom Sheet Save/Cancel Handlers
    private func handleCustomSaveHistorySheetSave(newValue: Int) {
        customSaveHistoryWasSaved = true // 保存されたことをマーク
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
    }

    private func handleCustomSaveHistorySheetCancel() {
        if maxHistoryToSave == 0 {
            tempSelectedSaveOption = .unlimited
        } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == maxHistoryToSave }) {
            tempSelectedSaveOption = savedPreset
        } else {
            tempSelectedSaveOption = .custom(maxHistoryToSave)
        }
    }

    private func handleCustomFileSizeSheetSave(newValue: Int) {
        customFileSizeWasSaved = true // 保存されたことをマーク
        let newByteValue = tempCustomFileSizeUnit.byteValue(for: newValue)
        maxFileSizeToSave = newByteValue

        if newByteValue == 0 { // 0は無制限として扱う
            tempSelectedFileSizeOption = .unlimited
        } else if let savedPreset = DataSizeOption.presets.first(where: { $0.byteValue == newByteValue }) {
            tempSelectedFileSizeOption = savedPreset
        } else {
            tempSelectedFileSizeOption = .custom(newValue, tempCustomFileSizeUnit)
        }
    }

    private func handleCustomFileSizeSheetCancel() {
        if maxFileSizeToSave == 0 { // 0は無制限として扱う
            tempSelectedFileSizeOption = .unlimited
        } else if let savedPreset = DataSizeOption.presets.first(where: { $0.byteValue == maxFileSizeToSave }) {
            tempSelectedFileSizeOption = savedPreset
        } else {
            // 既存の値をカスタムとして設定し直す
            let (value, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: maxFileSizeToSave)
            tempCustomFileSizeValue = value
            tempCustomFileSizeUnit = unit
            tempSelectedFileSizeOption = .custom(value, unit)
        }
    }

    private func handleCustomAlertSheetSave(newValue: Int) {
        customAlertWasSaved = true // 保存されたことをマーク
        let newByteValue = tempCustomAlertUnit.byteValue(for: newValue)
        largeFileAlertThreshold = newByteValue

        if newByteValue == 0 {
            tempSelectedAlertOption = .noAlert
        } else if let savedPreset = DataSizeAlertOption.presets.first(where: { $0.byteValue == newByteValue }) {
            tempSelectedAlertOption = savedPreset
        } else {
            tempSelectedAlertOption = .custom(newValue, tempCustomAlertUnit)
        }
    }

    private func handleCustomAlertSheetCancel() {
        if largeFileAlertThreshold == 0 {
            tempSelectedAlertOption = .noAlert
        } else if let savedPreset = DataSizeAlertOption.presets.first(where: { $0.byteValue == largeFileAlertThreshold }) {
            tempSelectedAlertOption = savedPreset
        } else {
            let (value, unit) = DataSizeOption.extractValueAndUnitFromByteValue(byteValue: largeFileAlertThreshold)
            tempCustomAlertValue = value
            tempCustomAlertUnit = unit
            tempSelectedAlertOption = .custom(value, unit)
        }
    }

    // MARK: - File Management
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
    static func extractValueAndUnitFromByteValue(byteValue: Int) -> (value: Int, unit: DataSizeUnit) {
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
