import Foundation
import SwiftData

/// The scan's failure states. Validation failures repair once
/// (decisions/0004); transport and truncation fail fast.
enum JDScanError: Error, Equatable {
    case jobDescriptionRequired
    case apiKeyRequired
    case requestFailed(detail: String)
    case responseTruncated
    case resultInvalid(reason: String)
}

/// A scan response the schema or the pool rejects — feeds the single repair
/// request exactly like a tailor result's ([TAILOR-29], [TAILOR-31]).
struct JDScanValidationFailure: Error, Equatable {
    let reason: String
}

enum JDScanPrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "jd-scan", withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// One JD scan at a time (root `CONTEXT.md`: JD scan): reads an
/// Application's job description against the pool and persists the Match —
/// the slice's one write ([TAILOR-27]; decisions/0011). Suggestions stay in
/// memory for review (decisions/0013).
@MainActor
@Observable
final class JDScanStore {
    enum Phase: Equatable {
        case idle
        /// The repair request runs in this phase too — it never gets its own.
        case scanning
        /// The Match is saved; `suggestions` are held transiently.
        case scanned
        case failed(JDScanError)
    }

    private(set) var phase: Phase = .idle
    /// The scan result's pool-level proposals — mint and alias, never
    /// attach (decisions/0013) — transient, awaiting the Match review.
    private(set) var suggestions: [TagSuggestionProposal] = []

    private let keyStore: any APIKeyStore
    private let bundle: Bundle
    private let makeIntelligence: (String) -> any IntelligenceService

    /// `makeIntelligence` receives the stored API key — the live service in
    /// production, a fixture in tests and previews ([TAILOR-35]).
    init(
        keyStore: any APIKeyStore,
        bundle: Bundle = .main,
        makeIntelligence: @escaping (String) -> any IntelligenceService = {
            AnthropicIntelligenceService(apiKey: $0)
        }
    ) {
        self.keyStore = keyStore
        self.bundle = bundle
        self.makeIntelligence = makeIntelligence
    }

