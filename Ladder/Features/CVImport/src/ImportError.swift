import Foundation

enum ImportError: Error, Equatable {
    case unsupportedFileType
    case extractionFailed
    case apiKeyRequired
    case requestFailed(detail: String)
    case responseTruncated
    case proposalInvalid(reason: String)
}
