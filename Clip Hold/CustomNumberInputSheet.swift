import SwiftUI

struct CustomNumberInputSheet: View {
    let title: Text
    let description: Text?
    @Binding var currentValue: Int
    @Binding var selectedUnit: DataSizeUnit? // オプション型に変更

    var onSave: (Int) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var inputText: String = ""
    @State private var showAlert = false

    init(title: Text, description: Text?, currentValue: Binding<Int>, selectedUnit: Binding<DataSizeUnit?> = .constant(nil), onSave: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.description = description
        self._currentValue = currentValue
        self._selectedUnit = selectedUnit
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 20) {
            title
                .font(.headline)

            HStack {
                TextField("数値を入力", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit {
                        performSave()
                    }

                Stepper("値を調整", value: $currentValue, in: 1...Int.max)
                    .labelsHidden()

                // MARK: - 単位選択ピッカーの追加
                if selectedUnit != nil {
                    Picker("", selection: Binding<DataSizeUnit>( // 修正箇所: ラベルを空文字列に変更
                        get: { selectedUnit ?? .megabytes },
                        set: { selectedUnit = $0 }
                    )) {
                        ForEach(DataSizeUnit.allCases, id: \.self) { unit in // Use id: \.self for Identifiable
                            Text(unit.label)
                                .tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
            }
            .padding(.horizontal)
            .onChange(of: inputText) { oldValue, newValue in
                let halfWidthConverted = convertFullWidthToHalfWidthNumbers(newValue)
                let filtered = halfWidthConverted.filter { $0.isNumber }

                if filtered != newValue {
                    inputText = filtered
                }

                if let newInt = Int(inputText) {
                    currentValue = newInt
                } else if inputText.isEmpty {
                    currentValue = 0
                }
            }
            .onChange(of: currentValue) { oldValue, newValue in
                // currentValue がプログラム的に変更された場合のみinputTextを更新
                // TextFieldでの直接入力と無限ループにならないように
                if Int(inputText) != newValue {
                    inputText = String(newValue)
                }
            }
            .onAppear {
                inputText = String(currentValue)
            }

            if let description = description {
                description
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("キャンセル") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("保存") {
                    performSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            }
        }
        .padding()
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300, minHeight: 150)
        .alert("入力エラー", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            // alertMessageの代わりに直接Textビューを返す
            if let newInt = Int(inputText), newInt < 1 {
                Text("1以上の数値を入力してください。")
            } else {
                Text("有効な数値を入力してください。")
            }
        }
    }

    private func performSave() {
        if let newInt = Int(inputText) {
            if newInt >= 1 {
                onSave(newInt)
                dismiss()
            } else {
                showAlert = true
            }
        } else {
            showAlert = true
        }
    }
}

func convertFullWidthToHalfWidthNumbers(_ input: String) -> String {
    var output = ""
    for char in input {
        switch char {
        case "０": output.append("0")
        case "１": output.append("1")
        case "２": output.append("2")
        case "３": output.append("3")
        case "４": output.append("4")
        case "５": output.append("5")
        case "６": output.append("6")
        case "７": output.append("7")
        case "８": output.append("8")
        case "９": output.append("9")
        default: output.append(char)
        }
    }
    return output
}
