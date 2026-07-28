import Foundation

enum LongTextField {
    static func collapsesAtAppearance(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
