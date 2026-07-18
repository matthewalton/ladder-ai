import Foundation
import Security

/// The real key store: a Keychain generic-password item — never
/// UserDefaults, never on disk, never logged (SPEC.md [TAILOR-16],
/// CLAUDE.md).
struct KeychainAPIKeyStore: APIKeyStore {
    struct KeychainFailure: Error, Equatable {
        var status: OSStatus
    }

    private let service: String
    private static let account = "anthropic-api-key"

    init(service: String = "app.ladder.anthropic") {
        self.service = service
    }

    func readKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(decoding: data, as: UTF8.self)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainFailure(status: status)
        }
    }

    func save(key: String) throws {
        // Delete-then-add keeps one item per service, never duplicates.
        try deleteKey()
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainFailure(status: status)
        }
    }

    func deleteKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainFailure(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}
