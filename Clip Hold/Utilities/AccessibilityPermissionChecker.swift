import Foundation
import Accessibility
import AppKit

class AccessibilityPermissionChecker: ObservableObject {
    static let shared = AccessibilityPermissionChecker()

    @Published var hasAccessibilityPermission: Bool = false

    private init() {
        checkPermission()
    }

    func checkPermission() {
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
