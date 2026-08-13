import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = false
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    @AppStorage("enableColorCodeFilter") var enableColorCodeFilter: Bool = false
    
    @State private var showingResetConfirmation = false
    @State private var showingResetComplete = false
    @State private var showingSpotlightResetConfirmation = false
    
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
            
            // MARK: - デバッグ
            Section(header: Text("デバッグ").font(.headline)) {
                
                // Spotlight Index Status
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Spotlightインデックス状況")
                        Spacer()
                        Text(spotlightManager.isIndexing ? "インデックス中..." : "インデックス済み")
                            .foregroundStyle(.secondary)
                    }
                    
                    if spotlightManager.isIndexing {
                        ProgressView(
                            value: spotlightManager.totalCount > 0 ? Double(spotlightManager.indexedCount) : nil,
                            total: Double(max(1, spotlightManager.totalCount))
                        ) {
                            EmptyView()
                        } currentValueLabel: {
                            if spotlightManager.totalCount > 0 {
                                HStack {
                                    let fraction = Double(spotlightManager.indexedCount) / Double(max(1, spotlightManager.totalCount))
                                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                                    Spacer()
                                    Text("\(spotlightManager.indexedCount) / \(spotlightManager.totalCount)個")
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
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
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
    }
    
    private func resetUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            print("User defaults reset for bundle ID: \(bundleID)")
        }
    }
}

#Preview {
    DeveloperSettingsView()
        .environmentObject(ClipboardManager.shared)
}
