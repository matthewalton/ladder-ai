import Foundation

/// One request to the intelligence layer: a versioned prompt plus the
/// user-content payload it operates on. Prompts load from the bundled
/// `Prompts/` folder, never inline strings (CLAUDE.md).
struct IntelligenceRequest: Equatable, Sendable {
    var prompt: String
    var payload: String
}

/// All LLM access goes through this protocol (ARCHITECTURE.md §7). Phase 1
/// development is fixture-driven; the live Anthropic implementation arrives
/// with the tailor slice.
protocol IntelligenceService: Sendable {
    /// The service's raw JSON response for the request.
    func complete(_ request: IntelligenceRequest) async throws -> Data
}
