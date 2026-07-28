import Foundation

struct CalendarSectionRow: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let isPossibleInterview: Bool
    let kindGuess: StageKind?
}

enum CalendarSection {
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
