import Foundation

/// Canned-JSON implementation of `IntelligenceService`: returns a fixture
/// response and records every request it receives. No network — development
/// stays offline until the tailor slice turns live calls on (CLAUDE.md).
actor FixtureIntelligenceService: IntelligenceService {
    private let responses: [Data]
    private(set) var recordedRequests: [IntelligenceRequest] = []

    init(returning fixtureJSON: Data) {
        responses = [fixtureJSON]
    }

    /// Responses returned in order, one per request; the last repeats once
    /// the sequence is exhausted. Lets tests script an invalid-then-valid
    /// exchange (the tailor slice's repair loop, [TAILOR-9]).
    init(returning sequence: [Data]) {
        precondition(!sequence.isEmpty, "the fixture needs at least one response")
        responses = sequence
    }

    /// The canned import proposal bundled in the app's Fixtures folder.
    static func importFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "import-proposal", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("import-proposal.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    /// The canned tailor result bundled in the app's Fixtures folder.
    static func tailorFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "tailor-result", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("tailor-result.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        recordedRequests.append(request)
        let index = min(recordedRequests.count - 1, responses.count - 1)
        return responses[index]
    }
}
