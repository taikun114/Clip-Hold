import Cocoa
import CoreGraphics

struct ClipboardSourceAppDetector {
    
    private static let appIgnoreList: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver",
        "com.apple.WindowManager",
        "com.apple.TextInputMenuAgent",
        "com.apple.screencaptureui",
        "com.apple.PIPAgent",
        "com.apple.inputmethod.AssistiveControl"
    ]

    /// 画面上で一番手前にある有効なウィンドウを所有するアプリケーションを返します。
    /// バックグラウンドのアプリで右クリックしてコピーした場合など、アクティブなアプリが切り替わっていなくても
    /// コンテキストメニュー等のウィンドウが手前に描画される性質を利用してコピー元アプリを特定します。
    /// 取得できない場合は、フォールバックとして `NSWorkspace.shared.frontmostApplication` を返します。
    static func appOwningFrontmostWindow() -> NSRunningApplication? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return NSWorkspace.shared.frontmostApplication
        }
        
        let minimumWindowSize: CGFloat = 50.0
        
        for window in windowInfoList {
            // ウィンドウレイヤー（Zオーダーレベル）の確認
            guard let layer = window[kCGWindowLayer as String] as? Int else { continue }
            
            // コンテキストメニュー（Layer 101）などをキャッチするため、上限は設けず、下限（normal以上）のみ確認する
            guard layer >= NSWindow.Level.normal.rawValue else {
                continue
            }
            
            // 透明度の確認
            guard let alpha = window[kCGWindowAlpha as String] as? CGFloat, alpha > 0.2 else {
                continue
            }
            
            // ウィンドウサイズの確認 (例えばChromeのツールチップなど、小さすぎるものを除外)
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let width = boundsDict["Width"] as? CGFloat,
               let height = boundsDict["Height"] as? CGFloat {
                guard width >= minimumWindowSize, height >= minimumWindowSize else {
                    continue
                }
            } else {
                continue
            }
            
            // メニューバーアプリやエージェントプロセスなどを名前で除外
            if let ownerName = window[kCGWindowOwnerName as String] as? String {
                // Window Server はローカライズされないシステムプロセス名
                if ownerName.lowercased().hasSuffix("agent") || ownerName == "Window Server" {
                    continue
                }
            }
            
            // プロセスID (PID) から実行中のアプリケーションを取得
            if let pid = window[kCGWindowOwnerPID as String] as? pid_t,
               let runningApp = NSRunningApplication(processIdentifier: pid) {
                
                // 特殊な最前面ウィンドウを配置するアプリを除外する（例: Grammarly）
                if let bundleIdentifier = runningApp.bundleIdentifier {
                    // ユーザーのアイデアを採用：Clip Hold自身は完全にZオーダー判定から除外する
                    if bundleIdentifier == Bundle.main.bundleIdentifier {
                        continue
                    }
                    
                    // 除外リストにあるシステムアプリは無視する
                    if appIgnoreList.contains(bundleIdentifier) {
                        continue
                    }
                    
                    let grammarly = "com.grammarly.ProjectLlama"
                    let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    
                    if bundleIdentifier == grammarly && frontmostApp != grammarly {
                        continue
                    }
                }
                
                return runningApp
            }
        }
        
        // 有効なウィンドウが見つからなかった場合はフォールバック
        return NSWorkspace.shared.frontmostApplication
    }
}
