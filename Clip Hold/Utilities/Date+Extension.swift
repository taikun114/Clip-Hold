import Foundation

extension Date {
    func formatted(for format: String, currentDate: Date) -> String {
        switch format {
        case "absolute":
            return self.formattedAsAbsolute()
        case "both":
            return self.formattedAsBoth(currentDate: currentDate)
        case "relative":
            return self.formattedAsRelative(currentDate: currentDate)
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
    func formattedAsRelative(currentDate: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: currentDate)
    }
    
    // アクセスレベルをinternalに変更
    func formattedAsBoth(currentDate: Date) -> String {
        let absolutePart = self.formattedAsAbsolute()
        let relativePart = self.formattedAsRelative(currentDate: currentDate)
        return "\(absolutePart) (\(relativePart))"
    }
}
