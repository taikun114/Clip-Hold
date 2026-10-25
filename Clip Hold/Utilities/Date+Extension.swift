import Foundation

extension Date {
    func formatted(for format: String, currentDate: Date) -> String {
        switch format {
        case "absolute":
            return formattedAsAbsolute()
        case "relative":
            return formattedAsRelative(currentDate: currentDate)
        case "both_abs_rel_paren":
            return "\(formattedAsAbsolute()) (\(formattedAsRelative(currentDate: currentDate)))"
        case "both_abs_rel_hyphen":
            return "\(formattedAsAbsolute()) - \(formattedAsRelative(currentDate: currentDate))"
        case "both_rel_abs_paren":
            return "\(formattedAsRelative(currentDate: currentDate)) (\(formattedAsAbsolute()))"
        case "both_rel_abs_hyphen":
            return "\(formattedAsRelative(currentDate: currentDate)) - \(formattedAsAbsolute())"
        default:
            return formattedAsAbsolute()
        }
    }
    
    /// 設定画面などで使用するサンプルテキスト（5分前）のフォーマット結果を返す
    static func sampleFormatted(for format: String, currentDate: Date) -> String {
        let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: currentDate) ?? currentDate
        return fiveMinutesAgo.formatted(for: format, currentDate: currentDate)
    }
    
    func formattedAsAbsolute() -> String {
        CachedDateFormatters.shared.absoluteString(from: self)
    }
    
    func formattedAsRelative(currentDate: Date) -> String {
        let timeInterval = currentDate.timeIntervalSince(self)
        if abs(timeInterval) < 30 {
            return String(localized: "たった今")
        }
        return CachedDateFormatters.shared.relativeString(from: self, currentDate: currentDate)
    }
}

/// フォーマッターを再利用し、設定変更時に更新する。並行呼び出しはロックで保護する。
private final class CachedDateFormatters: @unchecked Sendable {
    static let shared = CachedDateFormatters()
    private let lock = NSLock()
    private var absoluteFormatter: DateFormatter?
    private var relativeFormatter: RelativeDateTimeFormatter?
    private var observers: [NSObjectProtocol] = []

    private init() {
        for name in [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.invalidate()
            })
        }
    }

    private func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        absoluteFormatter = nil
        relativeFormatter = nil
    }

    func absoluteString(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter: DateFormatter
        if let cached = absoluteFormatter {
            formatter = cached
        } else {
            formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            absoluteFormatter = formatter
        }
        return formatter.string(from: date)
    }

    func relativeString(from date: Date, currentDate: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter: RelativeDateTimeFormatter
        if let cached = relativeFormatter {
            formatter = cached
        } else {
            formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            relativeFormatter = formatter
        }
        return formatter.localizedString(for: date, relativeTo: currentDate)
    }
}
