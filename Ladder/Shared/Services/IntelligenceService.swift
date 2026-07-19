import Foundation

/// Prompts load from the bundled `Prompts/` folder, never inline strings.
struct IntelligenceRequest: Equatable, Sendable {
    var prompt: String
    var payload: String
}

/// All LLM access goes through this protocol.
protocol IntelligenceService: Sendable {
    /// The service's raw JSON response for the request.
    func complete(_ request: IntelligenceRequest) async throws -> Data
}
