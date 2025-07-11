//
//  HistoryCopyConfirmation.swift
//  Clip Hold
//
//  Created by 今浦大雅 on 2025/07/11.
//


import SwiftUI

struct HistoryCopyConfirmation: View {
    @Binding var showCopyConfirmation: Bool

    var body: some View {
        VStack {
            Spacer() // 下部に寄せる
            if showCopyConfirmation {
                ZStack { // グラデーションとテキストを重ねるZStack
                    LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)]), startPoint: .top, endPoint: .bottom)
                        .frame(height: 60)
                        .frame(maxWidth: .infinity) // 横幅を最大に
                    
                    Text("コピーしました！")
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 0)
                        .padding(.top, 15)
                }
                .frame(maxWidth: .infinity) // ZStack自体も横幅を最大に
                .offset(y: 1) // 下にぴったりとくっつくように微調整
                .transition(.opacity) // フェードイン/アウト
            }
        }
        .animation(.easeOut(duration: 0.1), value: showCopyConfirmation)
        .allowsHitTesting(false) // クリックイベントを透過させる
    }
}
