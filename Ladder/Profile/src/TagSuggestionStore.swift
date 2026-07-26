import Foundation

/// The suggestion run's failure states — fail-fast with the reason surfaced
/// (CVImport decisions/0004's stance, adopted by decisions/0012).
enum TagSuggestionError: Error, Equatable {
    case apiKeyRequired
    case requestFailed(detail: String)
    case responseTruncated
    case responseInvalid(reason: String)
}

/// One LLM-proposed change to the Tag vocabulary (root `CONTEXT.md`: Tag
/// suggestion), held for review. The LLM proposes; only the user writes
/// (root ADR 0005).
struct TagSuggestionProposal: Identifiable, Equatable, Sendable {
    enum Change: Equatable, Sendable {
        /// Link an existing Tag, named by its primary name ([PROFILE-33]).
        case attach(tagName: String)
        /// Create a new Tag with this curated casing ([PROFILE-34]).
        case mint(name: String)
        /// Record a lowercase Alias on the named Tag ([PROFILE-35]).
        case alias(String, onTagNamed: String)
    }

    let id: Int
    var change: Change
    var rationale: String
}

enum TagsPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "tags", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// One suggestion run at a time, for one point or Project (decisions/0012).
@MainActor
@Observable
final class TagSuggestionStore {
    enum Phase: Equatable {
        case idle
        case requesting
        /// Proposals are held for review — nothing persisted yet.
        case review
        case failed(TagSuggestionError)
    }

    enum Subject {
        case point(Achievement)
        case project(Project)
    }

    private(set) var phase: Phase = .idle
    private(set) var proposals: [TagSuggestionProposal] = []
    private(set) var subject: Subject?

