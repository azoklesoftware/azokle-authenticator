//
//  CryptoUtils.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public enum CryptoError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidKeySize
    case invalidNonceSize
    case invalidTagSize
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed (bad key, password or corrupt data)"
        case .invalidKeySize: return "Invalid cryptographic key size"
        case .invalidNonceSize: return "Invalid nonce/IV size"
        case .invalidTagSize: return "Invalid authentication tag size"
        case .invalidData: return "Invalid cryptographic data"
        }
    }
}

public struct CryptParameters: Codable, Equatable {
    public let nonce: String
    public let tag: String

    public init(nonce: String, tag: String) {
        self.nonce = nonce
        self.tag = tag
    }

    public init(nonceData: Data, tagData: Data) {
        self.nonce = Hex.encode(nonceData)
        self.tag = Hex.encode(tagData)
    }

    public var nonceData: Data? {
        return Hex.decode(nonce)
    }

    public var tagData: Data? {
        return Hex.decode(tag)
    }
}

public struct CryptResult {
    public let data: Data
    public let params: CryptParameters

    public init(data: Data, params: CryptParameters) {
        self.data = data
        self.params = params
    }
}

public enum CryptoUtils: Sendable {
    public static let keySize = 32 // 256-bit AES
    public static let tagSize = 16 // 128-bit tag
    public static let nonceSize = 12 // 96-bit GCM nonce

    /// Generates secure random bytes using system CSPRNG
    public nonisolated static func generateRandomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            fatalError("Failed to generate secure random bytes")
        }
        return Data(bytes)
    }

    /// Generates a random 256-bit AES master key
    public nonisolated static func generateMasterKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }

    /// Generates a random 256-bit salt for scrypt
    public nonisolated static func generateSalt() -> Data {
        return generateRandomBytes(count: keySize)
    }

    /// Encrypts data using AES-256-GCM
    public nonisolated static func encrypt(data: Data, key: SymmetricKey) throws -> CryptResult {
        let nonceData = generateRandomBytes(count: nonceSize)
        let nonce = try AES.GCM.Nonce(data: nonceData)

        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        let ciphertext = sealedBox.ciphertext
        let tag = sealedBox.tag

        let params = CryptParameters(nonceData: nonceData, tagData: tag)
        return CryptResult(data: ciphertext, params: params)
    }

    /// Decrypts data using AES-256-GCM
    public nonisolated static func decrypt(ciphertext: Data, key: SymmetricKey, params: CryptParameters) throws -> Data {
        guard let nonceData = params.nonceData, let tagData = params.tagData else {
            throw CryptoError.invalidData
        }

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tagData)

        do {
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}
