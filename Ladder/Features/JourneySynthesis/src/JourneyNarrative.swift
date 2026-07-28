import Foundation
import SwiftData

@Model
final class JourneyNarrative {
    var text: String
    var generatedAt: Date
    var application: Application?

    init(text: String, generatedAt: Date) {
        self.text = text
        self.generatedAt = generatedAt
    }
}
