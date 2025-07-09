import SwiftUI
import Foundation
import ServiceManagement

// MARK: - LoginItemManager クラスの定義
class LoginItemManager: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            // launchAtLogin の値が変更されたときに自動的に呼び出されます
            updateLoginItemStatus(launchAtLogin)
        }
    }

    init() {
        // 初期化時に現在のログイン項目の状態を読み込む
        // SMAppService.mainApp.status は現在の登録状態を返します
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        print("DEBUG: LoginItemManager init() - Initial login item status: \(self.launchAtLogin ? "Enabled" : "Disabled")")
    }

    private func updateLoginItemStatus(_ enable: Bool) {
        if enable {
            // ログイン項目として登録する
            do {
                try SMAppService.mainApp.register() //
                print("DEBUG: App registered as login item.")
            } catch {
                print("ERROR: Failed to register app as login item: \(error.localizedDescription)")
                // 登録に失敗した場合、UIの状態を元に戻すか、ユーザーに通知する
                DispatchQueue.main.async {
                    self.launchAtLogin = false // UIを元の状態に戻す
                }
            }
        } else {
            // ログイン項目から登録解除する
            do {
                try SMAppService.mainApp.unregister() //
                print("DEBUG: App unregistered from login items.")
            } catch {
                print("ERROR: Failed to unregister app from login items: \(error.localizedDescription)")
                // 登録解除に失敗した場合、UIの状態を元に戻すか、ユーザーに通知する
                DispatchQueue.main.async {
                    self.launchAtLogin = true // UIを元の状態に戻す
                }
            }
        }
    }
    
    // ログイン項目の状態を強制的に更新し、UIに反映させるメソッド
    // アプリがフォアグラウンドになった時などに呼び出すと良い
    func refreshLoginItemStatus() {
        DispatchQueue.main.async {
            let newStatus = SMAppService.mainApp.status == .enabled
            if self.launchAtLogin != newStatus {
                self.launchAtLogin = newStatus
                print("DEBUG: Refreshed login item status: \(self.launchAtLogin ? "Enabled" : "Disabled")")
            } else {
                print("DEBUG: Login item status unchanged during refresh.")
            }
        }
    }

    // システム設定のログイン項目パネルを開くヘルパーメソッド
    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems() //
    }
}

