import SwiftUI
import AppKit
import Combine

class ModifierKeyMonitor: ObservableObject {
    static let shared = ModifierKeyMonitor()
    @Published var isOptionKeyPressed: Bool = false
    private var localMonitor: Any?
    
    /// アクション実行時など、その瞬間の確実なOptionキーの状態を取得する
    var currentOptionKeyPressed: Bool {
        NSEvent.modifierFlags.contains(.option)
    }
    
    private init() {
        // Initial state check
        isOptionKeyPressed = NSEvent.modifierFlags.contains(.option)
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.isOptionKeyPressed = event.modifierFlags.contains(.option)
            return event
        }
    }
    
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
