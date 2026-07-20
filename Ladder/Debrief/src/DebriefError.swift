import Foundation

enum DebriefError: Error, Equatable {
    /// No attached notes overview — nothing to ground a debrief in
    /// (decisions/0002).
    case notesRequired
    case apiKeyRequired
    /// Even the single repair response failed validation.
    case resultInvalid
    /// The service call itself failed (network, HTTP error) — distinct from
    /// an invalid result.
    case requestFailed
}
