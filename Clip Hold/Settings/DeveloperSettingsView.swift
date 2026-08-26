import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = false
    @AppStorage("showInvisibleCharacters") var showInvisibleCharacters: Bool = false
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    @AppStorage("enableColorCodeFilter") var enableColorCodeFilter: Bool = false
    
    @State private var showingResetConfirmation = false
    @State private var showingResetComplete = false
    @State private var showingSpotlightResetConfirmation = false
    @State private var showingCodeDetectorResetConfirmation = false
    
    @ObservedObject var spotlightManager = SpotlightManager.shared
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        Form {
            // MARK: - テキスト
            Section(header: Text("テキスト").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("文字数カウントを表示")
                        Text("履歴ウィンドウとメニューの日付の後に、文字数カウントを表示します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $showCharacterCount) {
                        Text("文字数カウントを表示")
                        Text("履歴ウィンドウとメニューの日付の後に、文字数カウントを表示します。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("空白・改行記号を表示")
                        Text("半角スペース、全角スペース、改行、タブを記号で表示します。テキスト置換の履歴では、この設定に関わらず常に表示されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $showInvisibleCharacters) {
                        Text("空白・改行記号を表示")
                        Text("半角スペース、全角スペース、改行、タブを記号で表示します。テキスト置換の履歴では、この設定に関わらず常に表示されます。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: テキスト
            
            // MARK: - カラーコード
            Section(header: Text("カラーコード").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("カラーコードに基づくカラーアイコンを表示")
                        Text("HEX、HSL / HSLA、RGB / RGBA形式のカラーコードをコピーすると、履歴・定型文ウィンドウとメニューにその色のアイコンが表示されるようになります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $showColorCodeIcon) {
                        Text("カラーコードに基づくカラーアイコンを表示")
                        Text("HEX、HSL / HSLA、RGB / RGBA形式のカラーコードをコピーすると、履歴・定型文ウィンドウとメニューにその色のアイコンが表示されるようになります。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                HStack {
                    VStack(alignment: .leading) {
                        Text("カラーコードでフィルタリングできるようにする")
                        Text("履歴ウィンドウのフィルタリングオプションに「カラーコードのみ」を追加します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(isOn: $enableColorCodeFilter) {
                        Text("カラーコードでフィルタリングできるようにする")
                        Text("履歴ウィンドウのフィルタリングオプションに「カラーコードのみ」を追加します。")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: カラーコード
            
            // MARK: - Spotlight
            Section(header: Text("Spotlight").font(.headline)) {
                // Spotlight Index Status
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Spotlightインデックス状況")
                        Spacer()
                        Text(spotlightManager.isIndexing ? "インデックス中..." : "インデックス済み")
                            .foregroundStyle(.secondary)
                    }
                    
                    if spotlightManager.isIndexing {
                        let total = Double(max(1, spotlightManager.totalCount))
                        let progress = Double(max(0, min(spotlightManager.indexedCount, spotlightManager.totalCount)))
                        let fraction = progress / total
                        
                        ProgressView(
                            value: spotlightManager.indexedCount > 0 ? progress : nil,
                            total: total
                        ) {
                            EmptyView()
                        } currentValueLabel: {
                            if spotlightManager.totalCount > 0 {
                                HStack {
                                    if spotlightManager.indexedCount > 0 {
                                        Text(fraction, format: .percent.precision(.fractionLength(0)))
                                        Spacer()
                                        Text("\(spotlightManager.indexedCount) / \(spotlightManager.totalCount)個")
                                    } else {
                                        Text("インデックス準備中...")
                                        Spacer()
                                        Text("\(spotlightManager.totalCount)個")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .progressViewStyle(.linear)
                        .id(spotlightManager.resetID)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Spotlightインデックスをリセット")
                        Text("Clip Holdによってインデックスされたすべての履歴と定型文をリセットして再インデックスを行います。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("リセット...") {
                        showingSpotlightResetConfirmation = true
                    }
                    .disabled(spotlightManager.isIndexing)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: Spotlight
            
            // MARK: - コード検出
            Section(header: Text("コード検出").font(.headline)) {
                // Code Detection Index Status
                VStack(alignment: .leading, spacing: 4) {
                    let total = Double(max(1, clipboardManager.codeDetectionTotalCount))
                    let progress = Double(max(0, min(clipboardManager.codeDetectionIndexedCount, clipboardManager.codeDetectionTotalCount)))
                    let fraction = progress / total
                    
                    HStack {
                        Text("コード検出インデックス状況")
                        Spacer()
                        if clipboardManager.isIndexingCodeDetection {
                            if clipboardManager.codeDetectionIndexedCount > 0 {
                                Text(fraction < 0.5 ? "計算中..." : "インデックス中...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("計算中...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("インデックス済み")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if clipboardManager.isIndexingCodeDetection {
                        let halfTotal = max(1, clipboardManager.codeDetectionTotalCount / 2)
                        let currentCount = min(halfTotal, fraction < 0.5 ? clipboardManager.codeDetectionIndexedCount : (clipboardManager.codeDetectionIndexedCount - halfTotal))
                        
                        ProgressView(
                            value: progress,
                            total: total
                        ) {
                            EmptyView()
                        } currentValueLabel: {
                            if clipboardManager.codeDetectionTotalCount > 0 {
                                HStack {
                                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                                    Spacer()
                                    Text("\(currentCount) / \(halfTotal)個")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .progressViewStyle(.linear)
                        .id(clipboardManager.codeDetectionResetID)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("コード検出インデックスをリセット")
                        Text("すべての履歴と定型文のコード検出インデックスをリセットして、再判定します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("リセット...") {
                        showingCodeDetectorResetConfirmation = true
                    }
                    .disabled(clipboardManager.isIndexingCodeDetection)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: コード検出
            
            // MARK: - デバッグ
            Section(header: Text("デバッグ").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("すべての設定をリセット")
                        Text("アプリのすべての設定を初期状態に戻します。コピー履歴と定型文は影響を受けません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("リセット...") {
                        showingResetConfirmation = true
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } // End of Section: デバッグ
            
#if DEBUG
            // MARK: - Debug Menu (開発者テスト用)
            Section(header: Text(verbatim: "Debug Menu").font(.headline)) {
                HStack {
                    Text(verbatim: "Test isExporting")
                    Spacer()
                    Toggle(isOn: $clipboardManager.isExporting) {
                        Text(verbatim: "Test isExporting")
                    }
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
#endif
        } // End of Form
        .formStyle(.grouped)
        .alert("すべての設定をリセット", isPresented: $showingResetConfirmation) {
            Button("リセット", role: .destructive) {
                resetUserDefaults()
                showingResetComplete = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("アプリの全ての設定を初期状態に戻してもよろしいですか？この操作は元に戻せません。")
        }
        .alert("リセット完了", isPresented: $showingResetComplete) {
            Button("完了") {}
        } message: {
            Text("すべての設定が初期状態に戻りました。変更を完全に適用するにはアプリを再起動してください。")
        }
        .alert("インデックスをリセット", isPresented: $showingSpotlightResetConfirmation) {
            Button("リセット", role: .destructive) {
                SpotlightManager.shared.resetAndReindexAll()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("履歴や定型文の数によっては、再インデックスが完全に終わるまでに時間がかかる事があります。よろしいですか？")
        }
        .alert("コード検出インデックスをリセット", isPresented: $showingCodeDetectorResetConfirmation) {
            Button("リセット", role: .destructive) {
                Task {
                    await clipboardManager.resetCodeDetectionIndex()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("履歴や定型文の数によっては、再判定が完全に終わるまでに時間がかかることがあります。よろしいですか？")
        }
    }
    
    private func resetUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
#if DEBUG
            print("User defaults reset for bundle ID: \(bundleID)")
#endif
        }
    }
}

#Preview {
    DeveloperSettingsView()
        .environmentObject(ClipboardManager.shared)
}
