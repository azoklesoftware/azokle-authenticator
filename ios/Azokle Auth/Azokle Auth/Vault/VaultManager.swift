//
//  VaultManager.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import SwiftUI
import Combine
import CryptoKit
import LocalAuthentication

@MainActor
public final class VaultManager: ObservableObject {
    public static let shared = VaultManager()

    @Published public var isVaultLoaded: Bool = false
    @Published public var isLocked: Bool = true
    @Published public var repository: VaultRepository?
    @Published public var entries: [VaultEntry] = []
    @Published public var groups: [VaultGroup] = []
    @Published public var hasExistingVault: Bool = false
    @Published public var isBiometricsAvailable: Bool = false
    @Published public var isBiometricsConfigured: Bool = false

    private static let biometricKeychainKey = "com.azokle.authenticator.biometricWrapper"

    private init() {
        refreshVaultStatus()
    }

    public func refreshVaultStatus() {
        self.hasExistingVault = VaultRepository.vaultExists
        checkBiometrics()
    }

    private func checkBiometrics() {
        let context = LAContext()
        var error: NSError?
        self.isBiometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if hasExistingVault {
            do {
                let fileData = try Data(contentsOf: VaultRepository.vaultFileURL)
                let vaultFile = try JSONDecoder().decode(VaultFile.self, from: fileData)
                let bioSlot = vaultFile.header.slots?.first(where: { $0.slot is BiometricSlot })
                self.isBiometricsConfigured = bioSlot != nil && hasKeychainBiometricKey()
            } catch {
                self.isBiometricsConfigured = false
            }
        } else {
            self.isBiometricsConfigured = false
        }
    }

    // MARK: - Initial Vault Setup
    public func createVault(password: String) async throws {
        let repo = try await Task.detached(priority: .userInitiated) {
            let masterKey = CryptoUtils.generateMasterKey()
            let passwordSlot = try PasswordSlot.create(masterKey: masterKey, password: password, isBackup: false)
            let initialDatabase = VaultDatabase(version: 1, entries: [], groups: [])

            let repo = VaultRepository(database: initialDatabase, masterKey: masterKey, slots: [passwordSlot])
            try repo.save()
            return repo
        }.value

        self.repository = repo
        self.entries = repo.entries
        self.groups = repo.groups
        self.isVaultLoaded = true
        self.isLocked = false
        self.hasExistingVault = true

        AuditLogService.shared.record(.vaultUnlocked)
    }

    // MARK: - Unlock with Password
    public func unlock(password: String) async throws {
        guard VaultRepository.vaultExists else {
            throw VaultRepositoryError.vaultFileNotFound
        }

        let repo: VaultRepository
        do {
            repo = try await Task.detached(priority: .userInitiated) {
                let fileData = try Data(contentsOf: VaultRepository.vaultFileURL)
                let vaultFile = try JSONDecoder().decode(VaultFile.self, from: fileData)

                guard let anySlots = vaultFile.header.slots, !anySlots.isEmpty else {
                    throw CryptoError.decryptionFailed
                }

                var decryptedMasterKey: SymmetricKey?

                // Attempt each password slot (primary or backup)
                for anySlot in anySlots {
                    if let passwordSlot = anySlot.slot as? PasswordSlot {
                        do {
                            let masterKey = try passwordSlot.unlockMasterKey(password: password)
                            decryptedMasterKey = masterKey
                            break
                        } catch {
                            // Try next slot
                            continue
                        }
                    }
                }

                guard let masterKey = decryptedMasterKey else {
                    throw CryptoError.decryptionFailed
                }

                let database = try vaultFile.getDatabase(using: masterKey)
                let slots = anySlots.map { $0.slot }

                return VaultRepository(database: database, masterKey: masterKey, slots: slots)
            }.value
        } catch {
            AuditLogService.shared.record(.failedPassword)
            throw error
        }

        self.repository = repo
        self.entries = repo.entries
        self.groups = repo.groups
        self.isVaultLoaded = true
        self.isLocked = false

        AuditLogService.shared.record(.vaultUnlocked)
    }

