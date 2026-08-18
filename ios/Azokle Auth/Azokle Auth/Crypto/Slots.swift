//
//  Slots.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public enum SlotType: Int, Codable {
    case raw = 0
    case password = 1
    case biometric = 2
}

public class Slot: Identifiable, Codable {
    public let uuid: UUID
    public let type: SlotType
    public var key: String // Hex encoded ciphertext of master key
    public var keyParams: CryptParameters // Nonce + tag

    enum CodingKeys: String, CodingKey {
        case uuid
        case type
        case key
        case keyParams = "key_params"
    }

    public init(uuid: UUID = UUID(), type: SlotType, key: String, keyParams: CryptParameters) {
        self.uuid = uuid
        self.type = type
        self.key = key
        self.keyParams = keyParams
    }

    /// Decrypts the master key from this slot using the given wrapper key
    public func getMasterKey(using wrapperKey: SymmetricKey) throws -> SymmetricKey {
        guard let encryptedData = Hex.decode(key) else {
            throw CryptoError.invalidData
        }
        let decryptedData = try CryptoUtils.decrypt(ciphertext: encryptedData, key: wrapperKey, params: keyParams)
        return SymmetricKey(data: decryptedData)
    }

    /// Sets and encrypts the master key into this slot using the given wrapper key
    public func setMasterKey(_ masterKey: SymmetricKey, using wrapperKey: SymmetricKey) throws {
        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }
        let result = try CryptoUtils.encrypt(data: masterKeyData, key: wrapperKey)
        self.key = Hex.encode(result.data)
        self.keyParams = result.params
    }
}

// MARK: - PasswordSlot
public final class PasswordSlot: Slot {
    public var scryptParams: SCryptParameters
    public var isRepaired: Bool
    public var isBackup: Bool

    enum PasswordCodingKeys: String, CodingKey {
        case n, r, p, salt
        case repaired
        case isBackup = "is_backup"
    }

    public init(
        uuid: UUID = UUID(),
        key: String,
        keyParams: CryptParameters,
        scryptParams: SCryptParameters,
        isRepaired: Bool = true,
        isBackup: Bool = false
    ) {
        self.scryptParams = scryptParams
        self.isRepaired = isRepaired
        self.isBackup = isBackup
        super.init(uuid: uuid, type: .password, key: key, keyParams: keyParams)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuidString = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString
        let uuid = UUID(uuidString: uuidString) ?? UUID()
        let type = try container.decode(SlotType.self, forKey: .type)
        let key = try container.decode(String.self, forKey: .key)
        let keyParams = try container.decode(CryptParameters.self, forKey: .keyParams)

        let passContainer = try decoder.container(keyedBy: PasswordCodingKeys.self)
        let n = try passContainer.decode(Int.self, forKey: .n)
        let r = try passContainer.decode(Int.self, forKey: .r)
        let p = try passContainer.decode(Int.self, forKey: .p)
        let salt = try passContainer.decode(String.self, forKey: .salt)
        let repaired = try passContainer.decodeIfPresent(Bool.self, forKey: .repaired) ?? true
        let isBackup = try passContainer.decodeIfPresent(Bool.self, forKey: .isBackup) ?? false

        self.scryptParams = SCryptParameters(n: n, r: r, p: p, salt: salt)
        self.isRepaired = repaired
        self.isBackup = isBackup
        super.init(uuid: uuid, type: type, key: key, keyParams: keyParams)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var passContainer = encoder.container(keyedBy: PasswordCodingKeys.self)
        try passContainer.encode(scryptParams.n, forKey: .n)
        try passContainer.encode(scryptParams.r, forKey: .r)
        try passContainer.encode(scryptParams.p, forKey: .p)
        try passContainer.encode(scryptParams.salt, forKey: .salt)
        try passContainer.encode(isRepaired, forKey: .repaired)
        try passContainer.encode(isBackup, forKey: .isBackup)
    }

    /// Derives wrapper key from password and unlocks master key
    public func unlockMasterKey(password: String) throws -> SymmetricKey {
        let derivedKeyData = try SCrypt.generate(password: password, params: scryptParams)
        let wrapperKey = SymmetricKey(data: derivedKeyData)
        return try getMasterKey(using: wrapperKey)
    }

    /// Creates a new PasswordSlot wrapping the given MasterKey
    public static func create(masterKey: SymmetricKey, password: String, isBackup: Bool = false) throws -> PasswordSlot {
        let salt = CryptoUtils.generateSalt()
        let scryptParams = SCryptParameters(n: 32768, r: 8, p: 1, saltData: salt)
        let derivedKeyData = try SCrypt.generate(password: password, params: scryptParams)
        let wrapperKey = SymmetricKey(data: derivedKeyData)

        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }
        let cryptResult = try CryptoUtils.encrypt(data: masterKeyData, key: wrapperKey)

        return PasswordSlot(
            key: Hex.encode(cryptResult.data),
            keyParams: cryptResult.params,
            scryptParams: scryptParams,
            isRepaired: true,
            isBackup: isBackup
        )
    }
}

// MARK: - BiometricSlot
public final class BiometricSlot: Slot {
    public init(uuid: UUID = UUID(), key: String, keyParams: CryptParameters) {
        super.init(uuid: uuid, type: .biometric, key: key, keyParams: keyParams)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuidString = try container.decodeIfPresent(String.self, forKey: .uuid) ?? UUID().uuidString
        let uuid = UUID(uuidString: uuidString) ?? UUID()
        let type = try container.decode(SlotType.self, forKey: .type)
        let key = try container.decode(String.self, forKey: .key)
        let keyParams = try container.decode(CryptParameters.self, forKey: .keyParams)
        super.init(uuid: uuid, type: type, key: key, keyParams: keyParams)
    }
}

// MARK: - Slot Polymorphic Deserializer / Serializer
public struct AnySlot: Codable {
    public let slot: Slot

    public init(_ slot: Slot) {
        self.slot = slot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Slot.CodingKeys.self)
        let type = try container.decode(SlotType.self, forKey: .type)
        switch type {
        case .password:
            self.slot = try PasswordSlot(from: decoder)
        case .biometric:
            self.slot = try BiometricSlot(from: decoder)
        case .raw:
            self.slot = try Slot(from: decoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try slot.encode(to: encoder)
    }
}
