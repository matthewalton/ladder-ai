import Foundation

enum JourneyError: Error, Equatable {
    case offerRequired
    case apiKeyRequired
    case resultInvalid
    case requestFailed
}
