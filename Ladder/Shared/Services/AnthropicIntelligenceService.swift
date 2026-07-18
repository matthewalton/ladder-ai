import Foundation

/// The live `IntelligenceService`: the Anthropic Messages API, raw HTTP.
/// Selected exactly when an API key is stored (Tailor decisions/0002); the
/// model is pinned to the latest Sonnet (Tailor decisions/0003). The key is
/// never logged.
struct AnthropicIntelligenceService: IntelligenceService {
    /// Pinned per Tailor decisions/0003; verified against current Anthropic
    /// API documentation at implement time.
    static let model = "claude-sonnet-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    enum LiveServiceError: Error, Equatable {
        case httpFailure(status: Int)
        case emptyResponse
    }

    /// The request-building seam ([TAILOR-17]) — tested without network.
    /// The prompt travels as the system prompt, the payload as the one user
    /// message.
    static func urlRequest(for request: IntelligenceRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        urlRequest.httpBody = try encoder.encode(MessagesRequest(
            model: model,
            maxTokens: 16000,
            system: request.prompt,
            messages: [MessagesRequest.Message(role: "user", content: request.payload)]
        ))
        return urlRequest
    }

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        let urlRequest = try Self.urlRequest(for: request, apiKey: apiKey)
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LiveServiceError.httpFailure(status: status)
        }
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        // Adaptive thinking can put thinking blocks before the text block —
        // the tailor result JSON is the first text block's text.
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw LiveServiceError.emptyResponse
        }
        return Data(text.utf8)
    }
}

private struct MessagesRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    var model: String
    var maxTokens: Int
    var system: String
    var messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct MessagesResponse: Decodable {
    struct ContentBlock: Decodable {
        var type: String
        var text: String?
    }

    var content: [ContentBlock]
}
