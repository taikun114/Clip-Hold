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
#if DEBUG
        print("DEBUG: LoginItemManager init() - Initial login item status: \(self.launchAtLogin ? "Enabled" : "Disabled")")
#endif
    }
    
    private func updateLoginItemStatus(_ enable: Bool) {
        if enable {
            // ログイン項目として登録する
            do {
                try SMAppService.mainApp.register() //
#if DEBUG
                print("DEBUG: App registered as login item.")
#endif
            } catch {
                print("ERROR: Failed to register app as login item: \(error.localizedDescription)")
                // 登録に失敗した場合、UIの状態を元に戻すか、ユーザーに通知する
                Task { @MainActor in
                    self.launchAtLogin = false // UIを元の状態に戻す
                }
            }
        } else {
            // ログイン項目から登録解除する
            do {
                try SMAppService.mainApp.unregister() //
#if DEBUG
                print("DEBUG: App unregistered from login items.")
#endif
            } catch {
                print("ERROR: Failed to unregister app from login items: \(error.localizedDescription)")
                // 登録解除に失敗した場合、UIの状態を元に戻すか、ユーザーに通知する
                Task { @MainActor in
                    self.launchAtLogin = true // UIを元の状態に戻す
                }
            }
        }
    }
    
    // ログイン項目の状態を強制的に更新し、UIに反映させるメソッド
    // アプリがフォアグラウンドになった時などに呼び出すと良い
    func refreshLoginItemStatus() {
        Task { @MainActor in
            let newStatus = SMAppService.mainApp.status == .enabled
            if self.launchAtLogin != newStatus {
                self.launchAtLogin = newStatus
#if DEBUG
                print("DEBUG: Refreshed login item status: \(self.launchAtLogin ? "Enabled" : "Disabled")")
#endif
            } else {
#if DEBUG
                print("DEBUG: Login item status unchanged during refresh.")
#endif
            }
        }
    }
    
    // システム設定のログイン項目パネルを開くヘルパーメソッド
    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

