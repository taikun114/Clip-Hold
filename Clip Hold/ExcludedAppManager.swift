import Foundation
import SwiftUI // @Published

extension ClipboardManager {
    // MARK: - Excluded App Management
    func updateExcludedAppIdentifiers(_ identifiers: [String]) {
        // 現在のリストと新しいリストが同じでなければ更新する
        if self.excludedAppIdentifiers != identifiers {
            // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
            self.objectWillChange.send()
            self.excludedAppIdentifiers = identifiers
            print("ClipboardManager: Excluded app identifiers updated. Count: \(identifiers.count)")
        }
    }
}