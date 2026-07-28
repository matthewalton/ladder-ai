import Foundation

enum TailorError: Error, Equatable {
    case jobDescriptionRequired
    case achievementsRequired
    case apiKeyRequired
    case resultInvalid
    case requestFailed
}
