import Foundation

enum DebriefError: Error, Equatable {
    case notesRequired
    case apiKeyRequired
    case resultInvalid
    case requestFailed
}
