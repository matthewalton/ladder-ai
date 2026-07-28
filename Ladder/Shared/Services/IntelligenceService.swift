import Foundation

struct IntelligenceRequest: Equatable, Sendable {
    var prompt: String
    var payload: String
}

protocol IntelligenceService: Sendable {
    func complete(_ request: IntelligenceRequest) async throws -> Data
}
