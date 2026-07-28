import Foundation

struct FitPassItem: Equatable, Sendable, Codable {
    var id: String
    var text: String
}

enum FitPassPrompts {
    static func condense(from bundle: Bundle = .main) throws -> String {
        try text(named: "condense", from: bundle)
    }

    static func trim(from bundle: Bundle = .main) throws -> String {
        try text(named: "trim", from: bundle)
    }

    private static func text(named name: String, from bundle: Bundle) throws -> String {
        guard let url = bundle.url(forResource: name, withExtension: "md", subdirectory: "Prompts") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor
struct FitPassRunner {
    private let service: any IntelligenceService
    private let bundle: Bundle

    init(service: any IntelligenceService, bundle: Bundle = .main) {
        self.service = service
        self.bundle = bundle
    }

    func condense(_ items: [FitPassItem]) async throws -> [FitPassItem] {
        let prompt = try FitPassPrompts.condense(from: bundle)
        let payload = try Self.payloadJSON(["items": items])
        let response: CondenseResponse = try await completeWithRepair(
            prompt: prompt, payload: payload
        ) { data in
            let decoded: CondenseResponse = try Self.decode(data)
            let expected = items.map(\.id)
            guard decoded.items.map(\.id).sorted() == expected.sorted() else {
                throw TailorValidationFailure(
                    reason: "The condense pass must return exactly the ids it was sent — \(expected.joined(separator: ", ")) — with shortened texts. Never add or remove items."
                )
            }
            guard decoded.items.allSatisfy({
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else {
                throw TailorValidationFailure(reason: "Every condensed text must be non-empty.")
            }
            return decoded
        }
        let byID = Dictionary(uniqueKeysWithValues: response.items.map { ($0.id, $0) })
        return items.compactMap { byID[$0.id] }
    }

    func trim(_ items: [FitPassItem], jobDescription: String) async throws -> [String] {
        let prompt = try FitPassPrompts.trim(from: bundle)
        let payload = try Self.payloadJSON(TrimPayload(items: items, jobDescription: jobDescription))
        let validIDs = Set(items.map(\.id))
        let response: TrimResponse = try await completeWithRepair(
            prompt: prompt, payload: payload
        ) { data in
            let decoded: TrimResponse = try Self.decode(data)
            let keep = Set(decoded.keep)
            guard keep.isSubset(of: validIDs), !keep.isEmpty, keep.count < validIDs.count else {
                throw TailorValidationFailure(
                    reason: "The trim pass must keep at least one item and drop at least one, using only the ids it was sent: \(items.map(\.id).joined(separator: ", "))."
                )
            }
            return decoded
        }
        let keep = Set(response.keep)
        return items.map(\.id).filter(keep.contains)
    }

    private func completeWithRepair<Response>(
        prompt: String,
        payload: String,
        validate: (Data) throws -> Response
    ) async throws -> Response {
        let response = try await service.complete(
            IntelligenceRequest(prompt: prompt, payload: payload)
        )
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

private struct CondenseResponse: Decodable {
    var items: [FitPassItem]
}

private struct TrimPayload: Encodable {
    var items: [FitPassItem]
    var jobDescription: String
}

private struct TrimResponse: Decodable {
    var keep: [String]
}
