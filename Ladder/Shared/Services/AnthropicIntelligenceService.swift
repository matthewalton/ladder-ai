import Foundation

/// The key is never logged.
struct AnthropicIntelligenceService: IntelligenceService {
    static let model = "claude-sonnet-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    // URLSession restarts this each time bytes arrive, so on a streamed reply
    // it measures silence rather than the run's length — which is why a value
    // no multi-minute run could survive unstreamed is safe here.
    static let timeout: TimeInterval = 60

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
            messages: [MessagesRequest.Message(role: "user", content: request.payload)],
            thinking: request.narrateThinking ? .summarized : nil,
            stream: true
        ))
        return urlRequest
    }

    func complete(_ request: IntelligenceRequest) async throws -> Data {
        try await complete(request, onDelta: { _ in })
    }

    func complete(
        _ request: IntelligenceRequest,
        onDelta: @Sendable (IntelligenceDelta) -> Void
    ) async throws -> Data {
        let urlRequest = try Self.urlRequest(for: request, apiKey: apiKey)
        let (bytes, response) = try await urlSession.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LiveServiceError.httpFailure(status: status)
        }
        var reply = StreamedReply()
        for try await byte in bytes {
            if let delta = reply.consume(byte: byte) { onDelta(delta) }
        }
        if let delta = reply.flush() { onDelta(delta) }
        return try reply.assembled()
    }

    static func assembledText(
        fromEventBytes data: Data, onDelta: (IntelligenceDelta) -> Void = { _ in }
    ) throws -> Data {
        var reply = StreamedReply()
        for byte in data {
            if let delta = reply.consume(byte: byte) { onDelta(delta) }
        }
        if let delta = reply.flush() { onDelta(delta) }
        return try reply.assembled()
    }

    struct StreamedReply {
        // Server-sent events frame on CR, LF or CRLF and nothing else. Splitting
        // the bytes rather than the Characters keeps U+2028 and its kin — legal
        // unescaped inside a JSON string, and routine in text pasted out of a
        // PDF — from being taken for a frame boundary and losing that delta.
        private static let dataPrefix = Array("data:".utf8)

        private var text = ""
        private var stopReason: String?
        private var line: [UInt8] = []

        mutating func consume(byte: UInt8) -> IntelligenceDelta? {
            guard byte == UInt8(ascii: "\n") else {
                line.append(byte)
                return nil
            }
            return flush()
        }

        mutating func flush() -> IntelligenceDelta? {
            defer { line.removeAll(keepingCapacity: true) }
            var frame = line
            if frame.last == UInt8(ascii: "\r") { frame.removeLast() }
            guard frame.starts(with: Self.dataPrefix) else { return nil }
            guard let event = try? JSONDecoder().decode(
                StreamEvent.self, from: Data(frame.dropFirst(Self.dataPrefix.count))
            ) else { return nil }
            if let reason = event.delta?.stopReason { stopReason = reason }
            switch event.delta?.type {
            case "text_delta":
                guard let piece = event.delta?.text else { return nil }
                text += piece
                return .text(piece)
            case "thinking_delta":
                guard let piece = event.delta?.thinking else { return nil }
                return .narration(piece)
            default:
                return nil
            }
        }

        func assembled() throws -> Data {
            guard stopReason != "max_tokens" else { throw LiveServiceError.truncated }
            guard !text.isEmpty else { throw LiveServiceError.emptyResponse }
            return Data(text.utf8)
        }
    }

}

private struct MessagesRequest: Encodable {
    struct Message: Encodable {
        var role: String
        var content: String
    }

    struct Thinking: Encodable {
        var type: String
        var display: String

        static let summarized = Thinking(type: "adaptive", display: "summarized")
    }

    var model: String
    var maxTokens: Int
    var system: String
    var messages: [Message]
    var thinking: Thinking?
    var stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case thinking
        case stream
    }
}

private struct StreamEvent: Decodable {
    struct Delta: Decodable {
        var type: String?
        var text: String?
        var thinking: String?
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case thinking
            case stopReason = "stop_reason"
        }
    }

    var delta: Delta?
}
