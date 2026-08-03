import Foundation

struct IntelligenceRequest: Equatable, Sendable {
    var prompt: String
    var payload: String
    var narrateThinking = false
}

enum IntelligenceDelta: Equatable, Sendable {
    case text(String)
    case narration(String)
}

protocol IntelligenceService: Sendable {
    func complete(_ request: IntelligenceRequest) async throws -> Data
}