    private let profileStore: ProfileStore
    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` receives the stored API key — the live service in
    /// production, a fixture in tests and previews ([PROFILE-38]).
    init(
        profileStore: ProfileStore,
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.profileStore = profileStore
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    func requestSuggestions(for achievement: Achievement) async {
        await run(as: .point(achievement), payload: payload(for: .point(achievement)))
    }

    func requestSuggestions(for project: Project) async {
        await run(as: .project(project), payload: payload(for: .project(project)))
    }

    private func run(as subject: Subject, payload: String) async {
        // No stored key means no live run — never a fixture fallback
        // ([PROFILE-37]; Tailor decisions/0002).
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        self.subject = subject
        phase = .requesting
        proposals = []
        do {
            let prompt = try TagsPrompt.text(from: bundle)
            let service = makeIntelligence(key)
            let response: Data
            do {
                response = try await service.complete(
                    IntelligenceRequest(prompt: prompt, payload: payload))
            } catch AnthropicIntelligenceService.LiveServiceError.truncated {
                // A length problem, not a transport one ([CVIMPORT-19]'s rule).
                throw TagSuggestionError.responseTruncated
            } catch {
                throw TagSuggestionError.requestFailed(detail: Self.requestFailureDetail(for: error))
            }
            proposals = try Self.proposals(from: response)
            phase = .review
        } catch {
            // Only a missing bundled prompt reaches the fallback — a
            // packaging bug; every other failure is a TagSuggestionError.
            phase = .failed(
                (error as? TagSuggestionError)
                    ?? .responseInvalid(reason: "the tags prompt could not be loaded from the app bundle"))
        }
    }

    // MARK: - Review

    /// Applies one confirmed proposal through the ProfileStore's own
    /// pathways — the only writer ([PROFILE-33] through [PROFILE-35]).
    /// Attach and mint resolve alias-aware at confirm time, so a stale
    /// pool view in the model's response never duplicates a Tag
    /// ([PROFILE-34]). A colliding alias throws exactly as a manual one
    /// does ([PROFILE-27]); the proposal stays for the review to surface.
    func confirm(_ proposal: TagSuggestionProposal) throws {
        guard let subject else { return }
        switch proposal.change {
        case .attach(let tagName):
            try link(named: tagName, to: subject)
        case .mint(let name):
            try link(named: name, to: subject)
        case .alias(let alias, let onTagNamed):
            guard let tag = profileStore.profile?.skills.first(where: {
                $0.name.caseInsensitiveCompare(onTagNamed) == .orderedSame
                    || $0.aliases.contains(onTagNamed.lowercased())
            }) else {
                throw TagSuggestionError.responseInvalid(
                    reason: "no Tag named '\(onTagNamed)' to record the alias on")
            }
            try profileStore.recordAlias(alias, on: tag)
        }
        proposals.removeAll { $0.id == proposal.id }
    }

    /// Declining lands nothing — per proposal, never all-or-nothing
    /// ([PROFILE-36]; root ADR 0005).
    func decline(_ proposal: TagSuggestionProposal) {
        proposals.removeAll { $0.id == proposal.id }
    }

    private func link(named name: String, to subject: Subject) throws {
        switch subject {
        case .point(let achievement):
            _ = try profileStore.tag(achievement, skillNamed: name)
        case .project(let project):
            _ = try profileStore.tag(project, skillNamed: name)
        }
    }

    private static func requestFailureDetail(for error: Error) -> String {
        switch error {
        case AnthropicIntelligenceService.LiveServiceError.httpFailure(let status):
            "HTTP \(status)"
        case AnthropicIntelligenceService.LiveServiceError.emptyResponse:
            "the service returned an empty response"
        default:
            (error as NSError).localizedDescription
        }
    }

    // MARK: - Payload

    private struct PayloadTag: Encodable {
        var name: String
        var aliases: [String]
    }

    private struct PayloadPoint: Encodable {
        var type: String
        var title: String?
        var name: String?
        var text: String?
        var summary: String?
        var description: String?
        var impactMetric: String?
        var strengthNotes: String?
        var currentTags: [String]
    }

    private struct Payload: Encodable {
        var point: PayloadPoint
        var vocabulary: [PayloadTag]
    }

    /// The request carries the point's own evidence and the whole
    /// vocabulary — primary names with Aliases — so the model attaches or
    /// aliases before it mints ([PROFILE-31], decisions/0012).
    private func payload(for subject: Subject) -> String {
        let vocabulary = (profileStore.profile?.skills ?? [])
            .map { PayloadTag(name: $0.name, aliases: $0.aliases) }
            .sorted { $0.name < $1.name }
        let point: PayloadPoint =
            switch subject {
            case .point(let achievement):
                PayloadPoint(
                    type: "achievement",
                    title: achievement.title,
                    text: achievement.text,
                    impactMetric: achievement.impactMetric,
                    strengthNotes: achievement.strengthNotes,
                    currentTags: achievement.skills.map(\.name).sorted()
                )
            case .project(let project):
                PayloadPoint(
                    type: "project",
                    name: project.name,
                    summary: project.summary.isEmpty ? nil : project.summary,
                    description: project.details.isEmpty ? nil : project.details,
                    currentTags: project.skills.map(\.name).sorted()
                )
            }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Payload(point: point, vocabulary: vocabulary)),
              let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }

    // MARK: - Parsing

    /// Validates the service's JSON into proposals, fail-fast with the part
    /// that was rejected ([PROFILE-39]). A fenced-but-valid response parses
    /// exactly as a bare one — the [CVIMPORT-18] tolerance.
    static func proposals(from raw: Data) throws -> [TagSuggestionProposal] {
        let data = FencedJSON.stripped(from: raw)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TagSuggestionError.responseInvalid(reason: "the response was not valid JSON")
        }
        guard let root = object as? [String: Any] else {
            throw TagSuggestionError.responseInvalid(reason: "the response is not a JSON object")
        }
        guard let list = root["suggestions"] as? [Any] else {
            throw TagSuggestionError.responseInvalid(reason: "the response has no suggestions array")
        }
        return try list.enumerated().map { index, entry in
            guard let suggestion = entry as? [String: Any],
                  let kind = suggestion["kind"] as? String
            else {
                throw TagSuggestionError.responseInvalid(
                    reason: "suggestion \(index + 1) has no kind")
            }
            let rationale = (suggestion["rationale"] as? String) ?? ""
            func required(_ field: String) throws -> String {
                guard let value = (suggestion[field] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !value.isEmpty
                else {
                    throw TagSuggestionError.responseInvalid(
                        reason: "suggestion \(index + 1) (\(kind)) is missing '\(field)'")
                }
                return value
            }
            let change: TagSuggestionProposal.Change =
                switch kind {
                case "attach": .attach(tagName: try required("tag"))
                case "mint": .mint(name: try required("name"))
                case "alias": .alias(try required("alias"), onTagNamed: try required("tag"))
                default:
                    throw TagSuggestionError.responseInvalid(
                        reason: "suggestion \(index + 1) has unknown kind '\(kind)'")
                }
            return TagSuggestionProposal(id: index, change: change, rationale: rationale)
        }
    }
}
