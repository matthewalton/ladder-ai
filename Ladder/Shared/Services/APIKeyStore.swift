import Foundation

/// Where the user's Anthropic API key lives. The real implementation is the
/// Keychain ([TAILOR-16]); the protocol exists so every other test and
/// preview fakes it (slice AGENTS.md).
protocol APIKeyStore: Sendable {
    /// The stored key, or nil when none is saved.
    func readKey() throws -> String?
    func save(key: String) throws
    func deleteKey() throws
}

/// Test and `#Preview` stand-in — never wired in production (decisions/0002
/// keeps the live/fixture boundary strict; the same goes for keys).
final class InMemoryAPIKeyStore: APIKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    init(key: String? = nil) {
        self.key = key
    }

    func readKey() throws -> String? {
        lock.withLock { key }
    }

    func save(key: String) throws {
        lock.withLock { self.key = key }
    }

    func deleteKey() throws {
        lock.withLock { key = nil }
    }
}
