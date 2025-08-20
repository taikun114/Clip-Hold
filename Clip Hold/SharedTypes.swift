import Foundation
import SwiftUI

enum HistoryOption: Hashable, Identifiable, CaseIterable {
    case preset(Int)
    case custom(Int?)
    case unlimited

    var id: String {
        switch self {
        case .preset(let value): return "preset_\(value)"
        case .custom(let value):
            if let val = value {
                return "custom_value_\(val)"
            } else {
                return "custom_nil"
            }
        case .unlimited: return "unlimited"
        }
    }

    var stringValue: LocalizedStringKey {
        switch self {
        case .preset(let value): return LocalizedStringKey(String(value)) // 数値はString(value)で直接変換し、それをLocalizedStringKeyでラップ
        case .custom(let value):
            if let value = value {
                return LocalizedStringKey(String(value)) // 数値はString(value)で直接変換し、それをLocalizedStringKeyでラップ
            } else {
                return "カスタム..."
            }
        case .unlimited: return "無制限"
        }
    }

    var intValue: Int? {
        switch self {
        case .preset(let value): return value
        case .custom(let value): return value
        case .unlimited: return 0
        }
    }

    static let presets: [HistoryOption] = [.preset(5), .preset(10), .preset(20), .preset(50)]

    static var allCases: [HistoryOption] {
        var cases = HistoryOption.presets
        cases.append(.unlimited)
        cases.append(.custom(nil))
        return cases
    }

    static func == (lhs: HistoryOption, rhs: HistoryOption) -> Bool {
        switch (lhs, rhs) {
        case (.preset(let lv), .preset(let rv)): return lv == rv
        case (.custom(let lv), .custom(let rv)): return lv == rv
        case (.unlimited, .unlimited): return true
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .preset(let value):
            hasher.combine(0)
            hasher.combine(value)
        case .custom(let value):
            hasher.combine(1)
            hasher.combine(value)
        case .unlimited:
            hasher.combine(2)
        }
    }
}

enum MenuHistoryOption: Hashable, Identifiable, CaseIterable {
    case preset(Int)
    case custom(Int?)
    case sameAsSaved

    var id: String {
        switch self {
        case .preset(let value): return "preset_\(value)"
        case .custom(let value):
            if let actualValue = value {
                return "custom_value_\(actualValue)"
            } else {
                return "custom_nil"
            }
        case .sameAsSaved: return "same_as_saved"
        }
    }

    var stringValue: LocalizedStringKey {
        switch self {
        case .preset(let value): return LocalizedStringKey(String(value)) // 数値はString(value)で直接変換し、それをLocalizedStringKeyでラップ
        case .custom(let value):
            if let value = value {
                return LocalizedStringKey(String(value)) // 数値はString(value)で直接変換し、それをLocalizedStringKeyでラップ
            } else {
                return "カスタム..."
            }
        case .sameAsSaved: return "履歴の保存数に合わせる"
        }
    }

    var intValue: Int? {
        switch self {
        case .preset(let value): return value
        case .custom(let value): return value
        case .sameAsSaved: return nil // sameAsSavedは特定の数値を持たないためnil
        }
    }

    static let presetsAndSameAsSaved: [MenuHistoryOption] = [.preset(5), .preset(10), .preset(20), .preset(50), .sameAsSaved]

    static var allCases: [MenuHistoryOption] {
        var cases = MenuHistoryOption.presetsAndSameAsSaved
        cases.append(.custom(nil))
        return cases
    }

    static func == (lhs: MenuHistoryOption, rhs: MenuHistoryOption) -> Bool {
        switch (lhs, rhs) {
        case (.preset(let lv), .preset(let rv)): return lv == rv
        case (.custom(let lv), .custom(let rv)): return lv == rv
        case (.sameAsSaved, .sameAsSaved): return true
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .preset(let value):
            hasher.combine(0)
            hasher.combine(value)
        case .custom(let value):
            hasher.combine(1)
            hasher.combine(value)
        case .sameAsSaved:
            hasher.combine(2)
        }
    }
}

enum DataSizeUnit: String, CaseIterable, Identifiable, Hashable {
    case bytes = "B"
    case kilobytes = "KB"
    case megabytes = "MB"
    case gigabytes = "GB"

    var id: String { self.rawValue }
    var label: String { self.rawValue }

    func byteValue(for value: Int) -> Int {
        switch self {
        case .bytes: return value
        case .kilobytes: return value * 1000
        case .megabytes: return value * 1000 * 1000
        case .gigabytes: return value * 1000 * 1000 * 1000
        }
    }
}

// MARK: - DataSizeOption Enum
enum DataSizeOption: Hashable, Identifiable, CaseIterable {
    case preset(Int, DataSizeUnit) // value, unit
    case custom(Int?, DataSizeUnit?) // value, unit (nil for "カスタム..." initial state)
    case unlimited

