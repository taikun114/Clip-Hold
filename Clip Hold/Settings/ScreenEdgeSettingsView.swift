import SwiftUI

struct ScreenEdgeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("screenEdgeDelay") private var screenEdgeDelay: Double = 0.5
    
    // 上辺
    @AppStorage(ScreenEdgePosition.topLeft.rawValue) private var topLeft: String = "none"
    @AppStorage(ScreenEdgePosition.topCenter.rawValue) private var topCenter: String = "none"
    @AppStorage(ScreenEdgePosition.topRight.rawValue) private var topRight: String = "none"
    
    // 下辺
    @AppStorage(ScreenEdgePosition.bottomLeft.rawValue) private var bottomLeft: String = "none"
    @AppStorage(ScreenEdgePosition.bottomCenter.rawValue) private var bottomCenter: String = "none"
    @AppStorage(ScreenEdgePosition.bottomRight.rawValue) private var bottomRight: String = "none"
    
    // 左辺
    @AppStorage(ScreenEdgePosition.leftTop.rawValue) private var leftTop: String = "none"
    @AppStorage(ScreenEdgePosition.leftCenter.rawValue) private var leftCenter: String = "none"
    @AppStorage(ScreenEdgePosition.leftBottom.rawValue) private var leftBottom: String = "none"
    
    // 右辺
    @AppStorage(ScreenEdgePosition.rightTop.rawValue) private var rightTop: String = "none"
    @AppStorage(ScreenEdgePosition.rightCenter.rawValue) private var rightCenter: String = "none"
    @AppStorage(ScreenEdgePosition.rightBottom.rawValue) private var rightBottom: String = "none"
    
    private var cardCornerRadius: CGFloat {
        if #available(macOS 26.0, *) {
            return 10
        } else {
            return 6
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                // セクションヘッダー
                Text("スクリーンエッジ")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.top)
                
                // グループドカードの完全再現
                VStack(spacing: 0) {
                    // ビジュアライザー
                    ScreenEdgeVisualizerView(
                        topLeft: $topLeft,
                        topCenter: $topCenter,
                        topRight: $topRight,
                        bottomLeft: $bottomLeft,
                        bottomCenter: $bottomCenter,
                        bottomRight: $bottomRight,
                        leftTop: $leftTop,
                        leftCenter: $leftCenter,
                        leftBottom: $leftBottom,
                        rightTop: $rightTop,
                        rightCenter: $rightCenter,
                        rightBottom: $rightBottom
                    )
                    .padding(10)
                    
                    Divider()
                        .padding(.horizontal, 10)
                    
                    // スライダー行
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("表示までの時間")
                            Text("クイックオーバーレイが表示されるまでマウスカーソルを画面の端に触れ続ける時間を指定します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Slider(value: $screenEdgeDelay, in: 0.0...2.0, step: 0.1) {
                            Text("表示までの時間")
                            Text("クイックオーバーレイが表示されるまでマウスカーソルを画面の端に触れ続ける時間を指定します。")
                        }
                        .frame(width: 140)
                        .labelsHidden()
                        
                        Text("\(screenEdgeDelay, specifier: "%.1f")秒")
                            .frame(width: 40, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .quaternarySystemFill))
                )
                .overlay {
                    if #available(macOS 26.0, *) {
                        EmptyView()
                    } else {
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(.tertiary, lineWidth: 0.5)
                    }
                }
                
                // セクションフッター（説明文）
                Text("マウスカーソルで画面の端に触れることでクイックオーバーレイを表示することができます。\nスクリーンエッジによって表示されるクイックオーバーレイでは、項目をクリックして選択・コピーしたり、ドラッグアンドドロップして特定の場所にペーストしたりできます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }
            .padding(.horizontal, 20)

            // フッター
            HStack {
                Spacer()
                Button("完了") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 460)
    }
}

/// ディスプレイと周囲の12個のピッカーを描画・連携するビジュアライザービュー
private struct ScreenEdgeVisualizerView: View {
    @Binding var topLeft: String
    @Binding var topCenter: String
    @Binding var topRight: String
    
    @Binding var bottomLeft: String
    @Binding var bottomCenter: String
    @Binding var bottomRight: String
    
    @Binding var leftTop: String
    @Binding var leftCenter: String
    @Binding var leftBottom: String
    
    @Binding var rightTop: String
    @Binding var rightCenter: String
    @Binding var rightBottom: String
    
    // ディスプレイのサイズ（16:10）
    private let displayWidth: CGFloat = 160
    private let displayHeight: CGFloat = 100
    
