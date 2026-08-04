import Foundation

/// A toured app (`-LadderScratchStore`) must never read the human's Keychain
/// or reach the network.
enum TourMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-LadderScratchStore")
    }

    private static var withholdsKey: Bool {
        ProcessInfo.processInfo.arguments.contains("-LadderTourNoKey")
    }

    private static var refusesRequests: Bool {
        ProcessInfo.processInfo.arguments.contains("-LadderTourServiceFails")
    }

    /// The import sheet opens on a drop zone, and XCUITest can drive neither a
    /// drag nor the sandbox's out-of-process open panel — so the one step the
    /// tour cannot take is choosing the file. Everything after it is real.
    static var importsBundledCV: Bool {
        isActive && ProcessInfo.processInfo.arguments.contains("-LadderTourImportCV")
    }

    static func bundledCV() -> URL? {
        Bundle.main.url(forResource: "sample-cv", withExtension: "pdf", subdirectory: "Fixtures")
    }

    static func keyStore() -> any APIKeyStore {
        guard isActive else { return KeychainAPIKeyStore() }
        return InMemoryAPIKeyStore(key: withholdsKey ? "" : "sk-tour")
    }

    static func makeIntelligence() -> (String) -> any IntelligenceService {
        intelligenceOverride() ?? { AnthropicIntelligenceService(apiKey: $0) }
    }

    static func intelligenceOverride() -> ((String) -> any IntelligenceService)? {
        guard isActive else { return nil }
        let failure: AnthropicIntelligenceService.LiveServiceError? = refusesRequests
            ? .serviceError(type: "overloaded_error", message: "Overloaded")
            : nil
        return { _ in TourIntelligenceService(failure: failure) }
    }
}

/// The fit passes validate that response ids echo payload ids, so those three
/// answers are synthesized from the payload instead of canned.
actor TourIntelligenceService: IntelligenceService {
    struct UnansweredRequest: Error {
        let detail: String
    }

    private let failure: AnthropicIntelligenceService.LiveServiceError?

    init(failure: AnthropicIntelligenceService.LiveServiceError? = nil) {
        self.failure = failure
    }

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        if let failure { throw failure }
        guard let answer = Self.answers.first(where: { $0.prompt == request.prompt }) else {
            throw UnansweredRequest(detail: "no tour answer matches the request's prompt")
        }
        return try answer.respond(request.payload)
    }

    private struct Answer {
        let prompt: String
        let respond: @Sendable (String) throws -> Data
    }

    private struct Item: Codable {
        var id: String
        var text: String
    }

    private struct ItemsPayload: Decodable {
        var items: [Item]
    }

    private struct Scores: Encodable {
        var tech: Int
        var domain: Int
        var seniority: Int
        var impact: Int
    }

    private static let answers: [Answer] = {
        func fixture(_ name: String) -> @Sendable (String) throws -> Data {
            { _ in
                guard
                    let url = Bundle.main.url(
                        forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                    let data = try? Data(contentsOf: url)
                else {
                    throw UnansweredRequest(detail: "\(name).json is missing from Fixtures")
                }
                return data
            }
        }
        var answers: [Answer] = []
        func answer(_ prompt: String, with respond: @escaping @Sendable (String) throws -> Data) {
            guard
                let url = Bundle.main.url(
                    forResource: prompt, withExtension: "md", subdirectory: "Prompts"),
                let text = try? String(contentsOf: url, encoding: .utf8)
            else { return }
            answers.append(Answer(prompt: text, respond: respond))
        }
        answer("tailor", with: fixture("tailor-result"))
        answer("jd-scan", with: fixture("jd-scan"))
        answer("debrief", with: fixture("debrief-result"))
        answer("prep", with: fixture("prep-result"))
        answer("journey", with: fixture("journey-result"))
        answer("job-details", with: fixture("job-details-result"))
        answer("import", with: fixture("import-proposal"))
        answer("tags", with: fixture("tag-suggestions"))
        answer("condense", with: condensed)
        answer("trim", with: trimmed)
        answer("rescore", with: rescored)
        return answers
    }()

    private static let condensed: @Sendable (String) throws -> Data = { payload in
        let items = try items(in: payload).map {
            Item(id: $0.id, text: String($0.text.prefix(72)))
        }
        return try JSONEncoder().encode(["items": items])
    }

    private static let trimmed: @Sendable (String) throws -> Data = { payload in
        let keep = try items(in: payload).dropLast().map(\.id)
        return try JSONEncoder().encode(["keep": keep])
    }

    private static let rescored: @Sendable (String) throws -> Data = { payload in
        let relevance = Dictionary(
            uniqueKeysWithValues: try items(in: payload).map {
                ($0.id, Scores(tech: 4, domain: 3, seniority: 4, impact: 4))
            })
        return try JSONEncoder().encode(["relevance": relevance])
    }

    private static func items(in payload: String) throws -> [Item] {
        do {
            return try JSONDecoder().decode(ItemsPayload.self, from: Data(payload.utf8)).items
        } catch {
            throw UnansweredRequest(detail: "the payload carries no items to echo")
        }
    }
}
