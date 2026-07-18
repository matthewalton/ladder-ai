import Foundation

/// Canned-JSON implementation of `IntelligenceService`: returns a fixture
/// response and records every request it receives. No network — development
/// stays offline until the tailor slice turns live calls on (CLAUDE.md).
actor FixtureIntelligenceService: IntelligenceService {
    private let fixtureJSON: Data
    private(set) var recordedRequests: [IntelligenceRequest] = []

    init(returning fixtureJSON: Data) {
        self.fixtureJSON = fixtureJSON
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

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        recordedRequests.append(request)
        return fixtureJSON
    }
}
