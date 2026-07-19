import Foundation

enum TailorError: Error, Equatable {
    case jobDescriptionRequired
    case achievementsRequired
    case apiKeyRequired
    /// Even the single repair response failed validation.
    case resultInvalid
    /// The service call itself failed (network, HTTP error) — distinct from
    /// an invalid result.
    case requestFailed
}
