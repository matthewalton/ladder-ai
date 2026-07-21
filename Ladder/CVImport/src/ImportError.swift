import Foundation

enum ImportError: Error, Equatable {
    case unsupportedFileType
    case extractionFailed
    case apiKeyRequired
    /// Transport failure, distinct from an invalid proposal; `detail` names
    /// what failed, e.g. "HTTP 429".
    case requestFailed(detail: String)
    /// Cut off at the model's token cap — retrying truncates again.
    case responseTruncated
    /// `reason` names the rejected part.
    case proposalInvalid(reason: String)
}
