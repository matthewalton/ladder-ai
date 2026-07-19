import Foundation

/// The live implementation is the Keychain; the protocol exists so tests
/// and previews fake it.
protocol APIKeyStore: Sendable {
    func readKey() throws -> String?
    func save(key: String) throws
    func deleteKey() throws
}

/// Test and `#Preview` stand-in — never wired in production.
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
