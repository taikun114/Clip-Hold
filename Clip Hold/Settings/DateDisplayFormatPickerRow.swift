import SwiftUI

/// 設定画面で共通して使用する「日付と時刻の表示方法」選択行コンポーネント
struct DateDisplayFormatPickerRow: View {
    @Binding var selection: String
    @EnvironmentObject var dateReloader: DateReloader

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("日付と時刻の表示方法")
                
                let exampleText = Date.sampleFormatted(for: selection, currentDate: dateReloader.now)
                Text("コピーされた日付の表示方法を変更します。\n例: \(exampleText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("日付と時刻の表示方法", selection: $selection) {
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
    }
}
