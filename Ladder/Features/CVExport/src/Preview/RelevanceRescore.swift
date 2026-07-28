import Foundation

struct RescoreItem: Equatable, Sendable, Codable {
    var id: String
    var text: String
}

enum RescorePrompt {
    static func text(from bundle: Bundle = .main) throws -> String {
        guard
            let url = bundle.url(forResource: "rescore", withExtension: "md", subdirectory: "Prompts")
        else { throw CocoaError(.fileNoSuchFile) }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// One request, run when the user asks — never per edit.
@MainActor
struct RelevanceRescorePass {
    private let service: any IntelligenceService
    private let bundle: Bundle

    init(service: any IntelligenceService, bundle: Bundle = .main) {
        self.service = service
        self.bundle = bundle
    }

    func rescore(
        _ items: [RescoreItem], jobDescription: String
    ) async throws -> [String: RelevanceStats] {
        let prompt = try RescorePrompt.text(from: bundle)
        let payload = try Self.payloadJSON(
            RescorePayload(items: items, jobDescription: jobDescription))
        let sent = Set(items.map(\.id))
        let response = try await completeWithRepair(prompt: prompt, payload: payload) { data in
            let decoded: RescoreResponse = try Self.decode(data)
            let unjudged = sent.subtracting(decoded.relevance.keys).sorted()
            guard unjudged.isEmpty else {
                throw TailorValidationFailure(
                    reason: "relevance is missing for: \(unjudged.joined(separator: ", ")). Judge every point you were sent on all four criteria, 0–5."
                )
            }
            let strays = decoded.relevance.keys.filter { !sent.contains($0) }.sorted()
            guard strays.isEmpty else {
                throw TailorValidationFailure(
                    reason: "relevance judges ids that were not sent: \(strays.joined(separator: ", ")). Use only the ids in `items`."
                )
            }
            let misscored = decoded.relevance.filter { !$0.value.isOnScale }.keys.sorted()
            guard misscored.isEmpty else {
                throw TailorValidationFailure(
                    reason: "relevance scores out of range for: \(misscored.joined(separator: ", ")). Every criterion score is an integer from 0 to 5."
                )
            }
            return decoded
        }
        return response.relevance
    }

    private func completeWithRepair<Response>(
        prompt: String,
        payload: String,
        validate: (Data) throws -> Response
    ) async throws -> Response {
        let response = try await service.complete(
            IntelligenceRequest(prompt: prompt, payload: payload))
        do {
            return try validate(response)
        } catch let failure as TailorValidationFailure {
            let repair = IntelligenceRequest(
                prompt: prompt,
                payload: """
                Your previous response failed validation.

                Failure: \(failure.reason)

                Your previous response was:
                \(String(decoding: response, as: UTF8.self))

                Return corrected JSON for the original input, which follows.

                \(payload)
                """
            )
            return try validate(await service.complete(repair))
        }
    }

    private static func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: FencedJSON.stripped(from: data))
        } catch {
            throw TailorValidationFailure(
                reason: "The response did not match the expected schema: \(error)"
            )
        }
    }

    private static func payloadJSON(_ body: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return String(decoding: try encoder.encode(body), as: UTF8.self)
    }
}

private struct RescorePayload: Encodable {
    var items: [RescoreItem]
    var jobDescription: String
}

private struct RescoreResponse: Decodable {
    var relevance: [String: RelevanceStats]
}
