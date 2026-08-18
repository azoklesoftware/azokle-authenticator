//
//  VaultFile.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public struct VaultFileHeader: Codable {
    public var slots: [AnySlot]?
    public var params: CryptParameters?

    public init(slots: [AnySlot]? = nil, params: CryptParameters? = nil) {
        self.slots = slots
        self.params = params
    }

    public var isEmpty: Bool {
        return (slots == nil || slots!.isEmpty) && params == nil
    }
}

public struct VaultFile: Codable {
    public static let currentVersion = 1

    public var version: Int
    public var header: VaultFileHeader
    public var db: String // Base64 encoded encrypted payload or JSON string

    public init(version: Int = currentVersion, header: VaultFileHeader = VaultFileHeader(), db: String = "") {
        self.version = version
        self.header = header
        self.db = db
    }

    public var isEncrypted: Bool {
        return !header.isEmpty
    }

    /// Decrypts the inner VaultDatabase payload using the decrypted master key
    public func getDatabase(using masterKey: SymmetricKey) throws -> VaultDatabase {
        guard let encryptedData = Data(base64Encoded: db) else {
            throw CryptoError.invalidData
        }
        guard let params = header.params else {
            throw CryptoError.invalidData
        }

        let decryptedBytes = try CryptoUtils.decrypt(ciphertext: encryptedData, key: masterKey, params: params)
        let decoder = JSONDecoder()
        return try decoder.decode(VaultDatabase.self, from: decryptedBytes)
    }

    /// Encrypts and sets the VaultDatabase payload using the master key and slots
    public mutating func setDatabase(_ database: VaultDatabase, using masterKey: SymmetricKey, slots: [Slot]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let databaseBytes = try encoder.encode(database)

        let cryptResult = try CryptoUtils.encrypt(data: databaseBytes, key: masterKey)
        self.db = cryptResult.data.base64EncodedString()
        self.header = VaultFileHeader(
            slots: slots.map { AnySlot($0) },
            params: cryptResult.params
        )
    }

    /// Creates an exportable copy of this vault file (optionally stripping primary password slot if backup password exists)
    public func exportable() -> VaultFile {
        guard isEncrypted, let slots = header.slots else {
            return self
        }

        let backupSlots = slots.filter {
            if let passSlot = $0.slot as? PasswordSlot {
                return passSlot.isBackup
            }
            return false
        }

        if !backupSlots.isEmpty {
            return VaultFile(
                version: version,
                header: VaultFileHeader(slots: backupSlots, params: header.params),
                db: db
            )
        }

        return self
    }
}