    var body: some View {
        ZStack {
            // 背景の引き出し線描画
            GuideLinesCanvas(
                displayWidth: displayWidth,
                displayHeight: displayHeight
            )
            
            VStack(spacing: 24) {
                // 上側ピッカー（3つ）
                HStack(spacing: 14) {
                    edgePicker(selection: $topLeft, title: "画面上辺左")
                    edgePicker(selection: $topCenter, title: "画面上辺中央")
                    edgePicker(selection: $topRight, title: "画面上辺右")
                }
                
                // 中央エリア（左ピッカー3つ + ディスプレイ + 右ピッカー3つ）
                HStack(spacing: 32) {
                    // 左側ピッカー（3つ）
                    VStack(spacing: 12) {
                        edgePicker(selection: $leftTop, title: "画面左辺上")
                        edgePicker(selection: $leftCenter, title: "画面左辺中央")
                        edgePicker(selection: $leftBottom, title: "画面左辺下")
                    }
                    
                    // ディスプレイ表現
                    displayScreenView
                        .frame(width: displayWidth, height: displayHeight)
                    
                    // 右側ピッカー（3つ）
                    VStack(spacing: 12) {
                        edgePicker(selection: $rightTop, title: "画面右辺上")
                        edgePicker(selection: $rightCenter, title: "画面右辺中央")
                        edgePicker(selection: $rightBottom, title: "画面右辺下")
                    }
                }
                
                // 下側ピッカー（3つ）
                HStack(spacing: 14) {
                    edgePicker(selection: $bottomLeft, title: "画面下辺左")
                    edgePicker(selection: $bottomCenter, title: "画面下辺中央")
                    edgePicker(selection: $bottomRight, title: "画面下辺右")
                }
            }
        }
    }
    
