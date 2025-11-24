import Foundation

extension Int {
    var ordinalSuffixForHistory: String {
        switch self {
        case 1: return String(localized: "1_suffix_history")
        case 2: return String(localized: "2_suffix_history")
        case 3: return String(localized: "3_suffix_history")
        case 4: return String(localized: "4_suffix_history")
        case 5: return String(localized: "5_suffix_history")
        case 6: return String(localized: "6_suffix_history")
        case 7: return String(localized: "7_suffix_history")
        case 8: return String(localized: "8_suffix_history")
        case 9: return String(localized: "9_suffix_history")
        case 10: return String(localized: "10_suffix_history")
        default:
            return self.description
        }
    }

    var ordinalSuffixForStandardPhrase: String {
        switch self {
        case 1: return String(localized: "1_suffix_standard_phrase")
        case 2: return String(localized: "2_suffix_standard_phrase")
        case 3: return String(localized: "3_suffix_standard_phrase")
        case 4: return String(localized: "4_suffix_standard_phrase")
        case 5: return String(localized: "5_suffix_standard_phrase")
        case 6: return String(localized: "6_suffix_standard_phrase")
        case 7: return String(localized: "7_suffix_standard_phrase")
        case 8: return String(localized: "8_suffix_standard_phrase")
        case 9: return String(localized: "9_suffix_standard_phrase")
        case 10: return String(localized: "10_suffix_standard_phrase")
        default:
            return self.description
        }
    }
}
