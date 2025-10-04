import Foundation

extension String {
    func truncate(maxLength: Int) -> String {
        if self.count > maxLength {
            return String(self.prefix(maxLength)) + "..."
        }
        return self
    }
}
