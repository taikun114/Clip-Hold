import Foundation
import SwiftUI

struct StandardPhraseDuplicate: Identifiable {
    let id = UUID()
    let existingPhrase: StandardPhrase // 既存のフレーズ
    var newPhrase: StandardPhrase     // インポートしようとしている新しいフレーズ
    
    // UIの状態を追跡するためのプロパティ
    var useCustomTitle: Bool = false // カスタムタイトルを使用するかどうかのフラグ

    // タイトルが既存のフレーズと重複しているか
    var hasTitleConflict: Bool {
        return newPhrase.title == existingPhrase.title
    }
    
    // 内容が既存のフレーズと重複しているか
    var hasContentConflict: Bool {
        return newPhrase.content == existingPhrase.content
    }
    
    // カスタムタイトルを使用するかどうかの初期値を設定
    mutating func setInitialUseCustomTitle() {
        useCustomTitle = newPhrase.title != newPhrase.content
    }
}
