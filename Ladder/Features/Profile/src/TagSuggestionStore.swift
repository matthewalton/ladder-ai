import Foundation

enum TagSuggestionError: Error, Equatable {
    case apiKeyRequired
    case requestFailed(detail: String)
    case responseTruncated
    case responseInvalid(reason: String)
}

struct TagSuggestionProposal: Identifiable, Equatable, Sendable {
    enum Change: Equatable, Sendable {
        case attach(tagName: String)
        case mint(name: String)
        case alias(String, onTagNamed: String)
    }

    let id: Int
    var change: Change
    var rationale: String
    /// The JD-scan vocabulary gap this suggestion dissolves when confirmed,
    /// normalised to the gap as the scan listed it (Tailor decisions/0015);
    /// always nil outside the JD scan door.
    var resolves: String? = nil
}

enum TagsPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "tags", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor
@Observable
final class TagSuggestionStore {
    enum Phase: Equatable {
        case idle
        case requesting
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
                throw TagSuggestionError.responseTruncated
            } catch {
                throw TagSuggestionError.requestFailed(detail: Self.requestFailureDetail(for: error))
            }
            proposals = try Self.proposals(from: response)
            phase = .review
        } catch {
            phase = .failed(
                (error as? TagSuggestionError)
                    ?? .responseInvalid(reason: "the tags prompt could not be loaded from the app bundle"))
        }
    }

    // MARK: - Review

    /// Attach and mint both resolve alias-aware at confirm time, so a stale
    /// pool view in the model's response never duplicates a Tag.
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
        case AnthropicIntelligenceService.LiveServiceError.serviceError(let type, let message):
            "the service reported \(type): \(message)"
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
