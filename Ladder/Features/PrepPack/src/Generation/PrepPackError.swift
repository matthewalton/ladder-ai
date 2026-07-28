import Foundation

enum PrepPackError: Error, Equatable {
    case inputsRequired
    case apiKeyRequired
    case resultInvalid
    case requestFailed
}
