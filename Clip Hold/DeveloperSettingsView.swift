import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = false
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    @AppStorage("enableColorCodeFilter") var enableColorCodeFilter: Bool = false

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
        } // End of Form
        .formStyle(.grouped)
    }
}

#Preview {
    DeveloperSettingsView()
}