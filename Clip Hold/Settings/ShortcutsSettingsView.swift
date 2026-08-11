import SwiftUI
import KeyboardShortcuts


struct ShortcutsSettingsView: View {
    @StateObject private var presetManager = StandardPhrasePresetManager.shared
    @EnvironmentObject var clipboardManager: ClipboardManager
    @AppStorage("useFilteredHistoryForShortcuts") private var useFilteredHistoryForShortcuts: Bool = false
    @AppStorage("isQuickOverlayEnabled") private var isQuickOverlayEnabled: Bool = false
    
    @AppStorage("historyQuickOverlayModifiers") private var historyQuickOverlayModifiers: Int = 0
    @AppStorage("standardPhraseQuickOverlayModifiers") private var standardPhraseQuickOverlayModifiers: Int = 0
    
    var body: some View {
        Form {
            Section(header: Text("クイックオーバーレイ").font(.headline)) {
                HStack {
                    Text("定型文オーバーレイ")
                        .foregroundColor(isQuickOverlayEnabled ? .primary : .secondary)
                    Spacer()
                    ModifierKeyPickerView(modifiers: $standardPhraseQuickOverlayModifiers)
                }
                HStack {
                    Text("履歴オーバーレイ")
                        .foregroundColor(isQuickOverlayEnabled ? .primary : .secondary)
                    Spacer()
                    ModifierKeyPickerView(modifiers: $historyQuickOverlayModifiers)
                }
            }
            .disabled(!isQuickOverlayEnabled)
            
            Section(header: Text("ウィンドウ操作").font(.headline)) {
                HStack {
                    Text("定型文ウィンドウを開く")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .showAllStandardPhrases)
                    Button(action: {
                        KeyboardShortcuts.reset(.showAllStandardPhrases)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
                
                HStack {
                    Text("履歴ウィンドウを開く")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .showAllCopyHistory)
                    Button(action: {
                        KeyboardShortcuts.reset(.showAllCopyHistory)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
            }
            
            Section(header: Text("プライバシー").font(.headline)) {
                HStack {
                    Text("クリップボード監視を切り替える")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleClipboardMonitoring)
                    Button(action: {
                        KeyboardShortcuts.reset(.toggleClipboardMonitoring)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
            }
            
            Section(header: Text("プリセット").font(.headline)) {
                HStack {
                    Text("新しいプリセットを追加する")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .addNewPreset)
                    Button(action: {
                        KeyboardShortcuts.reset(.addNewPreset)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
                HStack {
                    Text("次のプリセットに切り替える")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .nextPreset)
                    Button(action: {
                        KeyboardShortcuts.reset(.nextPreset)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
                HStack {
                    Text("前のプリセットに切り替える")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .previousPreset)
                    Button(action: {
                        KeyboardShortcuts.reset(.previousPreset)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
            }
            
            Section(header: Text("定型文").font(.headline)) {
                ForEach(0..<10, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading) {
                            // OrdinalSuffix を使用して英語表記の順序数にする
                            Text("\(index + 1)\((index + 1).ordinalSuffixForStandardPhrase)定型文をコピーする")
                            
                            let currentPhrases = presetManager.selectedPreset?.phrases ?? []
                            let phraseExists = currentPhrases.indices.contains(index)
                            
                            if phraseExists {
                                Text("「\(currentPhrases[index].title)」")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("定型文が設定されていません")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        let shortcutName: KeyboardShortcuts.Name = {
                            switch index {
                            case 0: return .copyStandardPhrase1
                            case 1: return .copyStandardPhrase2
                            case 2: return .copyStandardPhrase3
                            case 3: return .copyStandardPhrase4
                            case 4: return .copyStandardPhrase5
                            case 5: return .copyStandardPhrase6
                            case 6: return .copyStandardPhrase7
                            case 7: return .copyStandardPhrase8
                            case 8: return .copyStandardPhrase9
                            case 9: return .copyStandardPhrase10
                            default: fatalError("Unexpected index for standard phrase shortcut")
                            }
                        }()
                        
                        KeyboardShortcuts.Recorder(for: shortcutName)
                        Button(action: {
                            KeyboardShortcuts.reset(shortcutName)
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .imageScale(.small)
                        }
                        .buttonStyle(.borderless)
                        .help("デフォルトのショートカットに戻します。")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                HStack {
                    Text("新しい定型文を追加する")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .addSNewtandardPhrase)
                    Button(action: {
                        KeyboardShortcuts.reset(.addSNewtandardPhrase)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("クリップボードの内容から定型文を追加する")
                        Text("現在のクリップボード内容を使って新しい定型文を追加します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .addStandardPhraseFromClipboard)
                    Button(action: {
                        KeyboardShortcuts.reset(.addStandardPhraseFromClipboard)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
            }
            
            Section(header: Text("コピー履歴").font(.headline)) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Text("履歴ウィンドウでフィルタリングされたコピー履歴を使用")
                        Text("履歴ウィンドウが開いていてフィルタリングが適用されている場合、ショートカットキーでフィルタリングされた履歴をコピーできるようにします。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $useFilteredHistoryForShortcuts)
                        .labelsHidden()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("ピン留めされた項目をコピーする")
                        if let pinnedItem = clipboardManager.pinnedItem {
                            Text("「\(pinnedItem.text.replacingOccurrences(of: "\n", with: " "))」")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("ピン留めされた項目はありません")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .copyPinnedHistoryItem)
                    Button(action: {
                        KeyboardShortcuts.reset(.copyPinnedHistoryItem)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
                
                ForEach(0..<10, id: \.self) { index in
                    HStack {
                        Text("\(index + 1)\((index + 1).ordinalSuffixForHistory)履歴をコピーする")
                        Spacer()
                        
                        let shortcutName: KeyboardShortcuts.Name = {
                            switch index {
                            case 0: return .copyClipboardHistory1
                            case 1: return .copyClipboardHistory2
                            case 2: return .copyClipboardHistory3
                            case 3: return .copyClipboardHistory4
                            case 4: return .copyClipboardHistory5
                            case 5: return .copyClipboardHistory6
                            case 6: return .copyClipboardHistory7
                            case 7: return .copyClipboardHistory8
                            case 8: return .copyClipboardHistory9
                            case 9: return .copyClipboardHistory10
                            default: fatalError("Unexpected index for clipboard history shortcut")
                            }
                        }()
                        
                        KeyboardShortcuts.Recorder(for: shortcutName)
                        Button(action: {
                            KeyboardShortcuts.reset(shortcutName)
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .imageScale(.small)
                        }
                        .buttonStyle(.borderless)
                        .help("デフォルトのショートカットに戻します。")
                    }
                }
                HStack {
                    Text("新規コピー画面を開く")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .newCopy)
                    Button(action: {
                        KeyboardShortcuts.reset(.newCopy)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
                HStack {
                    Text("最新の履歴を変更してコピーする")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .editAndCopyLatestHistory)
                    Button(action: {
                        KeyboardShortcuts.reset(.editAndCopyLatestHistory)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help("デフォルトのショートカットに戻します。")
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    ShortcutsSettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}
