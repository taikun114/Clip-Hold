import SwiftUI

// カラーコードを表示するためのカスタムアイコンビュー
struct ColorCodeIconView: View {
    let color: Color
    
    var body: some View {
        // 30x30のフレームを確保し、その中央に25x25のアイコンを配置
        ZStack {
            ZStack {
                Circle().fill(color)
                Circle().stroke(Color.secondary, lineWidth: 0.5)
            }
            .frame(width: 25, height: 25)
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .frame(width: 30, height: 30)
    }
}