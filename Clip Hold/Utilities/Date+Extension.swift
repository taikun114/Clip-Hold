import Foundation

extension Date {
    func formatted(for format: String) -> String {
        switch format {
        case "absolute":
            return self.formattedAsAbsolute()
        case "both":
            return self.formattedAsBoth()
        case "relative":
            return self.formattedAsRelative()
        default:
            return self.formattedAsAbsolute()
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
    func formattedAsRelative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // アクセスレベルをinternalに変更
    func formattedAsBoth() -> String {
        let absolutePart = self.formattedAsAbsolute()
        let relativePart = self.formattedAsRelative()
        return "\(absolutePart) (\(relativePart))"
    }
}
