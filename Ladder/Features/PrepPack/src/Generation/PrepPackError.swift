import Foundation

enum PrepPackError: Error, Equatable {
    /// No job description, no prep context, no prior debriefs — nothing to
    /// ground prep in ([PREP-5]).
    case inputsRequired
    case apiKeyRequired
    /// Even the single repair response failed validation.
    case resultInvalid
    /// The service call itself failed (network, HTTP error) — distinct from
    /// an invalid result.
    case requestFailed
}
