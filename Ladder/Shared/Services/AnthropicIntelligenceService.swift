import Foundation

/// The key is never logged.
struct AnthropicIntelligenceService: IntelligenceService {
    static let model = "claude-sonnet-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    // URLRequest defaults to 60s, and because the response is not streamed no
    // bytes arrive until generation finishes — so that default is a ceiling on
    // the whole run, not an idle timeout. A tailor run on a thinking model
    // routinely passes it.
    static let timeout: TimeInterval = 300

    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    enum LiveServiceError: Error, Equatable {
        case httpFailure(status: Int)
        case emptyResponse
        case truncated
    }

    static func urlRequest(for request: IntelligenceRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        urlRequest.httpBody = try encoder.encode(MessagesRequest(
            model: model,
            // Adaptive thinking is on by default on this model and draws from
            // the same budget, so this is not headroom for the answer alone.
            maxTokens: 32000,
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
        return try Self.responseText(from: data)
    }

    static func assembledText(fromEventBytes data: Data) throws -> Data {
        var reply = StreamedReply()
        for line in String(decoding: data, as: UTF8.self).split(
            separator: "\n", omittingEmptySubsequences: false
        ) {
            reply.consume(line: line)
        }
        return try reply.assembled()
    }

    struct StreamedReply {
        private var text = ""

        mutating func consume(line: some StringProtocol) {
            guard line.hasPrefix("data:") else { return }
            let event = try? JSONDecoder().decode(
                StreamEvent.self, from: Data(line.dropFirst("data:".count).utf8)
            )
            guard event?.delta?.type == "text_delta", let piece = event?.delta?.text else { return }
            text += piece
        }

        func assembled() throws -> Data {
            guard !text.isEmpty else { throw LiveServiceError.emptyResponse }
            return Data(text.utf8)
        }
    }

    static func responseText(from data: Data) throws -> Data {
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard decoded.stopReason != "max_tokens" else {
            throw LiveServiceError.truncated
        }
        // Adaptive thinking can put thinking blocks before the text block.
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

private struct StreamEvent: Decodable {
    struct Delta: Decodable {
        var type: String?
        var text: String?
    }

    var delta: Delta?
}

private struct MessagesResponse: Decodable {
    struct ContentBlock: Decodable {
        var type: String
        var text: String?
    }

    var content: [ContentBlock]
    var stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}
