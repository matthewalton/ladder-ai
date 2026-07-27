import Foundation

/// One compact row of the calendar section — the Applications sidebar's
/// standing surface for proposals (decisions/0009).
struct CalendarSectionRow: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let isPossibleInterview: Bool
    let kindGuess: StageKind?
}

enum CalendarSection {
    /// One row per pending proposal, in scan order. Empty when nothing is
    /// pending — the section (divider included) never renders alone.
    static func rows(from proposals: [StageProposal]) -> [CalendarSectionRow] {
        proposals.map { proposal in
            CalendarSectionRow(
                id: proposal.id,
                title: proposal.event.title,
                start: proposal.event.start,
                isPossibleInterview: proposal.isPossibleInterview,
                kindGuess: proposal.kindGuess
            )
        }
    }
}
