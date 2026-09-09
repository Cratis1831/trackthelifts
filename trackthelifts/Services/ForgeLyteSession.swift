//
//  ForgeLyteSession.swift
//  TrackTheLifts
//

import Foundation
import Security
import StoreKit

@MainActor
final class ForgeLyteSession {
    static let shared = ForgeLyteSession()

    private var isBootstrapping = false

    func bootstrap(forceRefresh: Bool = false) async {
        if isBootstrapping { return }
        if !forceRefresh, ForgeLyteIdentityVault.hasFreshSession() {
            await identifyRevenueCatIfNeeded()
            return
        }

        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            let jws = try await signedAppTransactionJWS()
            let identity = try await ForgeLyteAPI.bootstrap(signedAppTransaction: jws)
            guard identity.sessionToken.isEmpty == false,
                  identity.userKey.hasPrefix("fl_") else {
                return
            }
            ForgeLyteIdentityVault.saveAppTransactionJWS(jws)
            ForgeLyteIdentityVault.saveSession(
                token: identity.sessionToken,
                userKey: identity.userKey
            )
            await RevenueCatService.shared.identifyForgeLyteUser(identity.userKey)
        } catch {
            print("ForgeLyte bootstrap failed: \(error)")
        }
    }

    func searchFoods(_ query: String) async throws -> [RemoteFood] {
        do {
            return try await ForgeLyteAPI.searchFoods(query)
        } catch ForgeLyteAPIError.sessionExpired {
            await bootstrap(forceRefresh: true)
            return try await ForgeLyteAPI.searchFoods(query)
        }
    }

    private func identifyRevenueCatIfNeeded() async {
        guard let userKey = ForgeLyteIdentityVault.userKey() else { return }
        await RevenueCatService.shared.identifyForgeLyteUser(userKey)
    }

    private func signedAppTransactionJWS() async throws -> String {
        if let cached = ForgeLyteIdentityVault.appTransactionJWS(), !cached.isEmpty {
            return cached
        }

        let result = try await AppTransaction.shared
        guard case .verified = result else {
            throw ForgeLyteAPIError.missingAppTransaction
        }
        let jws = result.jwsRepresentation
        guard !jws.isEmpty else {
            throw ForgeLyteAPIError.missingAppTransaction
        }
        return jws
    }
}

enum ForgeLyteIdentityVault {
    private static let service = "com.ashkansdev.track-the-lifts.identity"
    private static let sessionAccount = "server-session"
    private static let userKeyAccount = "user-key"
    private static let appTransactionAccount = "app-transaction-jws"

    static func saveSession(token: String, userKey: String) {
        save(token, account: sessionAccount)
        save(userKey, account: userKeyAccount)
    }

    static func sessionToken() -> String? {
        read(account: sessionAccount)
    }

    static func userKey() -> String? {
        if let stored = read(account: userKeyAccount), stored.hasPrefix("fl_") {
            return stored
        }
        guard let token = sessionToken() else { return nil }
        return userKey(fromSessionToken: token)
    }

    static func saveAppTransactionJWS(_ jws: String) {
        save(jws, account: appTransactionAccount)
    }

    static func appTransactionJWS() -> String? {
        read(account: appTransactionAccount)
    }

    static func hasFreshSession(now: Date = .now) -> Bool {
        guard let token = sessionToken(),
              let payload = sessionPayload(from: token),
              let expiresAt = payload["expiresAt"] as? Double else {
            return false
        }
        let refreshSkewMs: TimeInterval = 12 * 60 * 60 * 1000
        return expiresAt - refreshSkewMs > now.timeIntervalSince1970 * 1000
    }

    static func userKey(fromSessionToken token: String) -> String? {
        guard let payload = sessionPayload(from: token),
              let userKey = payload["userKey"] as? String,
              userKey.hasPrefix("fl_") else {
            return nil
        }
        return userKey
    }

    private static func sessionPayload(from token: String) -> [String: Any]? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let payloadData = Data(base64URLEncoded: String(parts[0])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }
        return payload
    }

    private static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }
}
