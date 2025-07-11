//
//  HistoryWindowBackground.swift
//  Clip Hold
//
//  Created by 今浦大雅 on 2025/07/11.
//


import SwiftUI

struct HistoryWindowBackground: View {
    var body: some View {
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .ignoresSafeArea()
        } else {
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}