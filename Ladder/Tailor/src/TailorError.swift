import Foundation

/// How a tailor run fails (SPEC.md [TAILOR-2]–[TAILOR-4], [TAILOR-10]).
enum TailorError: Error, Equatable {
    /// A run needs a non-empty job description (SPEC.md [TAILOR-2]).
    case jobDescriptionRequired
    /// Tailoring selects from Achievements; with none there is nothing to
    /// select (SPEC.md [TAILOR-3]).
    case achievementsRequired
    /// No API key stored — the refusal points to Settings (SPEC.md
    /// [TAILOR-4], decisions/0002).
    case apiKeyRequired
    /// The repair response also failed validation (SPEC.md [TAILOR-10],
    /// decisions/0004).
    case resultInvalid
    /// The service call itself failed (network, HTTP error) — distinct from
    /// an invalid result.
    case requestFailed
}
