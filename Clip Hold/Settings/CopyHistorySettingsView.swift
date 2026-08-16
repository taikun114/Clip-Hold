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
    
    @AppStorage("largeFileAlertThreshold") var largeFileAlertThreshold: Int = 100_000_000
    @State private var tempSelectedAlertOption: DataSizeAlertOption
    @State private var initialAlertOption: DataSizeAlertOption
    @State private var showingCustomAlertSheet = false
    
    @AppStorage("ignoreStandardPhrases") var ignoreStandardPhrases: Bool = false
    @AppStorage("folderCalculationTimeout") var folderCalculationTimeout: Double = 3.0
    
    @State private var tempCustomAlertValue: Int = 1 // カスタム入力シート用の値
    @State private var tempCustomAlertUnit: DataSizeUnit = .gigabytes // カスタム入力シート用の単位
    
    @State private var showingCustomSaveHistorySheet = false
    @State private var showingCustomFileSizeSheet = false
    @State private var showingClearHistoryConfirmation = false
    @State private var showingClearFilesConfirmation = false
    @State private var showingDecreaseHistoryLimitAlertForPicker = false
    @State private var showingDecreaseHistoryLimitAlertForSheet = false
    @State private var pendingHistorySaveValue: Int? = nil
    @State private var pendingHistorySaveOption: HistoryOption? = nil
    
    @State private var customSaveHistoryWasSaved = false
    @State private var customFileSizeWasSaved = false
    @State private var customAlertWasSaved = false
    
    @State private var tempCustomSaveHistoryValue: Int = 20
    @State private var tempCustomFileSizeValue: Int = 1
    @State private var tempCustomFileSizeUnit: DataSizeUnit = .megabytes
    
    @StateObject private var clipboardImporterExporter = ClipboardHistoryImporterExporter()
    @State private var isShowingImportSheet: Bool = false
    @State private var showingExportConfigSheet: Bool = false
    @State private var isShowingFileExporter: Bool = false
    @State private var exportIncludeFiles: Bool = true
    @State private var estimatedExportSizeMin: Int64 = 0
    @State private var estimatedExportSizeMax: Int64 = 0
    @State private var cachedSizeWithFiles: (min: Int64, max: Int64)? = nil
    @State private var cachedSizeWithoutFiles: (min: Int64, max: Int64)? = nil
    @State private var isCalculatingExportSize: Bool = false
    
    @State private var itemCount: Int = 0
    @State private var totalFolderSize: UInt64 = 0
    
    @State private var isCalculating: Bool = false
    @State private var showingRecalculateConfirmation = false
    @State private var hasUncalculatedFolders: Bool = false
    
    // MARK: - Initialization
    init() {
        // UserDefaultsから現在の設定値を取得 (Optional Intとして取得し、未設定と0を区別する)
        let savedMaxHistoryToSaveRaw = UserDefaults.standard.object(forKey: "maxHistoryToSave") as? Int
        let savedMaxFileSizeToSaveRaw = UserDefaults.standard.object(forKey: "maxFileSizeToSave") as? Int
        let savedLargeFileAlertThresholdRaw = UserDefaults.standard.object(forKey: "largeFileAlertThreshold") as? Int
        
        // maxHistoryToSaveは0が無制限を表すため、raw値をそのまま使用。nilの場合は0をデフォルトとする。
        let savedMaxHistoryToSave = savedMaxHistoryToSaveRaw ?? 0
        
        // largeFileAlertThresholdは、UserDefaultsに値がない場合（nil）にAppStorageのデフォルト値（100MB）を使用。
        // 0が明示的に設定されている場合は0として扱う。
        let savedMaxFileSizeToSave = savedMaxFileSizeToSaveRaw ?? 0
        let savedLargeFileAlertThreshold = savedLargeFileAlertThresholdRaw ?? 100_000_000
        
        
        // DEBUG print for initial values from UserDefaults
#if DEBUG
        print("DEBUG: init() - savedMaxHistoryToSaveRaw: \(savedMaxHistoryToSaveRaw ?? -1) (using \(savedMaxHistoryToSave))")
        print("DEBUG: init() - savedMaxFileSizeToSaveRaw: \(savedMaxFileSizeToSaveRaw ?? -1) (using \(savedMaxFileSizeToSave))")
        print("DEBUG: init() - savedLargeFileAlertThresholdRaw: \(savedLargeFileAlertThresholdRaw ?? -1) (using \(savedLargeFileAlertThreshold))")
#endif
        
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
    
    @ViewBuilder
    private var folderSizeDisplayView: some View {
        HStack {
            Text("保存フォルダの総容量:")
            Spacer()
            if isCalculating {
                Text("\(ByteCountFormatter.string(fromByteCount: Int64(totalFolderSize), countStyle: .file)) (計算中...)")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(totalFolderSize), countStyle: .file))
                        .foregroundStyle(.secondary)
                    Button("再計算...") {
                        showingRecalculateConfirmation = true
                    }
                }
            }
        }
    }
    
    var body: some View {
        Form {
            HistoryWindowSettingsSection()

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
                        Text("フォルダ容量計算のタイムアウト")
                        Text("フォルダがコピーされた時、容量の計算がここで設定した時間よりも長くかかったときに、コピーしたフォルダを履歴に保存するかどうかを求めるアラートが表示されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("フォルダ容量計算のタイムアウト", selection: $folderCalculationTimeout) {
                        Text("1秒").tag(1.0)
                        Text("3秒").tag(3.0)
                        Text("5秒").tag(5.0)
                        Text("10秒").tag(10.0)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
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
                    }
                    Spacer()
                    Button(action: {
#if DEBUG
                        print("DEBUG: Import button tapped. isShowingImportSheet will be true.")
#endif
                        self.isShowingImportSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("インポート...")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("書き出したクリップボード履歴のJSONファイルを読み込みます。")
                    
                    Button(action: {
                        self.cachedSizeWithFiles = nil
                        self.cachedSizeWithoutFiles = nil
                        self.showingExportConfigSheet = true
                        updateEstimatedSize()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("エクスポート...")
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
                            Text("すべての履歴を削除...")
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
                
                VStack(alignment: .leading, spacing: 4) {
                    folderSizeDisplayView
                    
                    if hasUncalculatedFolders {
                        Text("一部のフォルダ容量が計算されていないため、実際にはさらに多くの容量が使用されている可能性があります。再計算すると正しい容量が表示されるようになります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                            Text("保存フォルダを空にする...")
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
            if !clipboardImporterExporter.isExporting {
                calculateStatistics()
            }
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
            .alert("古い履歴が削除されます", isPresented: $showingDecreaseHistoryLimitAlertForSheet) {
                Button("キャンセル", role: .cancel) {
                    pendingHistorySaveValue = nil
                    pendingHistorySaveOption = nil
                }
                Button("設定", role: .destructive) {
                    if let value = pendingHistorySaveValue, let option = pendingHistorySaveOption {
                        applyHistoryLimitChange(newValue: value, option: option)
                    }
                    pendingHistorySaveValue = nil
                    pendingHistorySaveOption = nil
                    customSaveHistoryWasSaved = true
                    showingCustomSaveHistorySheet = false
                }
            } message: {
                if let newValue = pendingHistorySaveValue {
                    let diff = clipboardManager.clipboardHistory.count - newValue
                    Text("履歴の最大保存数を既に保存されている数よりも小さくしようとしています。これにより、次に履歴が更新されるときに、設定値を超えた\(diff)個の履歴が削除されます。よろしいですか？")
                }
            }
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
        .sheet(isPresented: $showingExportConfigSheet) {
            exportSheetContent
        }
        .fileImporter(
            isPresented: $isShowingImportSheet,
            allowedContentTypes: [.json, .clipholdArchive],
            allowsMultipleSelection: false
        ) { result in
#if DEBUG
            print("DEBUG: fileImporter closure called for history import.")
#endif
            clipboardImporterExporter.handleImportResult(result, into: clipboardManager) { newTotalSize in
                self.totalFolderSize = newTotalSize
                self.hasUncalculatedFolders = false
                
                // 再計算を確実に終わらせるため、もし内部で非同期処理が衝突していても最後に正しく反映させる
                self.calculateStatistics()
            }
            self.isShowingImportSheet = false
        }
        .sheet(isPresented: Binding(
            get: { clipboardImporterExporter.isExporting && !clipboardImporterExporter.importStatusText.isEmpty },
            set: { _ in }
        )) {
            importSheetContent
        }
        .alert(item: $clipboardImporterExporter.currentAlert) { alertContent in
            Alert(
                title: alertContent.title,
                message: alertContent.message,
                dismissButton: .default(Text("OK"), action: alertContent.onDismiss)
            )
        }
        .alert(item: $clipboardImporterExporter.currentConfirmationAlert) { alertContent in
            Alert(
                title: alertContent.title,
                message: alertContent.message,
                primaryButton: .default(alertContent.primaryButtonTitle, action: alertContent.primaryAction),
                secondaryButton: .cancel(alertContent.secondaryButtonTitle, action: alertContent.secondaryAction)
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
        .alert("保存フォルダの総容量を再計算", isPresented: $showingRecalculateConfirmation) {
            Button("再計算") {
                recalculateAllFolderSizes()
            }
            Button("キャンセル", role: .cancel) {
                // 何もしない
            }
        } message: {
            Text("保存フォルダに含まれているすべてのファイルとフォルダの容量を再計算します。項目の数が多いと時間がかかる場合があります。")
        }
        .alert("古い履歴が削除されます", isPresented: $showingDecreaseHistoryLimitAlertForPicker) {
            Button("キャンセル", role: .cancel) {
                cancelHistoryLimitChange()
            }
            Button("設定", role: .destructive) {
                if let value = pendingHistorySaveValue, let option = pendingHistorySaveOption {
                    applyHistoryLimitChange(newValue: value, option: option)
                }
                pendingHistorySaveValue = nil
                pendingHistorySaveOption = nil
                showingCustomSaveHistorySheet = false
            }
        } message: {
            if let newValue = pendingHistorySaveValue {
                let diff = clipboardManager.clipboardHistory.count - newValue
                Text("履歴の最大保存数を既に保存されている数よりも小さくしようとしています。これにより、次に履歴が更新されるときに、設定値を超えた\(diff)個の履歴が削除されます。よろしいですか？")
            }
        }
    }
    
    // MARK: - Picker onChange Handlers
    // Modified to accept a single newValue parameter, as oldValue is not used in the logic
    private func handleSaveOptionChange(newValue: HistoryOption) {
        if case .custom(nil) = newValue {
            tempCustomSaveHistoryValue = maxHistoryToSave // 現在の値をカスタムシートの初期値に
            customSaveHistoryWasSaved = false // シート表示前にリセット
            showingCustomSaveHistorySheet = true
        } else {
            let intValue = newValue == .unlimited ? 0 : (newValue.intValue ?? 0)
            _ = checkAndApplyHistoryLimitChange(newValue: intValue, option: newValue, fromSheet: false)
        }
    }
    
    private func checkAndApplyHistoryLimitChange(newValue: Int, option: HistoryOption, fromSheet: Bool) -> Bool {
        let currentHistoryCount = clipboardManager.clipboardHistory.count
        if newValue > 0 && newValue < currentHistoryCount {
            pendingHistorySaveValue = newValue
            pendingHistorySaveOption = option
            if fromSheet {
                showingDecreaseHistoryLimitAlertForSheet = true
            } else {
                showingDecreaseHistoryLimitAlertForPicker = true
            }
            return false
        } else {
            applyHistoryLimitChange(newValue: newValue, option: option)
            if fromSheet {
                customSaveHistoryWasSaved = true
            }
            return true
        }
    }
    
    private func applyHistoryLimitChange(newValue: Int, option: HistoryOption) {
        maxHistoryToSave = newValue
        tempSelectedSaveOption = option
        
        if UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
            UserDefaults.standard.set(maxHistoryToSave, forKey: "maxHistoryInMenu")
        }
        if option == .unlimited && UserDefaults.standard.integer(forKey: "maxHistoryInMenu") == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
            UserDefaults.standard.set(10, forKey: "maxHistoryInMenu")
        }
    }
    
    private func cancelHistoryLimitChange() {
        if maxHistoryToSave == 0 {
            tempSelectedSaveOption = .unlimited
        } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == maxHistoryToSave }) {
            tempSelectedSaveOption = savedPreset
        } else {
            tempSelectedSaveOption = .custom(maxHistoryToSave)
        }
        pendingHistorySaveValue = nil
        pendingHistorySaveOption = nil
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
    private func handleCustomSaveHistorySheetSave(newValue: Int) -> Bool {
        
        let newOption: HistoryOption
        if newValue == 0 {
            newOption = .unlimited
        } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == newValue }) {
            newOption = savedPreset
        } else {
            newOption = .custom(newValue)
        }
        
        return checkAndApplyHistoryLimitChange(newValue: newValue, option: newOption, fromSheet: true)
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
    
    private func handleCustomFileSizeSheetSave(newValue: Int) -> Bool {
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
        return true
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
    
    private func handleCustomAlertSheetSave(newValue: Int) -> Bool {
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
        return true
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
        Task.detached(priority: .background) {
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
                
                await self.clipboardManager.loadClipboardHistory()
                
                // メインスレッドでUIを更新
                await MainActor.run {
                    self.calculateStatistics()
#if DEBUG
                    print("DEBUG: All saved files cleared and clipboard history reloaded.")
#endif
                }
            } catch {
                print("Error clearing clipboard files: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateStatistics() {
        let historyCopy = clipboardManager.clipboardHistory
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            
            guard let appSpecificDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ClipHold") else {
                return
            }
            let filesDirectory = appSpecificDirectory.appendingPathComponent("ClipboardFiles", isDirectory: true)
            
            guard fileManager.fileExists(atPath: filesDirectory.path) else {
                await MainActor.run {
                    self.itemCount = 0
                    self.totalFolderSize = 0
                    self.hasUncalculatedFolders = false
                }
                return
            }
            
            // 最適化: ファイル名からアイテムを高速検索するための辞書を作成 O(N)
            var historyItemsDict: [String: ClipboardItem] = [:]
            for item in historyCopy {
                if let fileName = item.filePath?.lastPathComponent {
                    historyItemsDict[fileName] = item
                }
            }
            
            do {
                // ファイルシステムからプロパティを一括取得して高速化
                // .skipsHiddenFiles を使うと macOS の hidden 属性が付いた正当なファイルまで除外されてしまうため、
                // すべて取得した上で、OSが自動生成する .DS_Store のみ手動で除外する
                let allChildURLs = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [])
                let childURLs = allChildURLs.filter { $0.lastPathComponent != ".DS_Store" }
                
                var totalSize: UInt64 = 0
                var foundUncalculatedFolder = false
                
                for childURL in childURLs {
                    let fileName = childURL.lastPathComponent
                    let isDirectory = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    
                    if let item = historyItemsDict[fileName] {
                        if isDirectory && (!item.isSizeCalculated || item.isPartialSize) {
                            foundUncalculatedFolder = true
                        }
                        
                        if let size = item.fileSize, item.isSizeCalculated {
                            totalSize += size
                        } else if let fileSize = (try? childURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                            totalSize += UInt64(fileSize)
                        }
                    } else {
                        if let fileSize = (try? childURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                            totalSize += UInt64(fileSize)
                        }
                    }
                }
                
                let finalItemCount = childURLs.count
                await MainActor.run { [totalSize, foundUncalculatedFolder, finalItemCount] in
                    self.itemCount = finalItemCount
                    self.totalFolderSize = totalSize
                    self.hasUncalculatedFolders = foundUncalculatedFolder
                }
            } catch {
                print("Error calculating clipboard file statistics: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateEstimatedSize() {
        Task {
            isCalculatingExportSize = true
            let currentIncludeFiles = exportIncludeFiles
            
            if currentIncludeFiles {
                if let cached = cachedSizeWithFiles {
                    if exportIncludeFiles == currentIncludeFiles {
                        estimatedExportSizeMin = cached.min
                        estimatedExportSizeMax = cached.max
                        isCalculatingExportSize = false
                    }
                } else {
                    let sizes = await clipboardImporterExporter.calculateEstimatedExportSize(clipboardManager: clipboardManager, includeFiles: true)
                    cachedSizeWithFiles = sizes
                    if exportIncludeFiles == currentIncludeFiles {
                        estimatedExportSizeMin = sizes.min
                        estimatedExportSizeMax = sizes.max
                        isCalculatingExportSize = false
                    }
                }
            } else {
                if let cached = cachedSizeWithoutFiles {
                    if exportIncludeFiles == currentIncludeFiles {
                        estimatedExportSizeMin = cached.min
                        estimatedExportSizeMax = cached.max
                        isCalculatingExportSize = false
                    }
                } else {
                    let sizes = await clipboardImporterExporter.calculateEstimatedExportSize(clipboardManager: clipboardManager, includeFiles: false)
                    cachedSizeWithoutFiles = sizes
                    if exportIncludeFiles == currentIncludeFiles {
                        estimatedExportSizeMin = sizes.min
                        estimatedExportSizeMax = sizes.max
                        isCalculatingExportSize = false
                    }
                }
            }
        }
    }
    
    private func recalculateAllFolderSizes() {
        isCalculating = true
        Task.detached(priority: .userInitiated) {
            let newTotalSize = await self.clipboardManager.recalculateAllFolderSizes { _, currentSize in
                await MainActor.run {
                    self.totalFolderSize = currentSize
                }
            }
            
            await MainActor.run { [newTotalSize] in
                self.totalFolderSize = newTotalSize
                self.isCalculating = false
                // UI再描画のため
                self.clipboardManager.objectWillChange.send()
                
                // 本当に未計算のフォルダがなくなったかを再評価する
                self.calculateStatistics()
                
                // 再計算完了後に孤立ファイルのクリーンアップをトリガー
                self.clipboardManager.triggerOrphanedFilesCleanup()
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


// MARK: - HistoryWindowSettingsSection
private struct HistoryWindowSettingsSection: View {
    @EnvironmentObject var dateReloader: DateReloader
    
    @AppStorage("historyWindowAlwaysOnTop") var historyWindowAlwaysOnTop: Bool = false
    @AppStorage("historyWindowIsOverlay") var historyWindowIsOverlay: Bool = false
    @AppStorage("historyWindowOverlayTransparency") var historyWindowOverlayTransparency: Double = 0.5
    @AppStorage("dateDisplayFormatInHistoryWindow") var dateDisplayFormatInHistoryWindow: String = "absolute"
    @AppStorage("scrollToTopOnUpdate") var scrollToTopOnUpdate: Bool = true
    @AppStorage("hideNumbersInHistoryWindow") var hideNumbersInHistoryWindow: Bool = false
    @AppStorage("closeWindowOnDoubleClickInHistoryWindow") var closeWindowOnDoubleClickInHistoryWindow: Bool = false
    @AppStorage("excludeClipHoldWindowsFromAutoFilter") var excludeClipHoldWindowsFromAutoFilter: Bool = false

    var body: some View {
        // MARK: - 履歴ウィンドウ
        Section(header: Text("履歴ウィンドウ").font(.headline)) {
            HStack {
                VStack(alignment: .leading) {
                    Text("常に最前面に表示")
                    Text("ウィンドウを常に最も手前に表示します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $historyWindowAlwaysOnTop) {
                    Text("履歴ウィンドウを常に最前面に表示")
                    Text("オンにすると、履歴ウィンドウを常に最も手前に表示します。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            HStack {
                VStack(alignment: .leading) {
                    Text("オーバーレイ表示")
                    Text("フォーカスが当たっていない時は、ウィンドウを半透明にします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $historyWindowIsOverlay) {
                    Text("オーバーレイ表示")
                    Text("フォーカスが当たっていない時は、ウィンドウを半透明にします。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            HStack {
                Text("オーバーレイ時の透明度")
                    .foregroundStyle(historyWindowIsOverlay ? .primary : .secondary)
                Spacer()
                HStack {
                    Slider(
                        value: .init(
                            get: {
                                return 100 - (historyWindowOverlayTransparency * 100)
                            },
                            set: { sliderValue in
                                historyWindowOverlayTransparency = (100 - sliderValue) / 100
                            }
                        ),
                        in: 20...80,
                        step: 10
                    )
                    Text(1 - historyWindowOverlayTransparency, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(historyWindowIsOverlay ? .secondary : .tertiary)
                }
            }
            .disabled(!historyWindowIsOverlay)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            DateDisplayFormatPickerRow(selection: $dateDisplayFormatInHistoryWindow)
            HStack {
                VStack(alignment: .leading) {
                    Text("自動スクロール")
                    Text("リストが更新されたとき、リストを自動的に最も上にスクロールします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $scrollToTopOnUpdate) {
                    Text("自動スクロール")
                    Text("オンにすると、リストが更新されたとき、履歴リストを自動的に最も上にスクロールします。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            HStack {
                VStack(alignment: .leading) {
                    Text("番号を隠す")
                    Text("各項目に表示される番号を非表示にします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $hideNumbersInHistoryWindow) {
                    Text("履歴ウィンドウの番号を隠す")
                    Text("オンにすると、履歴ウィンドウの各項目に表示される番号を非表示にします。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("ダブルクリックでウィンドウを閉じる")
                    Text("項目をダブルクリックしてコピーしたときにウィンドウを閉じるようにします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $closeWindowOnDoubleClickInHistoryWindow) {
                    Text("ダブルクリックで履歴ウィンドウを閉じる")
                    Text("オンにすると、項目をダブルクリックしてコピーしたときにウィンドウを閉じるようにします。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            HStack {
                VStack(alignment: .leading) {
                    Text("アプリの「自動」フィルタリングでClip Holdのウィンドウを除外")
                    Text("アプリの「自動」フィルタリングが有効な状態でClip Holdのウィンドウ（履歴ウィンドウなど）をフォーカスしたときに、フィルタリングするアプリが切り替わらないようにします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $excludeClipHoldWindowsFromAutoFilter) {
                    Text("アプリの「自動」フィルタリングでClip Holdのウィンドウを除外")
                    Text("アプリの「自動」フィルタリングが有効な状態でClip Holdのウィンドウ（履歴ウィンドウなど）をフォーカスしたときに、フィルタリングするアプリが切り替わらないようにします。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } // End of Section: 履歴ウィンドウ
    }
}

extension CopyHistorySettingsView {
    @ViewBuilder
    private var exportSheetContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let alert = clipboardImporterExporter.sheetAlert {
                alert.title
                    .font(.headline)
                    .foregroundStyle(alert.isSuccess ? Color.primary : Color.red)
                
                alert.message
                
                Spacer(minLength: 0)
                
                HStack {
                    Spacer()
                    Button("OK") {
                        alert.onDismiss?()
                        clipboardImporterExporter.sheetAlert = nil
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                Text("履歴のエクスポート")
                    .font(.headline)
                
                if !clipboardImporterExporter.isExporting {
                    Toggle("ファイルやフォルダを含む", isOn: $exportIncludeFiles)
                        .help("Clip Hold 1.6.3またはそれ以前のバージョンに復元するにはチェックを外す必要があります。")
                        .onChange(of: exportIncludeFiles) {
                            updateEstimatedSize()
                        }
                    
                    if isCalculatingExportSize {
                        Text("推定書き出しサイズ: 計算中...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        let formattedMin = ByteCountFormatter.string(fromByteCount: estimatedExportSizeMin, countStyle: .file)
                        let formattedMax = ByteCountFormatter.string(fromByteCount: estimatedExportSizeMax, countStyle: .file)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if estimatedExportSizeMin == estimatedExportSizeMax {
                                Text("推定書き出しサイズ: 約\(formattedMin)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("推定書き出しサイズ: \(formattedMin) 〜 \(formattedMax)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("履歴の内容や保存されているファイルによって、圧縮後のサイズが大きく変動する可能性があります。")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            
            if clipboardImporterExporter.isExporting {
                ProgressView(
                    clipboardImporterExporter.exportStatusText,
                    value: clipboardImporterExporter.exportProgress < 0 ? nil : clipboardImporterExporter.exportProgress,
                    total: 1.0
                )
                .id(clipboardImporterExporter.isCancelling ? "export-cancelling" : "export-normal")
            }
                
            Spacer(minLength: 0)
            
            Text("エクスポート中はデータの整合性を保つため、ほぼすべての機能が一時的に無効化されます。エクスポートが完了すると再び利用できるようになります。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if clipboardImporterExporter.isExporting {
                HStack {
                    Spacer()
                    Button("キャンセル") {
                        clipboardImporterExporter.cancelExport()
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    .disabled(clipboardImporterExporter.isCancelling)
                }
            } else {
                HStack {
                    Button("キャンセル") {
                        showingExportConfigSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    
                    Spacer()
                    
                    Button("エクスポート") {
                        isShowingFileExporter = true
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            }
            }
        }
        .padding()
        .frame(width: 350)
        .fileExporter(
            isPresented: $isShowingFileExporter,
            document: ClipboardHistoryDocument(clipboardItems: clipboardManager.clipboardHistory),
            contentType: exportIncludeFiles ? .clipholdArchive : .json,
            defaultFilename: exportIncludeFiles ? "Clip Hold Clipboard History \(Date().formattedLocalExportFilename()).cliphold" : "Clip Hold Clipboard History \(Date().formattedLocalExportFilename()).json"
        ) { result in
            clipboardImporterExporter.handleExportResult(result, from: clipboardManager, includeFiles: exportIncludeFiles, estimatedFinalSize: estimatedExportSizeMax > 0 ? estimatedExportSizeMax : nil) {
                showingExportConfigSheet = false
            }
        }
    }
    
    @ViewBuilder
    private var importSheetContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let alert = clipboardImporterExporter.sheetAlert {
                alert.title
                    .font(.headline)
                    .foregroundStyle(alert.isSuccess ? Color.primary : Color.red)
                
                alert.message
                
                Spacer(minLength: 0)
                
                HStack {
                    Spacer()
                    Button("OK") {
                        alert.onDismiss?()
                        clipboardImporterExporter.sheetAlert = nil
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            } else if let confirmation = clipboardImporterExporter.currentConfirmationAlert {
                confirmation.title
                    .font(.headline)
                
                confirmation.message
                
                Spacer(minLength: 0)
                
                HStack {
                    Button(action: {
                        confirmation.secondaryAction()
                        clipboardImporterExporter.currentConfirmationAlert = nil
                    }) {
                        confirmation.secondaryButtonTitle
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    
                    Spacer()
                    
                    Button(action: {
                        confirmation.primaryAction()
                        clipboardImporterExporter.currentConfirmationAlert = nil
                    }) {
                        confirmation.primaryButtonTitle
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            } else {
                Text("履歴のインポート")
                    .font(.headline)
                
                ProgressView(
                    clipboardImporterExporter.importStatusText,
                    value: clipboardImporterExporter.importProgress < 0 ? nil : clipboardImporterExporter.importProgress,
                    total: 1.0
                )
                .progressViewStyle(.linear)
                .id(clipboardImporterExporter.isCancelling ? "import-cancelling" : "import-normal")
                
                Spacer(minLength: 0)
                
                Text("インポート中はデータの整合性を保つため、ほぼすべての機能が一時的に無効化されます。インポートが完了すると再び利用できるようになります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                
                HStack {
                    Spacer()
                    Button("キャンセル") {
                        clipboardImporterExporter.cancelImport()
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    .disabled(clipboardImporterExporter.isCancelling)
                }
            }
        }
        .padding()
        .frame(width: 350)
    }
}