    // MARK: - Unlock with Biometrics
    public func unlockWithBiometrics() async throws {
        guard isBiometricsConfigured else {
            throw CryptoError.decryptionFailed
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your Azokle Auth Vault"
        )

        guard success else {
            AuditLogService.shared.record(.failedBiometrics)
            throw CryptoError.decryptionFailed
        }

        // Retrieve biometric wrapper key from Keychain using the authenticated context
        guard let wrapperKeyData = getKeychainBiometricKey(context: context) else {
            AuditLogService.shared.record(.failedBiometrics)
            throw CryptoError.decryptionFailed
        }

        let fileData = try Data(contentsOf: VaultRepository.vaultFileURL)
        let vaultFile = try JSONDecoder().decode(VaultFile.self, from: fileData)

        guard let bioSlotItem = vaultFile.header.slots?.first(where: { $0.slot is BiometricSlot }),
              let bioSlot = bioSlotItem.slot as? BiometricSlot else {
            throw CryptoError.decryptionFailed
        }

        let wrapperKey = SymmetricKey(data: wrapperKeyData)
        let masterKey = try bioSlot.getMasterKey(using: wrapperKey)
        let database = try vaultFile.getDatabase(using: masterKey)
        let slots = vaultFile.header.slots!.map { $0.slot }

        let repo = VaultRepository(database: database, masterKey: masterKey, slots: slots)
        self.repository = repo
        self.entries = repo.entries
        self.groups = repo.groups
        self.isVaultLoaded = true
        self.isLocked = false

        AuditLogService.shared.record(.vaultUnlocked)
    }

    // MARK: - Enable / Disable Biometrics
    public func enableBiometrics() throws {
        guard let repo = repository else { return }

        // Generate a random biometric wrapper key
        let wrapperKey = CryptoUtils.generateMasterKey()
        let wrapperKeyData = wrapperKey.withUnsafeBytes { Data($0) }

        // Save wrapper key in Keychain with biometrics access control
        saveKeychainBiometricKey(data: wrapperKeyData)

        // Create biometric slot
        let masterKeyData = repo.masterKey.withUnsafeBytes { Data($0) }
        let cryptResult = try CryptoUtils.encrypt(data: masterKeyData, key: wrapperKey)

        let bioSlot = BiometricSlot(
            key: Hex.encode(cryptResult.data),
            keyParams: cryptResult.params
        )

        try repo.setBiometricSlot(bioSlot)
        self.isBiometricsConfigured = true
    }

    public func disableBiometrics() throws {
        guard let repo = repository else { return }
        deleteKeychainBiometricKey()
        try repo.setBiometricSlot(nil)
        self.isBiometricsConfigured = false
    }

    // MARK: - Lock & Memory Purge
    public func lock() {
        self.repository = nil
        self.entries = []
        self.groups = []
        self.isVaultLoaded = false
        self.isLocked = true
    }

    // MARK: - Sync State
    public func syncEntries() {
        if let repo = repository {
            self.entries = repo.entries
            self.groups = repo.groups
        }
    }

    public func wipeVault() throws {
        try VaultRepository.deleteVaultFile()
        deleteKeychainBiometricKey()
        lock()
        refreshVaultStatus()
    }

    // MARK: - Keychain Helpers
    private func saveKeychainBiometricKey(data: Data) {
        deleteKeychainBiometricKey()

        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            nil
        )

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.biometricKeychainKey,
            kSecValueData as String: data
        ]

        if let access = access {
            query[kSecAttrAccessControl as String] = access
        }

        SecItemAdd(query as CFDictionary, nil)
    }

    private func getKeychainBiometricKey(context: LAContext? = nil) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.biometricKeychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let context = context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private func hasKeychainBiometricKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.biometricKeychainKey,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    private func deleteKeychainBiometricKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.biometricKeychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