struct GeneralSettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager()

    @AppStorage("maxHistoryToSave") var maxHistoryToSave: Int = 0 // 無制限を0で表す
    @State private var tempSelectedSaveOption: HistoryOption
    @State private var initialSaveOption: HistoryOption

    @AppStorage("maxHistoryInMenu") var maxHistoryInMenu: Int = 10
    @State private var tempSelectedMenuOption: MenuHistoryOption
    @State private var initialMenuOption: MenuHistoryOption

    @AppStorage("maxPhrasesInMenu") var maxPhrasesInMenu: Int = 5
    @State private var tempSelectedPhraseMenuOption: HistoryOption
    @State private var initialPhraseMenuOption: HistoryOption

    @AppStorage("showLineNumbersInHistoryWindow") var showLineNumbersInHistoryWindow: Bool = false
    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false
    @AppStorage("scrollToTopOnUpdate") var scrollToTopOnUpdate: Bool = false // 追加

    @AppStorage("showLineNumbersInStandardPhraseWindow") var showLineNumbersInStandardPhraseWindow: Bool = false
    @AppStorage("preventStandardPhraseWindowCloseOnDoubleClick") var preventStandardPhraseWindowCloseOnDoubleClick: Bool = false
    @AppStorage("historyWindowAlwaysOnTop") var historyWindowAlwaysOnTop: Bool = false
    @AppStorage("standardPhraseWindowAlwaysOnTop") var standardPhraseWindowAlwaysOnTop: Bool = false

    @AppStorage("quickPaste") var quickPaste: Bool = false
    @AppStorage("hideMenuBarExtra") var hideMenuBarExtra: Bool = true

    @AppStorage("scanQRCodeImage") var scanQRCodeImage: Bool = false

    @State private var showingCustomSaveHistorySheet = false
    @State private var showingCustomMenuHistorySheet = false
    @State private var showingCustomPhraseMenuSheet = false
    
    @State private var tempCustomSaveHistoryValue: Int = 20
    @State private var tempCustomMenuHistoryValue: Int = 10
    @State private var tempCustomPhrasesInMenuValue: Int = 5


    init() {
        let savedMaxHistoryToSave = UserDefaults.standard.integer(forKey: "maxHistoryToSave")
        var savedMaxHistoryInMenu = UserDefaults.standard.integer(forKey: "maxHistoryInMenu")
        var savedMaxPhrasesInMenu = UserDefaults.standard.integer(forKey: "maxPhrasesInMenu")

        // DEBUG print for initial values from UserDefaults (accessing AppStorage directly here is fine)
        print("DEBUG: init() - savedMaxHistoryToSave: \(savedMaxHistoryToSave)")
        print("DEBUG: init() - savedMaxHistoryInMenu: \(savedMaxHistoryInMenu)")


        // MARK: - ローカル変数を宣言し、それらの値を決定するロジック
        // tempSelectedSaveOption の値を決定
        let determinedTempSelectedSaveOption: HistoryOption
        var determinedTempCustomSaveHistoryValue: Int

        if savedMaxHistoryToSave == 0 {
            determinedTempSelectedSaveOption = .unlimited
            determinedTempCustomSaveHistoryValue = 20
            // maxHistoryToSaveが0（無制限）で、maxHistoryInMenuも0（不正な状態）の場合の修正
            if savedMaxHistoryInMenu == 0 {
                savedMaxHistoryInMenu = 10 // UI表示と整合性を取るため一時変数を10に設定
                UserDefaults.standard.set(10, forKey: "maxHistoryInMenu") // UserDefaultsも更新して次回起動時も正しくなるように
            }
        } else if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == savedMaxHistoryToSave }) {
            determinedTempSelectedSaveOption = savedPreset
            determinedTempCustomSaveHistoryValue = savedMaxHistoryToSave
        } else {
            determinedTempSelectedSaveOption = .custom(savedMaxHistoryToSave)
            determinedTempCustomSaveHistoryValue = savedMaxHistoryToSave
        }
        
        // tempSelectedMenuOption の値を決定
        let determinedTempSelectedMenuOption: MenuHistoryOption
        var determinedTempCustomMenuHistoryValue: Int

        if savedMaxHistoryInMenu == 0 { // デフォルトデリートなどで0になった場合の優先処理
            determinedTempSelectedMenuOption = .preset(10)
            determinedTempCustomMenuHistoryValue = 10
            UserDefaults.standard.set(10, forKey: "maxHistoryInMenu") // UserDefaultsも確実に10に設定
        } else if savedMaxHistoryInMenu == savedMaxHistoryToSave && savedMaxHistoryToSave != 0 {
            determinedTempSelectedMenuOption = .sameAsSaved
            determinedTempCustomMenuHistoryValue = savedMaxHistoryInMenu
        } else if let savedPreset = MenuHistoryOption.presetsAndSameAsSaved.first(where: { $0.intValue == savedMaxHistoryInMenu }) {
            determinedTempSelectedMenuOption = savedPreset
            determinedTempCustomMenuHistoryValue = savedMaxHistoryInMenu
        } else {
            determinedTempSelectedMenuOption = .custom(savedMaxHistoryInMenu)
            determinedTempCustomMenuHistoryValue = savedMaxHistoryInMenu
        }
        print("DEBUG: init() - determinedTempSelectedMenuOption after logic: \(determinedTempSelectedMenuOption)") // ローカル変数をプリント

        // tempSelectedPhraseMenuOption の値を決定
        let determinedTempSelectedPhraseMenuOption: HistoryOption
        var determinedTempCustomPhrasesInMenuValue: Int

        // savedMaxPhrasesInMenu が 0 の場合、デフォルト値の 5 を使用する
        if savedMaxPhrasesInMenu == 0 {
            savedMaxPhrasesInMenu = 5
            UserDefaults.standard.set(5, forKey: "maxPhrasesInMenu") // UserDefaultsも更新
        }
        
        if let preset = HistoryOption.presets.first(where: { $0.intValue == savedMaxPhrasesInMenu }) {
            determinedTempSelectedPhraseMenuOption = preset
            determinedTempCustomPhrasesInMenuValue = savedMaxPhrasesInMenu
        } else {
            determinedTempSelectedPhraseMenuOption = .custom(savedMaxPhrasesInMenu)
            determinedTempCustomPhrasesInMenuValue = savedMaxPhrasesInMenu
        }

        // MARK: - すべての @State プロパティの初期化を一括で行う
        _tempSelectedSaveOption = State(initialValue: determinedTempSelectedSaveOption)
        _tempCustomSaveHistoryValue = State(initialValue: determinedTempCustomSaveHistoryValue)

        _tempSelectedMenuOption = State(initialValue: determinedTempSelectedMenuOption)
        _tempCustomMenuHistoryValue = State(initialValue: determinedTempCustomMenuHistoryValue)

        _tempSelectedPhraseMenuOption = State(initialValue: determinedTempSelectedPhraseMenuOption)
        _tempCustomPhrasesInMenuValue = State(initialValue: determinedTempCustomPhrasesInMenuValue)

        // initialオプションは、対応するtempオプションが確定した後に初期化
        _initialSaveOption = State(initialValue: determinedTempSelectedSaveOption)
        _initialMenuOption = State(initialValue: determinedTempSelectedMenuOption)
        _initialPhraseMenuOption = State(initialValue: determinedTempSelectedPhraseMenuOption)
    }

    var body: some View {
        Form {
            // MARK: - Clip Holdの設定
            Section(header: Text("Clip Holdの設定").font(.headline)) {
                HStack {
                    Text("ログイン時に開く")
                    Spacer()
                    Toggle(isOn: $loginItemManager.launchAtLogin) {
                        Text("ログイン時に開く")
                        Text("Clip Holdをログイン時に開くかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

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
                        if tempSelectedMenuOption == .sameAsSaved {
                            maxHistoryInMenu = maxHistoryToSave
                        }
                        // ★修正: 保存数が無制限に設定された場合、かつメニュー表示が「保存数に合わせる」ならデフォルト値に戻す
                        if tempSelectedSaveOption == .unlimited && tempSelectedMenuOption == .sameAsSaved {
                            tempSelectedMenuOption = .preset(10) // デフォルト値（10個）に設定
                            maxHistoryInMenu = 10
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    VStack(alignment: .leading) {
                        Text("クイックペースト")
                        Text("このオプションをオンにすると、定型文またはコピー履歴をメニューから選択したとき、またはショートカットキーでコピーしたときに、Command + Vキー操作が送信されます。アクセシビリティの許可が必要です。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $quickPaste) {
                        Text("クイックペースト")
                        Text("このオプションをオンにすると、定型文またはコピー履歴をメニューから選択したとき、またはショートカットキーでコピーしたときに、Command + Vキー操作が送信されます。アクセシビリティの許可が必要です。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    VStack(alignment: .leading) {
                        Text("QRコード画像をスキャンする")
                        Text("このオプションをオンにすると、QRコードが含まれた画像をコピーしたときに、QRコードの内容が履歴に追加されます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $scanQRCodeImage) {
                        Text("QRコード画像をスキャンする")
                        Text("このオプションをオンにすると、QRコードが含まれた画像をコピーしたときに、QRコードの内容が履歴に追加されます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: Clip Holdの設定

            // MARK: - メニュー
            Section(header: Text("メニュー").font(.headline)) {
                // メニューに表示する定型文の最大数
                HStack {
                    Text("メニューに表示する定型文の最大数:")
                    Spacer()

                    Picker("メニューに表示する定型文の最大数", selection: $tempSelectedPhraseMenuOption) {
                        ForEach(HistoryOption.presets) { option in
                            Text(option.stringValue)
                                .tag(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Text("カスタム...")
                            .tag(HistoryOption.custom(nil))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !HistoryOption.presets.contains(where: { $0.intValue == maxPhrasesInMenu }) && tempSelectedPhraseMenuOption != .custom(nil) {
                            Divider()
                            Text("カスタム: \(maxPhrasesInMenu)")
                                .tag(HistoryOption.custom(maxPhrasesInMenu))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: tempSelectedMenuOption) {
                        if case .custom(nil) = tempSelectedMenuOption {
                            tempCustomMenuHistoryValue = maxHistoryInMenu
                            showingCustomMenuHistorySheet = true
                        } else if tempSelectedMenuOption == .sameAsSaved {
                            maxHistoryInMenu = maxHistoryToSave
                        } else if let intValue = tempSelectedMenuOption.intValue {
                            maxHistoryInMenu = intValue
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                // メニューに表示する履歴の最大数
                HStack {
                    Text("メニューに表示する履歴の最大数:")
                    Spacer()

                    Picker("メニューに表示する履歴の最大数", selection: $tempSelectedMenuOption) {
                        ForEach(MenuHistoryOption.presetsAndSameAsSaved.filter { option in
                            if case .sameAsSaved = option {
                                // tempSelectedSaveOption が .unlimited (無制限) でない場合のみ .sameAsSaved を表示
                                return tempSelectedSaveOption != .unlimited
                            }
                            return true // その他のプリセットは常に表示
                        }) { option in
                            Text(option.stringValue)
                                .tag(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Text("カスタム...")
                            .tag(MenuHistoryOption.custom(nil))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 条件を MenuHistoryOption.presetsAndSameAsSaved に合わせて調整
                        if !MenuHistoryOption.presetsAndSameAsSaved.contains(where: { $0.intValue == maxHistoryInMenu }) &&
                           tempSelectedMenuOption != .custom(nil) &&
                           tempSelectedMenuOption != .sameAsSaved {
                            Divider()
                            Text("カスタム: \(maxHistoryInMenu)")
                                .tag(MenuHistoryOption.custom(maxHistoryInMenu))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: tempSelectedPhraseMenuOption) { // ここは $tempSelectedPhraseMenuOption の onChange が正しい
                        if case .custom(nil) = tempSelectedPhraseMenuOption {
                            tempCustomPhrasesInMenuValue = maxPhrasesInMenu // 現在の値をカスタムシートの初期値に
                            showingCustomPhraseMenuSheet = true
                        } else if let intValue = tempSelectedPhraseMenuOption.intValue {
                            maxPhrasesInMenu = intValue
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))


                HStack {
                    VStack(alignment: .leading) {
                        Text("メニューバーアイコンを一時的に非表示")
                        Text("このオプションをオンにすると、メニューバーアイコンが一時的に非表示になります。もう一度アプリを開くと再び表示されるようになります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $hideMenuBarExtra) {
                        Text("メニューバーアイコンを一時的に非表示")
                        Text("このオプションをオンにすると、メニューバーアイコンが一時的に非表示になります。もう一度アプリを開くと再び表示されるようになります。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: メニュー

            // MARK: - 定型文ウィンドウ
            Section(header: Text("定型文ウィンドウ").font(.headline)) {
                HStack {
                    Text("番号を表示する")
                    Spacer()
                    Toggle(isOn: $showLineNumbersInStandardPhraseWindow) {
                        Text("定型文ウィンドウに番号を表示する")
                        Text("定型文ウィンドウの各項目に番号を表示するかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    Text("ダブルクリック時にウィンドウを閉じない")
                    Spacer()
                    Toggle(isOn: $preventStandardPhraseWindowCloseOnDoubleClick) {
                        Text("ダブルクリック時に定型文ウィンドウを閉じない")
                        Text("定型文ウィンドウに表示される各項目をダブルクリックしてコピーしたときにウィンドウを閉じないようにするかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                HStack {
                    Text("常に最前面に表示")
                    Spacer()
                    Toggle(isOn: $standardPhraseWindowAlwaysOnTop) {
                        Text("定型文ウィンドウを常に最前面に表示")
                        Text("定型文ウィンドウを常に最前面に表示するかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: 定型文ウィンドウ

            // MARK: - 履歴をウィンドウ
            Section(header: Text("履歴ウィンドウ").font(.headline)) {
                HStack {
                    Text("番号を表示する")
                    Spacer()
                    Toggle(isOn: $showLineNumbersInHistoryWindow) {
                        Text("履歴ウィンドウに番号を表示する")
                        Text("履歴ウィンドウの各項目に番号を表示するかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    Text("ダブルクリック時にウィンドウを閉じない")
                    Spacer()
                    Toggle(isOn: $preventWindowCloseOnDoubleClick) {
                        Text("ダブルクリック時に履歴ウィンドウを閉じない")
                        Text("履歴ウィンドウに表示される各項目をダブルクリックしてコピーしたときにウィンドウを閉じないようにするかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                HStack {
                    Text("常に最前面に表示")
                    Spacer()
                    Toggle(isOn: $historyWindowAlwaysOnTop) {
                        Text("履歴ウィンドウを常に最前面に表示")
                        Text("履歴ウィンドウを常に最前面に表示するかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                HStack {
                    Text("リストが更新されたら最も上にスクロールする")
                    Spacer()
                    Toggle(isOn: $scrollToTopOnUpdate) {
                        Text("リストが更新されたら最も上にスクロールする")
                        Text("履歴リストが更新されたときに自動的に一番上にスクロールするかどうかを切り替えます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: 履歴ウィンドウ
        } // End of Form
        .formStyle(.grouped)
        .onAppear {
            // View が表示されるたびにログイン項目の状態を最新にする
            loginItemManager.refreshLoginItemStatus()
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

                    if tempSelectedMenuOption == .sameAsSaved {
                        maxHistoryInMenu = maxHistoryToSave
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
        .sheet(isPresented: $showingCustomMenuHistorySheet) {
            CustomNumberInputSheet(
                title: Text("メニューに表示する履歴の最大数を設定"),
                description: nil,
                currentValue: $tempCustomMenuHistoryValue,
                onSave: { newValue in
                    maxHistoryInMenu = newValue

                    if newValue == maxHistoryToSave {
                        tempSelectedMenuOption = .sameAsSaved
                    } else if let savedPreset = MenuHistoryOption.presetsAndSameAsSaved.first(where: { $0.intValue == newValue }) {
                        tempSelectedMenuOption = savedPreset
                    } else {
                        tempSelectedMenuOption = .custom(newValue)
                    }
                },
                onCancel: {
                    if let savedPreset = MenuHistoryOption.presetsAndSameAsSaved.first(where: { $0.intValue == maxHistoryInMenu }) {
                        tempSelectedMenuOption = savedPreset
                    } else if maxHistoryInMenu == maxHistoryToSave {
                        tempSelectedMenuOption = .sameAsSaved
                    } else {
                        tempSelectedMenuOption = .custom(maxHistoryInMenu)
                    }
                }
            )
        }
        .sheet(isPresented: $showingCustomPhraseMenuSheet) {
            CustomNumberInputSheet(
                title: Text("メニューに表示する定型文の最大数を設定"),
                description: nil,
                currentValue: $tempCustomPhrasesInMenuValue,
                onSave: { newValue in
                    maxPhrasesInMenu = newValue

                    if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == newValue }) {
                        tempSelectedPhraseMenuOption = savedPreset
                    } else {
                        tempSelectedPhraseMenuOption = .custom(newValue)
                    }
                },
                onCancel: {
                    if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == maxPhrasesInMenu }) {
                        tempSelectedPhraseMenuOption = savedPreset
                    } else {
                        tempSelectedPhraseMenuOption = .custom(maxPhrasesInMenu)
                    }
                }
            )
        }
    }
}

#Preview {
    GeneralSettingsView()
}
