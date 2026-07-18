import Foundation

/// How an import fails (SPEC.md [CVIMPORT-3], [CVIMPORT-10]–[CVIMPORT-12],
/// [CVIMPORT-14]).
enum ImportError: Error, Equatable {
    /// Import merges into the Profile and never creates it (decisions/0001).
    case profileRequired
    /// Accepted types are exactly PDF and docx (SPEC.md [CVIMPORT-12]).
    case unsupportedFileType
    /// The file yielded no extractable text (SPEC.md [CVIMPORT-11]).
    case extractionFailed
    /// No stored API key — refused before extraction and before any service
    /// call (SPEC.md [CVIMPORT-14], Tailor decisions/0002).
    case apiKeyRequired
    /// The live request failed in transport — distinct from an invalid
    /// proposal; `detail` names what failed, e.g. "HTTP 429"
    /// (SPEC.md [CVIMPORT-16], decisions/0004).
    case requestFailed(detail: String)
    /// The reply was cut off at the model's token cap — a length problem,
    /// distinct from transport failure: retrying truncates again
    /// (SPEC.md [CVIMPORT-19], decisions/0006).
    case responseTruncated
    /// The service's JSON did not match the proposal schema; `reason` names
    /// the rejected part (SPEC.md [CVIMPORT-10], [CVIMPORT-17]).
    case proposalInvalid(reason: String)
}