    var id: String {
        switch self {
        case .preset(let value, let unit): return "preset_\(value)_\(unit.rawValue)"
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return "custom_value_\(val)_\(u.rawValue)"
            } else {
                return "custom_nil"
            }
        case .unlimited: return "unlimited"
        }
    }

    var stringValue: LocalizedStringKey {
        switch self {
        case .preset(let value, let unit): return LocalizedStringKey("\(value) \(unit.label)")
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return LocalizedStringKey("\(val) \(u.label)")
            } else {
                return "カスタム..."
            }
        case .unlimited: return "無制限"
        }
    }

    // This property returns the byte value for the option.
    var byteValue: Int? {
        switch self {
        case .preset(let value, let unit): return unit.byteValue(for: value)
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return u.byteValue(for: val)
            }
            return nil // For custom(nil, nil)
        case .unlimited: return 0 // Unlimited is represented as 0 bytes
        }
    }

    static let presets: [DataSizeOption] = [
        .preset(1, .megabytes),
        .preset(50, .megabytes),
        .preset(500, .megabytes),
        .preset(1, .gigabytes)
    ]

    // CaseIterableの要件を満たすために、すべてのケースを定義
    static var allCases: [DataSizeOption] {
        var cases = DataSizeOption.presets
        cases.append(.unlimited)
        cases.append(.custom(nil, nil))
        return cases
    }

    // IdentifiableとHashableの要件を満たすために、== と hash(into:) を実装
    static func == (lhs: DataSizeOption, rhs: DataSizeOption) -> Bool {
        switch (lhs, rhs) {
        case (.preset(let lv, let lu), .preset(let rv, let ru)):
            return lv == rv && lu == ru
        case (.custom(let lv, let lu), .custom(let rv, let ru)):
            return lv == rv && lu == ru
        case (.unlimited, .unlimited):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .preset(let value, let unit):
            hasher.combine(0)
            hasher.combine(value)
            hasher.combine(unit)
        case .custom(let value, let unit):
            hasher.combine(1)
            hasher.combine(value)
            hasher.combine(unit)
        case .unlimited:
            hasher.combine(2)
        }
    }
}

enum DataSizeAlertOption: Hashable, Identifiable, CaseIterable {
    case preset(Int, DataSizeUnit)
    case custom(Int?, DataSizeUnit?)
    case noAlert // アラートを表示しない

    var id: String {
        switch self {
        case .preset(let value, let unit): return "preset_\(value)_\(unit.rawValue)"
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return "custom_value_\(val)_\(u.rawValue)"
            } else {
                return "custom_nil"
            }
        case .noAlert: return "no_alert"
        }
    }

    var stringValue: LocalizedStringKey {
        switch self {
        case .preset(let value, let unit): return LocalizedStringKey("\(value) \(unit.label)")
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return LocalizedStringKey("\(val) \(u.label)")
            } else {
                return "カスタム..."
            }
        case .noAlert: return "表示しない"
        }
    }

    var byteValue: Int? {
        switch self {
        case .preset(let value, let unit): return unit.byteValue(for: value)
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return u.byteValue(for: val)
            }
            return nil
        case .noAlert: return 0 // アラートを表示しない場合は0として保存
        }
    }
    
    // Stringカタログでローカライズ可能な文字列
    var localizedString: LocalizedStringKey {
        switch self {
        case .noAlert:
            return "表示しない"
        case .custom(let value, let unit):
            if let val = value, let u = unit {
                return LocalizedStringKey("\(val) \(u.label)")
            } else {
                return "カスタム..."
            }
        case .preset(let value, let unit):
            return LocalizedStringKey("\(value) \(unit.label)")
        }
    }

    static let presets: [DataSizeAlertOption] = [
        .preset(1, .gigabytes),
        .preset(2, .gigabytes),
        .preset(5, .gigabytes),
        .preset(10, .gigabytes)
    ]
    
    static var allCases: [DataSizeAlertOption] {
        var cases = DataSizeAlertOption.presets
        cases.append(.noAlert)
        cases.append(.custom(nil, nil))
        return cases
    }
    
    static func == (lhs: DataSizeAlertOption, rhs: DataSizeAlertOption) -> Bool {
        switch (lhs, rhs) {
        case (.preset(let lv, let lu), .preset(let rv, let ru)):
            return lv == rv && lu == ru
        case (.custom(let lv, let lu), .custom(let rv, let ru)):
            return lv == rv && lu == ru
        case (.noAlert, .noAlert):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .preset(let value, let unit):
            hasher.combine(0)
            hasher.combine(value)
            hasher.combine(unit)
        case .custom(let value, let unit):
            hasher.combine(1)
            hasher.combine(value)
            hasher.combine(unit)
        case .noAlert:
            hasher.combine(2)
        }
    }
}

// MARK: - Filter and Sort Options
enum ItemFilter: String, CaseIterable, Identifiable {
    case all
    case textOnly
    case linkOnly
    case fileOnly
    case imageOnly
    case colorCodeOnly

    var id: String { self.rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .all: return "すべての項目"
        case .textOnly: return "テキストのみ"
        case .linkOnly: return "リンクのみ"
        case .fileOnly: return "ファイルのみ"
        case .imageOnly: return "画像のみ"
        case .colorCodeOnly: return "カラーコードのみ"
        }
    }
}

enum ItemSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case largestFileSize
    case smallestFileSize

    var id: String { self.rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .newest: return "新しい順"
        case .oldest: return "古い順"
        case .largestFileSize: return "ファイルサイズが大きい順"
        case .smallestFileSize: return "ファイルサイズが小さい順"
        }
    }
}

extension Hashable where Self: Identifiable {
    func isEqual(to other: Self) -> Bool {
        return self.id == other.id && self.hashValue == other.hashValue
    }
}

extension Date {
    func formatted(_ formatOption: ISO8601DateFormatter.Options) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = formatOption
        return formatter.string(from: self)
    }

    static var iso8601: ISO8601DateFormatter.Options { .withInternetDateTime }
}
