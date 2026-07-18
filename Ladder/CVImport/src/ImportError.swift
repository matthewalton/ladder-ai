import Foundation

/// How an import fails (SPEC.md [CVIMPORT-3], [CVIMPORT-10]–[CVIMPORT-12]).
enum ImportError: Error, Equatable {
    /// Import merges into the Profile and never creates it (decisions/0001).
    case profileRequired
    /// Accepted types are exactly PDF and docx (SPEC.md [CVIMPORT-12]).
    case unsupportedFileType
    /// The file yielded no extractable text (SPEC.md [CVIMPORT-11]).
    case extractionFailed
    /// The service's JSON did not match the proposal schema (SPEC.md [CVIMPORT-10]).
    case proposalInvalid
}