    /// 中央のディスプレイビュー
    private var displayScreenView: some View {
        ZStack {
            // ディスプレイ本体（グラデーション: #7794D0 〜 #39599B）
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0x77 / 255.0, green: 0x94 / 255.0, blue: 0xD0 / 255.0),
                            Color(red: 0x39 / 255.0, green: 0x59 / 255.0, blue: 0x9B / 255.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            // ディスプレイ内側のエッジガイド線（四隅を空けた実線セグメント）
            DisplayInnerEdgeSegments(
                width: displayWidth,
                height: displayHeight,
                cornerMargin: 12,
                topTargets: [topLeft, topCenter, topRight],
                bottomTargets: [bottomLeft, bottomCenter, bottomRight],
                leftTargets: [leftTop, leftCenter, leftBottom],
                rightTargets: [rightTop, rightCenter, rightBottom]
            )
        }
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    /// 各エッジ用のコンパクトピッカー（SwiftUI標準のPicker）
    private func edgePicker(selection: Binding<String>, title: String) -> some View {
        Picker(title, selection: selection) {
            ForEach(ScreenEdgeTarget.allCases) { target in
                Text(target.displayName).tag(target.rawValue)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .labelsHidden()
        .flexiblePickerSizing()
        .frame(width: 88)
        .accessibilityLabel(Text(title))
    }
}

/// ディスプレイ内側の縁に表示する実線セグメント線（四隅は重ならないように空ける）
private struct DisplayInnerEdgeSegments: View {
    let width: CGFloat
    let height: CGFloat
    let cornerMargin: CGFloat
    let topTargets: [String]
    let bottomTargets: [String]
    let leftTargets: [String]
    let rightTargets: [String]
    
    private func segmentColor(for target: String) -> Color {
        if target == ScreenEdgeTarget.none.rawValue {
            return Color.white.opacity(0.35)
        } else {
            return Color.white.opacity(0.8)
        }
    }
    
    var body: some View {
        Canvas { context, size in
            let strokeStyle = StrokeStyle(lineWidth: 2.0, lineCap: .round)
            let inset: CGFloat = 6.0
            
            // 上辺（3分割）
            let topStartX = cornerMargin
            let topEndX = size.width - cornerMargin
            let topSegWidth = (topEndX - topStartX) / 3.0
            
            for i in 0..<3 {
                var path = Path()
                let segStart = topStartX + CGFloat(i) * topSegWidth + 3
                let segEnd = topStartX + CGFloat(i + 1) * topSegWidth - 3
                path.move(to: CGPoint(x: segStart, y: inset))
                path.addLine(to: CGPoint(x: segEnd, y: inset))
                let segColor = i < topTargets.count ? segmentColor(for: topTargets[i]) : segmentColor(for: "none")
                context.stroke(path, with: .color(segColor), style: strokeStyle)
            }
            
            // 下辺（3分割）
            let botStartX = cornerMargin
            let botEndX = size.width - cornerMargin
            let botSegWidth = (botEndX - botStartX) / 3.0
            let botY = size.height - inset
            
            for i in 0..<3 {
                var path = Path()
                let segStart = botStartX + CGFloat(i) * botSegWidth + 3
                let segEnd = botStartX + CGFloat(i + 1) * botSegWidth - 3
                path.move(to: CGPoint(x: segStart, y: botY))
                path.addLine(to: CGPoint(x: segEnd, y: botY))
                let segColor = i < bottomTargets.count ? segmentColor(for: bottomTargets[i]) : segmentColor(for: "none")
                context.stroke(path, with: .color(segColor), style: strokeStyle)
            }
            
            // 左辺（3分割）
            let leftStartY = cornerMargin
            let leftEndY = size.height - cornerMargin
            let leftSegHeight = (leftEndY - leftStartY) / 3.0
            
            for i in 0..<3 {
                var path = Path()
                let segStart = leftStartY + CGFloat(i) * leftSegHeight + 3
                let segEnd = leftStartY + CGFloat(i + 1) * leftSegHeight - 3
                path.move(to: CGPoint(x: inset, y: segStart))
                path.addLine(to: CGPoint(x: inset, y: segEnd))
                let segColor = i < leftTargets.count ? segmentColor(for: leftTargets[i]) : segmentColor(for: "none")
                context.stroke(path, with: .color(segColor), style: strokeStyle)
            }
            
            // 右辺（3分割）
            let rightStartY = cornerMargin
            let rightEndY = size.height - cornerMargin
            let rightSegHeight = (rightEndY - rightStartY) / 3.0
            let rightX = size.width - inset
            
            for i in 0..<3 {
                var path = Path()
                let segStart = rightStartY + CGFloat(i) * rightSegHeight + 3
                let segEnd = rightStartY + CGFloat(i + 1) * rightSegHeight - 3
                path.move(to: CGPoint(x: rightX, y: segStart))
                path.addLine(to: CGPoint(x: rightX, y: segEnd))
                let segColor = i < rightTargets.count ? segmentColor(for: rightTargets[i]) : segmentColor(for: "none")
                context.stroke(path, with: .color(segColor), style: strokeStyle)
            }
        }
    }
}

/// ピッカーからディスプレイへのガイド線を描画するCanvas
private struct GuideLinesCanvas: View {
    let displayWidth: CGFloat
    let displayHeight: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let strokeStyle = StrokeStyle(lineWidth: 1.0, lineCap: .round)
            let color = Color.secondary.opacity(0.5)
            
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let dispHalfW = displayWidth / 2.0
            let dispHalfH = displayHeight / 2.0
            
            let dispTop = center.y - dispHalfH
            let dispBottom = center.y + dispHalfH
            let dispLeft = center.x - dispHalfW
            let dispRight = center.x + dispHalfW
            
            let gap: CGFloat = 4.0
            
            // 上側ピッカーのY座標とディスプレイ上辺の結線
            let topPickerY = dispTop - 24
            let topSegStep = displayWidth / 3.0
            let pickerStepX: CGFloat = 88 + 14 // ピッカー幅88 + spacing 14
            
            // 上-中央
            var pTopC = Path()
            pTopC.move(to: CGPoint(x: center.x, y: topPickerY + gap))
            pTopC.addLine(to: CGPoint(x: center.x, y: dispTop - gap))
            context.stroke(pTopC, with: .color(color), style: strokeStyle)
            
            // 上-左 (斜め線)
            let startTL = CGPoint(x: center.x - pickerStepX, y: topPickerY)
            let endTL = CGPoint(x: dispLeft + (topSegStep * 0.5), y: dispTop)
            let dxTL = endTL.x - startTL.x
            let dyTL = endTL.y - startTL.y
            let distTL = sqrt(dxTL * dxTL + dyTL * dyTL)
            if distTL > gap * 2 {
                let uX = dxTL / distTL
                let uY = dyTL / distTL
                var pTopL = Path()
                pTopL.move(to: CGPoint(x: startTL.x + uX * gap, y: startTL.y + uY * gap))
                pTopL.addLine(to: CGPoint(x: endTL.x - uX * gap, y: endTL.y - uY * gap))
                context.stroke(pTopL, with: .color(color), style: strokeStyle)
            }
            
            // 上-右 (斜め線)
            let startTR = CGPoint(x: center.x + pickerStepX, y: topPickerY)
            let endTR = CGPoint(x: dispRight - (topSegStep * 0.5), y: dispTop)
            let dxTR = endTR.x - startTR.x
            let dyTR = endTR.y - startTR.y
            let distTR = sqrt(dxTR * dxTR + dyTR * dyTR)
            if distTR > gap * 2 {
                let uX = dxTR / distTR
                let uY = dyTR / distTR
                var pTopR = Path()
                pTopR.move(to: CGPoint(x: startTR.x + uX * gap, y: startTR.y + uY * gap))
                pTopR.addLine(to: CGPoint(x: endTR.x - uX * gap, y: endTR.y - uY * gap))
                context.stroke(pTopR, with: .color(color), style: strokeStyle)
            }
            
            // 下側ピッカーのY座標とディスプレイ下辺の結線
            let botPickerY = dispBottom + 24
            let botSegStep = displayWidth / 3.0
            
            // 下-中央
            var pBotC = Path()
            pBotC.move(to: CGPoint(x: center.x, y: botPickerY - gap))
            pBotC.addLine(to: CGPoint(x: center.x, y: dispBottom + gap))
            context.stroke(pBotC, with: .color(color), style: strokeStyle)
            
            // 下-左 (斜め線)
            let startBL = CGPoint(x: center.x - pickerStepX, y: botPickerY)
            let endBL = CGPoint(x: dispLeft + (botSegStep * 0.5), y: dispBottom)
            let dxBL = endBL.x - startBL.x
            let dyBL = endBL.y - startBL.y
            let distBL = sqrt(dxBL * dxBL + dyBL * dyBL)
            if distBL > gap * 2 {
                let uX = dxBL / distBL
                let uY = dyBL / distBL
                var pBotL = Path()
                pBotL.move(to: CGPoint(x: startBL.x + uX * gap, y: startBL.y + uY * gap))
                pBotL.addLine(to: CGPoint(x: endBL.x - uX * gap, y: endBL.y - uY * gap))
                context.stroke(pBotL, with: .color(color), style: strokeStyle)
            }
            
            // 下-右 (斜め線)
            let startBR = CGPoint(x: center.x + pickerStepX, y: botPickerY)
            let endBR = CGPoint(x: dispRight - (botSegStep * 0.5), y: dispBottom)
            let dxBR = endBR.x - startBR.x
            let dyBR = endBR.y - startBR.y
            let distBR = sqrt(dxBR * dxBR + dyBR * dyBR)
            if distBR > gap * 2 {
                let uX = dxBR / distBR
                let uY = dyBR / distBR
                var pBotR = Path()
                pBotR.move(to: CGPoint(x: startBR.x + uX * gap, y: startBR.y + uY * gap))
                pBotR.addLine(to: CGPoint(x: endBR.x - uX * gap, y: endBR.y - uY * gap))
                context.stroke(pBotR, with: .color(color), style: strokeStyle)
            }
            
            // 左右ピッカーの結線（完全水平）
            let sideSegStep = displayHeight / 3.0
            let leftPickerEdgeX = dispLeft - 32
            let rightPickerEdgeX = dispRight + 32
            
            let sideTopY = center.y - sideSegStep
            let sideMidY = center.y
            let sideBotY = center.y + sideSegStep
            
            // 左-上
            var pLeftT = Path()
            pLeftT.move(to: CGPoint(x: leftPickerEdgeX + gap, y: sideTopY))
            pLeftT.addLine(to: CGPoint(x: dispLeft - gap, y: sideTopY))
            context.stroke(pLeftT, with: .color(color), style: strokeStyle)
            
            // 左-中
            var pLeftC = Path()
            pLeftC.move(to: CGPoint(x: leftPickerEdgeX + gap, y: sideMidY))
            pLeftC.addLine(to: CGPoint(x: dispLeft - gap, y: sideMidY))
            context.stroke(pLeftC, with: .color(color), style: strokeStyle)
            
            // 左-下
            var pLeftB = Path()
            pLeftB.move(to: CGPoint(x: leftPickerEdgeX + gap, y: sideBotY))
            pLeftB.addLine(to: CGPoint(x: dispLeft - gap, y: sideBotY))
            context.stroke(pLeftB, with: .color(color), style: strokeStyle)
            
            // 右-上
            var pRightT = Path()
            pRightT.move(to: CGPoint(x: rightPickerEdgeX - gap, y: sideTopY))
            pRightT.addLine(to: CGPoint(x: dispRight + gap, y: sideTopY))
            context.stroke(pRightT, with: .color(color), style: strokeStyle)
            
            // 右-中
            var pRightC = Path()
            pRightC.move(to: CGPoint(x: rightPickerEdgeX - gap, y: sideMidY))
            pRightC.addLine(to: CGPoint(x: dispRight + gap, y: sideMidY))
            context.stroke(pRightC, with: .color(color), style: strokeStyle)
            
            // 右-下
            var pRightB = Path()
            pRightB.move(to: CGPoint(x: rightPickerEdgeX - gap, y: sideBotY))
            pRightB.addLine(to: CGPoint(x: dispRight + gap, y: sideBotY))
            context.stroke(pRightB, with: .color(color), style: strokeStyle)
        }
    }
}

#Preview {
    ScreenEdgeSettingsView()
}
