import Foundation

enum JourneyError: Error, Equatable {
    /// The narrative is the offer-time retrospective — every other status
    /// refuses ([JOURNEY-5]).
    case offerRequired
    case apiKeyRequired
    /// Even the single repair response failed validation.
    case resultInvalid
    /// The service call itself failed (network, HTTP error) — distinct from
    /// an invalid result.
    case requestFailed
}
