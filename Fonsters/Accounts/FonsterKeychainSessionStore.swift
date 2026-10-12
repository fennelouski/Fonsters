import Foundation
import Security
import CryptoKit

/// Device-only, unlocked-device access. No iCloud synchronization, access group,
/// shared login or persistent identity/code storage is created.
nonisolated final class FonsterKeychainSessionStore: FonsterAccountSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    enum Failure: Error { case storage(OSStatus), corrupt }
    let endpoint: URL
    private let service: String
    init(endpoint: URL) throws {
        guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil, endpoint.password == nil,
              endpoint.port == nil, endpoint.query == nil, endpoint.fragment == nil,
              endpoint.path == "/api/accounts" else { throw Failure.corrupt }
        self.endpoint = endpoint
        let scope = SHA256.hash(data: Data(endpoint.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        service = "com.fonsters.private-account.session.v1." + scope
    }
    private let account = "current"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false,
         kSecUseDataProtectionKeychain as String: true]
    }
    func claimExclusiveOwner() -> Bool { FonsterAccountStoreOwners.shared.claim(service) }
    func read() throws -> FonsterAccountClient.Session? {
        lock.lock(); defer { lock.unlock() }
        var request = query
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure.storage(status) }
        guard let data = value as? Data, data.count <= 4096,
              let session = try? JSONDecoder().decode(FonsterAccountClient.Session.self, from: data) else {
            SecItemDelete(query as CFDictionary); throw Failure.corrupt
        }
        return session
    }
    func write(_ session: FonsterAccountClient.Session) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try JSONEncoder().encode(session)
        guard data.count <= 4096 else { throw Failure.corrupt }
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure.storage(added) }
        } else if status != errSecSuccess { throw Failure.storage(status) }
    }
    func clear() throws {
        lock.lock(); defer { lock.unlock() }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.storage(status) }
    }
}

private nonisolated final class FonsterAccountStoreOwners: @unchecked Sendable {
    static let shared = FonsterAccountStoreOwners()
    private let lock = NSLock()
    private var claimed: Set<String> = []
    func claim(_ namespace: String) -> Bool { lock.withLock { claimed.insert(namespace).inserted } }
}
