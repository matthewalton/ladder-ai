import Foundation

actor FixtureIntelligenceService: IntelligenceService {
    private let responses: [Data]
    private(set) var recordedRequests: [IntelligenceRequest] = []

    init(returning fixtureJSON: Data) {
        responses = [fixtureJSON]
    }

    init(returning sequence: [Data]) {
        precondition(!sequence.isEmpty, "the fixture needs at least one response")
        responses = sequence
    }

    static func importFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "import-proposal", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("import-proposal.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func tailorFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "tailor-result", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("tailor-result.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func jobDetailsFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "job-details-result", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("job-details-result.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func debriefFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "debrief-result", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("debrief-result.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func prepFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "prep-result", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("prep-result.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func tagSuggestionsFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "tag-suggestions", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("tag-suggestions.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func jdScanFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "jd-scan", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("jd-scan.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    static func journeyFixture(in bundle: Bundle = .main) -> FixtureIntelligenceService {
        guard
            let url = bundle.url(forResource: "journey-result", withExtension: "json", subdirectory: "Fixtures"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("journey-result.json is missing from the bundled Fixtures folder")
        }
        return FixtureIntelligenceService(returning: data)
    }

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        recordedRequests.append(request)
        let index = min(recordedRequests.count - 1, responses.count - 1)
        return responses[index]
    }
}
