import SwiftUI
import UniformTypeIdentifiers // UTType.application を使うため

struct AppSelectionImporterView: View {
    @Binding var isPresented: Bool // Finderパネルの表示状態を親ビューから受け取る
    var onAppSelected: (String) -> Void // 選択されたアプリのバンドル識別子を親に渡すクロージャ
    var onSelectionCancelled: () -> Void // キャンセル時に親に通知するクロージャ

    var body: some View {
        // このビュー自体はUI要素を持たず、fileImporterモディファイアを適用するだけの透明なビューとして機能します。
        // あるいは、デバッグ用に一時的にボタンを配置することもできますが、通常は不要です。
        Text("")
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [UTType.application],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first,
                       let bundle = Bundle(url: url),
                       let bundleIdentifier = bundle.bundleIdentifier {
                        onAppSelected(bundleIdentifier) // 親ビューにバンドル識別子を渡す
                    } else {
                        print("Failed to get bundle identifier from selected app.")
                        onSelectionCancelled() // 失敗時も閉じる
                    }
                case .failure(let error):
                    print("Failed to select app from Finder: \(error.localizedDescription)")
                    onSelectionCancelled() // エラー時も閉じる
                }
            }
    }
}
