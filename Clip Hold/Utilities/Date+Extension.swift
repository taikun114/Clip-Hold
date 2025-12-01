import Foundation

extension Date {
    func formatted(for format: String, currentDate: Date) -> String {
        let absolutePart = self.formattedAsAbsolute()
        let relativePart = self.formattedAsRelative(currentDate: currentDate)

        switch format {
        case "absolute":
            return absolutePart
        case "relative":
            return relativePart
        case "both_abs_rel_paren":
            return "\(absolutePart) (\(relativePart))"
        case "both_abs_rel_hyphen":
            return "\(absolutePart) - \(relativePart)"
        case "both_rel_abs_paren":
            return "\(relativePart) (\(absolutePart))"
        case "both_rel_abs_hyphen":
            return "\(relativePart) - \(absolutePart)"
        default:
            return absolutePart
        }
    }
    
    // アクセスレベルをinternalに変更
    func formattedAsAbsolute() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    // アクセスレベルをinternalに変更
    func formattedAsRelative(currentDate: Date) -> String {
        let timeInterval = currentDate.timeIntervalSince(self)
        if abs(timeInterval) < 30 {
            return String(localized: "たった今")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: currentDate)
    }
}
