import Foundation
import SwiftData

/// The persisted retrospective prose over one Application's full Stage
/// chain, generated at `.offer`. One per Application; regenerating replaces
/// ([JOURNEY-12]). Plain text — the feedstock for the Phase 5 celebration
/// view, not the view itself (decisions/0001).
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
