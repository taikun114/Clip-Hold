import SwiftUI
import AppKit

// MARK: - Shared Action Menu Items

/// クリップボードへのコピーを行うメニュー項目
struct SharedCopyMenuItem: View {
    let action: () -> Void
    @ObservedObject var modifierMonitor = ModifierKeyMonitor.shared
    @AppStorage("quickPaste") var quickPaste: Bool = false
    @AppStorage("quickPasteToPreviousApp") var quickPasteToPreviousApp: Bool = false
    
    var body: some View {
        Button(action: action) {
            if quickPaste && quickPasteToPreviousApp && modifierMonitor.isOptionKeyPressed {
                Label("クイックペーストせずにコピー", systemImage: "document.on.document").forceIconOnMacOS27()
            } else {
                Label("コピー", systemImage: "document.on.document").forceIconOnMacOS27()
            }
        }
    }
}

/// 変更してコピーを行うメニュー項目
struct SharedEditAndCopyMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("変更してコピー...")
        }
    }
}

/// URLの場合にリンクを開くメニュー項目
struct SharedOpenLinkMenuItem: View {
    let urlString: String
    
    var body: some View {
        if let url = URL(string: urlString), (url.scheme == "http" || url.scheme == "https") {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("リンクを開く", systemImage: "paperclip").forceIconOnMacOS27()
            }
        }
    }
}

/// QRコードを表示するメニュー項目
struct SharedShowQRCodeMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("QRコードを表示...", systemImage: "qrcode").forceIconOnMacOS27()
        }
    }
}

/// このアプリからの他の履歴を表示するメニュー項目
struct SharedFilterByAppMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("このアプリからの他の履歴を表示", systemImage: "line.3.horizontal.decrease")
        }
    }
}

/// 項目を削除するメニュー項目
struct SharedDeleteMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: action) {
            Label("削除...", systemImage: "trash").forceIconOnMacOS27()
        }
    }
}

/// 項目を編集するメニュー項目
struct SharedEditMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("編集...", systemImage: "pencil")
        }
    }
}

/// 項目を複製するメニュー項目
struct SharedDuplicateMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("複製", systemImage: "plus.square.on.square")
        }
    }
}

/// 項目を別の場所に移動するメニュー項目
struct SharedMoveMenuItem: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("別のプリセットに移動...", systemImage: "folder")
        }
    }
}