struct GeneralSettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager()
    @EnvironmentObject var dateReloader: DateReloader
    
    @AppStorage("dateDisplayFormatInMenu") var dateDisplayFormatInMenu: String = "absolute"
    @AppStorage("maxHistoryInMenu") var maxHistoryInMenu: Int = 10
    @State private var tempSelectedMenuOption: MenuHistoryOption
    @State private var initialMenuOption: MenuHistoryOption
    
    @AppStorage("maxPhrasesInMenu") var maxPhrasesInMenu: Int = 5
    @State private var tempSelectedPhraseMenuOption: HistoryOption
    @State private var initialPhraseMenuOption: HistoryOption
    @AppStorage("quickPaste") var quickPaste: Bool = false
    @AppStorage("quickPasteToPreviousApp") var quickPasteToPreviousApp: Bool = false
    @AppStorage("textOnlyQuickPaste") var textOnlyQuickPaste: Bool = false
    
    @AppStorage("isQuickOverlayShortcutEnabled") var isQuickOverlayShortcutEnabled: Bool = false
    @AppStorage("quickOverlayShortcutDelay") var quickOverlayShortcutDelay: Double = 0.0
    @AppStorage("quickOverlayShortcutPosition") var quickOverlayShortcutPosition: String = "cursor"
    
    @AppStorage("showCurrentPresetIcon") var showCurrentPresetIcon: Bool = false
    @AppStorage("hideMenuBarExtra") var hideMenuBarExtra: Bool = true
    
    @State private var showingCustomMenuHistorySheet = false
    @State private var showingCustomPhraseMenuSheet = false
    @State private var customPhraseValueWasSaved = false
    @State private var customHistoryValueWasSaved = false
    @State private var showingQuickOverlayTutorial = false
    @State private var showingScreenEdgeSettings = false
    
    @State private var tempCustomMenuHistoryValue: Int = 10
    @State private var tempCustomPhrasesInMenuValue: Int = 5
    
    init() {
        let savedMaxHistoryInMenu = UserDefaults.standard.integer(forKey: "maxHistoryInMenu")
        let savedMaxPhrasesInMenu = UserDefaults.standard.integer(forKey: "maxPhrasesInMenu")
        
#if DEBUG
        // DEBUG print for initial values from UserDefaults (accessing AppStorage directly here is fine)
        print("DEBUG: init() - savedMaxHistoryInMenu: \(savedMaxHistoryInMenu)")
#endif
        
        // MARK: - ローカル変数を宣言し、それらの値を決定するロジック
        // tempSelectedMenuOption の値を決定
        let determinedTempSelectedMenuOption: MenuHistoryOption
        var determinedTempCustomMenuHistoryValue: Int
        
        if savedMaxHistoryInMenu == 0 { // デフォルトデリートなどで0になった場合の優先処理
            determinedTempSelectedMenuOption = .preset(10)
            determinedTempCustomMenuHistoryValue = 10
            UserDefaults.standard.set(10, forKey: "maxHistoryInMenu") // UserDefaultsも確実に10に設定
        } else if savedMaxHistoryInMenu == UserDefaults.standard.integer(forKey: "maxHistoryToSave") && UserDefaults.standard.integer(forKey: "maxHistoryToSave") != 0 {
            determinedTempSelectedMenuOption = .sameAsSaved
            determinedTempCustomMenuHistoryValue = savedMaxHistoryInMenu
        } else if let savedPreset = MenuHistoryOption.presetsAndSameAsSaved.first(where: { $0.intValue == savedMaxHistoryInMenu }) {
            determinedTempSelectedMenuOption = savedPreset
            determinedTempCustomMenuHistoryValue = savedMaxHistoryInMenu
        } else {
            determinedTempSelectedMenuOption = .custom(savedMaxHistoryInMenu)
            determinedTempCustomMenuHistoryValue = savedMaxHistoryInMenu
        }
#if DEBUG
        print("DEBUG: init() - determinedTempSelectedMenuOption after logic: \(determinedTempSelectedMenuOption)") // ローカル変数をプリント
#endif
        
        // tempSelectedPhraseMenuOption の値を決定
        let determinedTempSelectedPhraseMenuOption: HistoryOption
        var determinedTempCustomPhrasesInMenuValue: Int
        
        // savedMaxPhrasesInMenu が 0 の場合、デフォルト値の 5 を使用する
        if savedMaxPhrasesInMenu == 0 {
            // savedMaxPhrasesInMenu はletなので変更できない
            determinedTempCustomPhrasesInMenuValue = 5
            UserDefaults.standard.set(5, forKey: "maxPhrasesInMenu") // UserDefaultsは更新
        } else {
            determinedTempCustomPhrasesInMenuValue = savedMaxPhrasesInMenu
        }
        
        if let preset = HistoryOption.presets.first(where: { $0.intValue == determinedTempCustomPhrasesInMenuValue }) {
            determinedTempSelectedPhraseMenuOption = preset
        } else {
            determinedTempSelectedPhraseMenuOption = .custom(determinedTempCustomPhrasesInMenuValue)
        }
        
        // MARK: - すべての @State プロパティの初期化を一括で行う
        _tempSelectedMenuOption = State(initialValue: determinedTempSelectedMenuOption)
        _tempCustomMenuHistoryValue = State(initialValue: determinedTempCustomMenuHistoryValue)
        
        _tempSelectedPhraseMenuOption = State(initialValue: determinedTempSelectedPhraseMenuOption)
        _tempCustomPhrasesInMenuValue = State(initialValue: determinedTempCustomPhrasesInMenuValue)
        
        // initialオプションは、対応するtempオプションが確定した後に初期化
        _initialMenuOption = State(initialValue: determinedTempSelectedMenuOption)
        _initialPhraseMenuOption = State(initialValue: determinedTempSelectedPhraseMenuOption)
    }
    
    var body: some View {
        Form {
            // MARK: - 基本
            Section(header: Text("基本").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("ログイン時に開く")
                        Text("Macのログイン時にClip Holdを自動で開くようにします。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $loginItemManager.launchAtLogin) {
                        Text("ログイン時に開く")
                        Text("オンにすると、Macのログイン時にClip Holdを自動で開くようにします。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: 基本
            
            // MARK: - クイックペースト
            Section(header: Text("クイックペースト").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("クイックペースト")
                        Text("定型文またはコピー履歴をメニューから選択したとき、またはショートカットキーでコピーしたときに、Command + Vキー操作を送信します。アクセシビリティの許可が必要です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $quickPaste) {
                        Text("クイックペースト")
                        Text("オンにすると、定型文またはコピー履歴をメニューから選択したとき、またはショートカットキーでコピーしたときに、Command + Vキー操作を送信します。アクセシビリティの許可が必要です。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("テキストに限定")
                            .foregroundStyle(quickPaste ? .primary : .secondary)
                        Text("履歴項目がテキストである場合のみクイックペーストを行うようにします。")
                            .font(.caption)
                            .foregroundStyle(quickPaste ? .secondary : .tertiary)
                    }
                    Spacer()
                    Toggle(isOn: $textOnlyQuickPaste) {
                        Text("テキストに限定")
                        Text("オンにすると、履歴項目がテキストである場合のみクイックペーストを行うようにします。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                    // quickPasteがオフの時にグレイアウトする
                    .disabled(!quickPaste)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("直前のテキストフィールドにクイックペースト")
                            .foregroundStyle(quickPaste ? .primary : .secondary)
                        Text("履歴と定型文ウィンドウからコピーしたときに、直前まで選択されていたテキストフィールドがあるアプリにフォーカスを戻してクイックペーストを実行します。このオプションをオンにすると、新規コピーや変更してコピー機能でもクイックペーストが利用可能になります。アクセシビリティの許可が必要です。")
                            .font(.caption)
                            .foregroundStyle(quickPaste ? .secondary : .tertiary)
                    }
                    Spacer()
                    Toggle(isOn: $quickPasteToPreviousApp) {
                        Text("直前のテキストフィールドにクイックペースト")
                        Text("オンにすると、履歴と定型文ウィンドウからコピーしたときに、直前まで選択されていたテキストフィールドがあるアプリにフォーカスを戻してクイックペーストを実行します。このオプションをオンにすると、新規コピーや変更してコピー機能でもクイックペーストが利用可能になります。アクセシビリティの許可が必要です。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!quickPaste)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: クイックペースト
            
            // MARK: - クイックオーバーレイ
            Section(
                header: Text("クイックオーバーレイ").font(.headline),
                footer: HStack {
                    Spacer()
                    Button("スクリーンエッジ...") {
                        showingScreenEdgeSettings = true
                    }
                    .offset(x: tutorialButtonOffset)
                    
                    Button("クイックオーバーレイの使い方...") {
                        showingQuickOverlayTutorial = true
                    }
                    .offset(x: tutorialButtonOffset)
                }
            ) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("ショートカットキーで表示")
                        Text("設定されたショートカットキーを押し続けている間だけオーバーレイが表示され、コピーしたい項目にポインタを合わせてショートカットキーを離すことで簡単にコピーできます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $isQuickOverlayShortcutEnabled) {
                        Text("ショートカットキーで表示")
                        Text("オンにすると、設定されたショートカットキーを押し続けている間だけオーバーレイが表示され、コピーしたい項目にポインタを合わせてショートカットキーを離すことで簡単にコピーできます。この機能はVoiceOverでの操作に最適化されていないため、VoiceOverをご利用の方は、クイックオーバーレイの代わりに履歴ウィンドウや定型文ウィンドウをご利用ください。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("表示までの時間")
                            .foregroundStyle(isQuickOverlayShortcutEnabled ? .primary : .secondary)
                        Text("クイックオーバーレイが表示されるまでショートカットキーを押し続ける時間を指定します。")
                            .font(.caption)
                            .foregroundStyle(isQuickOverlayShortcutEnabled ? .secondary : .tertiary)
                    }
                    Spacer()
                    Slider(value: $quickOverlayShortcutDelay, in: 0.0...2.0, step: 0.1) {
                        Text("表示までの時間")
                        Text("クイックオーバーレイが表示されるまでショートカットキーを押し続ける時間を指定します。")
                    }
                    .frame(width: 150)
                    .labelsHidden()
                    .disabled(!isQuickOverlayShortcutEnabled)
                    
                    Text(String(format: "%.1f秒", quickOverlayShortcutDelay))
                        .frame(width: 40, alignment: .trailing)
                        .foregroundStyle(isQuickOverlayShortcutEnabled ? .secondary : .tertiary)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("表示場所")
                            .foregroundStyle(isQuickOverlayShortcutEnabled ? .primary : .secondary)
                        Text("クイックオーバーレイが表示される画面上の場所を選択します。")
                            .font(.caption)
                            .foregroundStyle(isQuickOverlayShortcutEnabled ? .secondary : .tertiary)
                    }
                    Spacer()
                    Picker("クイックオーバーレイの表示場所", selection: $quickOverlayShortcutPosition) {
                        Label("ポインタ付近", systemImage: "contextualmenu.and.cursorarrow").tag("cursor")
                        
                        Divider()
                        
                        if #available(macOS 15.0, *) {
                            Label("中央", systemImage: "inset.filled.center.rectangle").tag("center")
                        } else {
                            Label("中央", systemImage: "rectangle.center.inset.filled").tag("center")
                        }
                        Label("上", systemImage: "arrow.up").tag("top")
                        Label("右上", systemImage: "arrow.up.right").tag("topRight")
                        Label("右", systemImage: "arrow.right").tag("right")
                        Label("右下", systemImage: "arrow.down.right").tag("bottomRight")
                        Label("下", systemImage: "arrow.down").tag("bottom")
                        Label("左下", systemImage: "arrow.down.left").tag("bottomLeft")
                        Label("左", systemImage: "arrow.left").tag("left")
                        Label("左上", systemImage: "arrow.up.left").tag("topLeft")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(!isQuickOverlayShortcutEnabled)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: クイックオーバーレイ
            
            // MARK: - メニュー
            Section(header: Text("メニュー").font(.headline)) {
                // 定型文の最大表示数
                HStack {
                    VStack(alignment: .leading) {
                        Text("定型文の最大表示数")
                        Text("メニューに表示される定型文の最大数を設定します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Picker("定型文の最大表示数", selection: $tempSelectedPhraseMenuOption) {
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
                    .onChange(of: tempSelectedPhraseMenuOption) { // ここを tempSelectedPhraseMenuOption に修正
                        if case .custom(nil) = tempSelectedPhraseMenuOption {
                            tempCustomPhrasesInMenuValue = maxPhrasesInMenu // 現在の値をカスタムシートの初期値に
                            customPhraseValueWasSaved = false // シート表示前にリセット
                            showingCustomPhraseMenuSheet = true
                        } else if let intValue = tempSelectedPhraseMenuOption.intValue {
                            maxPhrasesInMenu = intValue
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // 履歴の最大表示数
                HStack {
                    VStack(alignment: .leading) {
                        Text("履歴の最大表示数")
                        Text("メニューに表示される履歴の最大数を設定します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Picker("履歴の最大表示数", selection: $tempSelectedMenuOption) {
                        ForEach(MenuHistoryOption.presetsAndSameAsSaved.filter { option in
                            if case .sameAsSaved = option {
                                // UserDefaults.standard.integer(forKey: "maxHistoryToSave") が 0 (無制限) でない場合のみ .sameAsSaved を表示
                                return UserDefaults.standard.integer(forKey: "maxHistoryToSave") != 0
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
                    .onChange(of: tempSelectedMenuOption) { // ここを tempSelectedMenuOption に修正
                        if case .custom(nil) = tempSelectedMenuOption {
                            tempCustomMenuHistoryValue = maxHistoryInMenu
                            customHistoryValueWasSaved = false // シート表示前にリセット
                            showingCustomMenuHistorySheet = true
                        } else if tempSelectedMenuOption == .sameAsSaved {
                            maxHistoryInMenu = UserDefaults.standard.integer(forKey: "maxHistoryToSave")
                        } else if let intValue = tempSelectedMenuOption.intValue {
                            maxHistoryInMenu = intValue
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                // 日付と時刻の表示方法
                HStack {
                    VStack(alignment: .leading) {
                        Text("日付と時刻の表示方法")
                        
                        let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: dateReloader.now)!
                        let exampleText: String = {
                            let absolutePart = fiveMinutesAgo.formattedAsAbsolute()
                            let relativePart = RelativeDateTimeFormatter().localizedString(for: fiveMinutesAgo, relativeTo: dateReloader.now)
                            
                            switch dateDisplayFormatInMenu {
                            case "absolute":
                                return absolutePart
                            case "relative":
                                return relativePart
                            case "both_abs_rel_paren":
                                return "\(absolutePart) (\(relativePart))"
                            case "both_abs_rel_hyphen":
                                return "\(absolutePart) - \(relativePart)"
                            case "both_rel_abs_paren":
                                return "\(relativePart) (\(absolutePart))"
                            case "both_rel_abs_hyphen":
                                return "\(relativePart) - \(absolutePart)"
                            default:
                                return absolutePart
                            }
                        }()
                        
                        Text("コピーされた日付の表示方法を変更します。\n例: \(exampleText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("日付と時刻の表示方法", selection: $dateDisplayFormatInMenu) {
                        Text("絶対的").tag("absolute")
                        Text("相対的").tag("relative")
                        Text("両方: 絶対的 (相対的)").tag("both_abs_rel_paren")
                        Text("両方: 絶対的 - 相対的").tag("both_abs_rel_hyphen")
                        Text("両方: 相対的 (絶対的)").tag("both_rel_abs_paren")
                        Text("両方: 相対的 - 絶対的").tag("both_rel_abs_hyphen")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("現在のプリセットアイコンを表示する")
                        Text("メニューバーに、Clip Holdアイコンの代わりに現在選択されているプリセットのアイコンを表示します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $showCurrentPresetIcon) {
                        Text("現在のプリセットアイコンを表示する")
                        Text("メニューバーに、Clip Holdアイコンの代わりに現在選択されているプリセットのアイコンを表示します。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("メニューバーアイコンを隠す")
                        Text("Clip Holdのメニューバーアイコンを一時的に非表示にします。もう一度アプリを開くと再び表示されるようになります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $hideMenuBarExtra) {
                        Text("メニューバーアイコンを隠す")
                        Text("Clip Holdのメニューバーアイコンを一時的に非表示にします。もう一度アプリを開くと再び表示されるようになります。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: メニュー
        } // End of Form
        .formStyle(.grouped)
        .onAppear {
            // View が表示されるたびにログイン項目の状態を最新にする
            loginItemManager.refreshLoginItemStatus()
        }
        .sheet(isPresented: $showingCustomMenuHistorySheet, onDismiss: {
            if !customHistoryValueWasSaved {
                // ユーザーがキャンセルまたはESCで閉じた場合、選択を元に戻す
                if let savedPreset = MenuHistoryOption.presetsAndSameAsSaved.first(where: { $0.intValue == maxHistoryInMenu }) {
                    tempSelectedMenuOption = savedPreset
                } else if maxHistoryInMenu == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
                    tempSelectedMenuOption = .sameAsSaved
                } else {
                    tempSelectedMenuOption = .custom(maxHistoryInMenu)
                }
            }
        }) {
            CustomNumberInputSheet(
                title: Text("メニューに表示する履歴の最大数を設定"),
                description: nil,
                currentValue: $tempCustomMenuHistoryValue,
                onSave: { newValue -> Bool in
                    maxHistoryInMenu = newValue
                    customHistoryValueWasSaved = true // 保存されたことをマーク
                    
                    if newValue == UserDefaults.standard.integer(forKey: "maxHistoryToSave") {
                        tempSelectedMenuOption = .sameAsSaved
                    } else if let savedPreset = MenuHistoryOption.presetsAndSameAsSaved.first(where: { $0.intValue == newValue }) {
                        tempSelectedMenuOption = savedPreset
                    } else {
                        tempSelectedMenuOption = .custom(newValue)
                    }
                    return true
                },
                onCancel: {
                    // onDismissで処理するため、ここは空で良い
                }
            )
        }
        .sheet(isPresented: $showingCustomPhraseMenuSheet, onDismiss: {
            if !customPhraseValueWasSaved {
                // ユーザーがキャンセルまたはESCで閉じた場合、選択を元に戻す
                if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == maxPhrasesInMenu }) {
                    tempSelectedPhraseMenuOption = savedPreset
                } else {
                    tempSelectedPhraseMenuOption = .custom(maxPhrasesInMenu)
                }
            }
        }) {
            CustomNumberInputSheet(
                title: Text("メニューに表示する定型文の最大数を設定"),
                description: nil,
                currentValue: $tempCustomPhrasesInMenuValue,
                onSave: { newValue -> Bool in
                    maxPhrasesInMenu = newValue
                    customPhraseValueWasSaved = true // 保存されたことをマーク
                    
                    if let savedPreset = HistoryOption.presets.first(where: { $0.intValue == newValue }) {
                        tempSelectedPhraseMenuOption = savedPreset
                    } else {
                        tempSelectedPhraseMenuOption = .custom(newValue)
                    }
                    return true
                },
                onCancel: {
                    // onDismissで処理するため、ここは空で良い
                }
            )
        }
        .sheet(isPresented: $showingQuickOverlayTutorial) {
            QuickOverlayTutorialView()
        }
        .sheet(isPresented: $showingScreenEdgeSettings) {
            ScreenEdgeSettingsView()
        }
    }
    
    private var tutorialButtonOffset: CGFloat {
        if #available(macOS 26, *) {
            return 10
        } else {
            return 0
        }
    }
}

#Preview {
    GeneralSettingsView()
}
