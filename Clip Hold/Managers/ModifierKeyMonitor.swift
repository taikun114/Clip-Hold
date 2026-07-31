import SwiftUI
import AppKit
import Combine

class ModifierKeyMonitor: ObservableObject {
    static let shared = ModifierKeyMonitor()
    @Published var isOptionKeyPressed: Bool = false
    private var localMonitor: Any?
    
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