    /// Scans the Application's stored job description and replaces its
    /// Match. Works entirely in the Application's own context, so the
    /// matched references and the pool are one set of instances.
    func scan(_ application: Application) async {
        guard !application.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed(.jobDescriptionRequired)
            return
        }
        // No stored key means no live run — never a fixture fallback
        // ([TAILOR-34]; decisions/0002).
        guard let key = try? keyStore.readKey(), !key.isEmpty else {
            phase = .failed(.apiKeyRequired)
            return
        }
        guard let context = application.modelContext else {
            phase = .failed(.requestFailed(detail: "the application is not in a store"))
            return
        }
        phase = .scanning
        suggestions = []
        do {
            let pool = try context.fetch(FetchDescriptor<Profile>()).first?.skills ?? []
            let prompt = try JDScanPrompt.text(from: bundle)
            let payload = Self.payload(jobDescription: application.jobDescription, pool: pool)
            let service = makeIntelligence(key)
            let request = IntelligenceRequest(prompt: prompt, payload: payload)
            let response: Data
            do {
                response = try await service.complete(request)
            } catch AnthropicIntelligenceService.LiveServiceError.truncated {
                throw JDScanError.responseTruncated
            } catch {
                throw JDScanError.requestFailed(detail: Self.requestFailureDetail(for: error))
            }
            let resolved: ResolvedScan
            do {
                resolved = try Self.resolvedScan(from: response, pool: pool)
            } catch let failure as JDScanValidationFailure {
                // Exactly one repair attempt; a repair response failing
                // validation fails the scan (decisions/0004; [TAILOR-32]).
                let repair = IntelligenceRequest(
                    prompt: prompt,
                    payload: Self.repairPayload(original: payload, response: response, failure: failure)
                )
                let repairResponse: Data
                do {
                    repairResponse = try await service.complete(repair)
                } catch AnthropicIntelligenceService.LiveServiceError.truncated {
                    throw JDScanError.responseTruncated
                } catch {
                    throw JDScanError.requestFailed(detail: Self.requestFailureDetail(for: error))
                }
                resolved = try Self.resolvedScan(from: repairResponse, pool: pool)
            }
            // Replace wholesale — the Match tracks the pool, never freezes
            // ([TAILOR-36]).
            if let previous = application.match {
                context.delete(previous)
            }
            let match = Match(
                matchedTags: resolved.matchedTags,
                vocabularyGaps: resolved.vocabularyGaps)
            application.match = match
            try context.save()
            suggestions = resolved.suggestions
            phase = .scanned
        } catch let failure as JDScanValidationFailure {
            phase = .failed(.resultInvalid(reason: failure.reason))
        } catch {
            phase = .failed(
                (error as? JDScanError)
                    ?? .requestFailed(detail: (error as NSError).localizedDescription))
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

    private struct Payload: Encodable {
        var jobDescription: String
        var vocabulary: [PayloadTag]
    }

    /// The request carries the JD verbatim and the whole vocabulary —
    /// primary names with Aliases — so the model matches or aliases before
    /// it mints and a flagged gap is a genuine one ([TAILOR-28]).
    static func payload(jobDescription: String, pool: [SkillTag]) -> String {
        let vocabulary = pool
            .map { PayloadTag(name: $0.name, aliases: $0.aliases) }
            .sorted { $0.name < $1.name }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard
            let data = try? encoder.encode(
                Payload(jobDescription: jobDescription, vocabulary: vocabulary)),
            let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }

    private static func repairPayload(
        original: String, response: Data, failure: JDScanValidationFailure
    ) -> String {
        """
        Your previous response failed validation.

        Failure: \(failure.reason)

        Your previous response was:
        \(String(decoding: response, as: UTF8.self))

        Return corrected JSON for the original input, which follows.

        \(original)
        """
    }

    // MARK: - Validation

    struct ResolvedScan {
        var matchedTags: [SkillTag]
        var vocabularyGaps: [String]
        var suggestions: [TagSuggestionProposal]
    }

    /// Validates the scan response and resolves its matched names against
    /// the pool — case-insensitively across primary names and Aliases; a
    /// name resolving to nothing means the model invented vocabulary and
    /// the response fails ([TAILOR-29]). Two asks resolving to the same Tag
    /// land one reference. A fenced-but-valid response parses exactly as a
    /// bare one ([TAILOR-18]'s tolerance).
    static func resolvedScan(from raw: Data, pool: [SkillTag]) throws -> ResolvedScan {
        let data = FencedJSON.stripped(from: raw)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw JDScanValidationFailure(reason: "the response was not valid JSON")
        }
        guard let root = object as? [String: Any] else {
            throw JDScanValidationFailure(reason: "the response is not a JSON object")
        }
        guard let matchedNames = root["matched"] as? [String] else {
            throw JDScanValidationFailure(reason: "the response has no matched array")
        }
        guard let gaps = root["gaps"] as? [String] else {
            throw JDScanValidationFailure(reason: "the response has no gaps array")
        }
        guard let suggestionList = root["suggestions"] as? [Any] else {
            throw JDScanValidationFailure(reason: "the response has no suggestions array")
        }

        var matchedTags: [SkillTag] = []
        for rawName in matchedNames {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw JDScanValidationFailure(reason: "the matched array contains an empty name")
            }
            guard
                let tag = pool.first(where: {
                    $0.name.caseInsensitiveCompare(name) == .orderedSame
                        || $0.aliases.contains(name.lowercased())
                })
            else {
                throw JDScanValidationFailure(
                    reason: "matched name '\(name)' resolves to no pool Tag")
            }
            if !matchedTags.contains(where: { $0 === tag }) {
                matchedTags.append(tag)
            }
        }

        let vocabularyGaps = gaps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let suggestions: [TagSuggestionProposal] = try suggestionList.enumerated().map { index, entry in
            guard let suggestion = entry as? [String: Any],
                  let kind = suggestion["kind"] as? String
            else {
                throw JDScanValidationFailure(reason: "suggestion \(index + 1) has no kind")
            }
            let rationale = (suggestion["rationale"] as? String) ?? ""
            func required(_ field: String) throws -> String {
                guard let value = (suggestion[field] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !value.isEmpty
                else {
                    throw JDScanValidationFailure(
                        reason: "suggestion \(index + 1) (\(kind)) is missing '\(field)'")
                }
                return value
            }
            // Pool-level kinds only — attach is a point-door kind
            // (decisions/0013).
            let change: TagSuggestionProposal.Change =
                switch kind {
                case "mint": .mint(name: try required("name"))
                case "alias": .alias(try required("alias"), onTagNamed: try required("tag"))
                default:
                    throw JDScanValidationFailure(
                        reason: "suggestion \(index + 1) has unknown kind '\(kind)'")
                }
            return TagSuggestionProposal(id: index, change: change, rationale: rationale)
        }

        return ResolvedScan(
            matchedTags: matchedTags,
            vocabularyGaps: vocabularyGaps,
            suggestions: suggestions)
    }

    func reset() {
        phase = .idle
        suggestions = []
    }
}
