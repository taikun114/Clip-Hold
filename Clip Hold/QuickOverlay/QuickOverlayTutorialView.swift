import SwiftUI

struct TutorialPage: Identifiable {
    let id = UUID()
    let image: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

struct QuickOverlayTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var movingForward = true
    
    private let pages: [TutorialPage] = [
        TutorialPage(
            image: "Clip Hold Overlay HowTo Overlays",
            title: "クイックオーバーレイを開く (1/2)",
            description: "クイックオーバーレイは、設定されたショートカットキーを押し続けている間、または画面の端にマウスカーソルで触れている間だけ表示されるオーバーレイです。ショートカットキーで表示する場合、デフォルトでは、^ (Control) + ⌘ (Command)キーで定型文オーバーレイ、⌥ (Option) + ⌘ (Command)キーで履歴オーバーレイを開くことができます。\nショートカットキーで表示されるクイックオーバーレイでは、クリックしなくても簡単に操作できるように設計されています。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Screen Edge",
            title: "クイックオーバーレイを開く (2/2)",
            description: "「スクリーンエッジ」機能を設定することで、マウスカーソルで画面の端に触れることでもクイックオーバーレイを表示することができます。\nスクリーンエッジによって表示されるクイックオーバーレイでは、項目をクリックして選択・コピーしたり、ドラッグアンドドロップして特定の場所にペーストしたりできます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Copy Content",
            title: "項目をコピーする",
            description: "履歴または定型文をコピーしたい場合、オーバーレイを開いたままコピーしたい項目にマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることでコピーすることができます。\n設定で「クイックペースト」がオンになっている場合、コピーされた後に自動でペーストされます（履歴の場合、「テキストに限定」設定も適用されます）。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Screen Edge Drag",
            title: "項目をドラッグしてペーストする",
            description: "履歴または定型文を指定の場所にペーストしたい場合、オーバーレイを開いたままコピーしたい項目をドラッグし、ペーストしたい場所でドロップすることでお好みの場所にペーストすることができます。\nドラッグアンドドロップしてコピー機能はショートカットキーでもスクリーンエッジでも利用可能です。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Copy as Plain Text",
            title: "履歴を標準テキストとしてコピーする",
            description: "履歴項目がリッチテキストの場合、項目の右側にある「標準テキストとしてコピー」ボタンにマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることで、標準テキストとしてコピーすることができます。\n設定で「クイックペースト」がオンになっている場合、コピーされた後に自動でペーストされます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Screen Edge Drag Plain Text",
            title: "履歴を標準テキストとしてドラッグしてペーストする",
            description: "履歴項目がリッチテキストの場合、項目の右側にある「標準テキストとしてコピー」ボタンをドラッグし、ペーストしたい場所でドロップすることでお好みの場所に標準テキストとしてペーストすることができます。\nドラッグアンドドロップしてコピー機能はショートカットキーでもスクリーンエッジでも利用可能です。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Change and Copy",
            title: "項目を変更してコピーする",
            description: "元となる履歴や定型文を変更してコピーしたい場合、項目の右側にある「変更してコピー...」にマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることで、「項目を変更してコピー」ウィンドウが開いて項目を変更してコピーすることができます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Open Presets Menu",
            title: "定型文プリセットを操作する (1/3)",
            description: "定型文オーバーレイでは、オーバーレイの右上に表示されているプリセット名にマウスカーソルを合わせることでプリセットメニューが自動で開き、プリセットを切り替えたり、新規プリセットを作成したりすることができます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Using Presets Menu",
            title: "定型文プリセットを操作する (2/3)",
            description: "プリセットメニューでは、マウスカーソルを動かすだけで簡単にプリセットを切り替えることができます。\nプリセットを切り替えるには、切り替えたいプリセット名にマウスカーソルを合わせ、そのままメニューの左か右にマウスカーソルを移動させることでプリセットが切り替わります（クリックでも可能です）。プリセットの切り替えをキャンセルしたい場合はメニューの上か下にマウスカーソルを移動させると、プリセットを切り替えずにメニューを閉じることができます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo New Preset",
            title: "定型文プリセットを操作する (3/3)",
            description: "新規プリセットを作成するには、プリセットメニューにある「新規プリセット...」にマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることで、「プリセットを追加」ウィンドウが開いてプリセットを作成することができます。\nこのメニュー項目では誤操作を防止するため、項目の左右にマウスカーソルを動かしてもアクションは実行されず、メニューが閉じます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo New",
            title: "定型文を追加 / 新規コピーする",
            description: "定型文オーバーレイでは、オーバーレイの左下にある「追加」にマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることで、「定型文を追加」ウィンドウが開いて定型文の追加を行うことができます。\n履歴オーバーレイでは、オーバーレイの左下にある「新規コピー」にマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることで、「テキストを入力して新規コピー」ウィンドウが開いて新たなコピーの作成を行うことができます。"
        ),
        TutorialPage(
            image: "Clip Hold Overlay HowTo Open Window",
            title: "定型文 / 履歴ウィンドウを開く",
            description: "オーバーレイの右下にある「定型文ウィンドウを開く」（定型文オーバーレイ）または「履歴ウィンドウを開く」（履歴オーバーレイ）にマウスカーソルを合わせてショートカットキーを離すか、項目をクリックすることで、定型文ウィンドウまたは履歴ウィンドウを開くことができます。"
        )
    ]
    
    var body: some View {
        Group {
            if #available(macOS 26, *) {
                mainContent
                    .safeAreaBar(edge: .bottom) {
                        footerView
                    }
            } else {
                VStack(spacing: 0) {
                    mainContent
                    Spacer(minLength: 0)
                    footerView
                }
            }
        }
        .frame(width: 500, height: 550)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 16) {
            // 画像エリア (左右上端にぴったり配置、角丸なし)
            ZStack {
                ForEach(0..<pages.count, id: \.self) { index in
                    if index == currentPage {
                        Image(pages[index].image)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .animation(.easeInOut, value: currentPage)
            
            // ドットインジケーター
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            
            // テキストエリア (スライドアニメーション、スクロール可能)
            ScrollView {
                ZStack(alignment: .top) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if index == currentPage {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(pages[index].title)
                                    .font(.headline)
                                    .bold()
                                
                                Text(pages[index].description)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.asymmetric(
                                insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                }
                .animation(.easeInOut, value: currentPage)
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Button("閉じる") {
                dismiss()
            }
            .controlSize(.large)
            
            Spacer()
            
            Button("戻る") {
                movingForward = false
                withAnimation {
                    currentPage -= 1
                }
            }
            .controlSize(.large)
            .disabled(currentPage == 0)
            
            if currentPage < pages.count - 1 {
                Button("次へ") {
                    movingForward = true
                    withAnimation {
                        currentPage += 1
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            } else {
                Button("完了") {
                    dismiss()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    QuickOverlayTutorialView()
}
