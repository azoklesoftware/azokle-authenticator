//
//  VaultRepository.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public enum VaultRepositoryError: Error, LocalizedError {
    case vaultFileNotFound
    case vaultAlreadyInitialized
    case vaultCorrupted
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .vaultFileNotFound: return "Vault file not found on device"
        case .vaultAlreadyInitialized: return "Vault is already initialized"
        case .vaultCorrupted: return "Vault file is corrupted or cannot be parsed"
        case .saveFailed: return "Failed to save vault file to disk"
        }
    }
}

public final class VaultRepository {
    public static let fileName = "azokle_auth.json"

    public private(set) var database: VaultDatabase
    public private(set) var masterKey: SymmetricKey
    public private(set) var slots: [Slot]

    public init(database: VaultDatabase, masterKey: SymmetricKey, slots: [Slot]) {
        self.database = database
        self.masterKey = masterKey
        self.slots = slots
    }

    // MARK: - File Storage Location
    public static var vaultFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent(fileName)
    }

    public static var vaultExists: Bool {
        return FileManager.default.fileExists(atPath: vaultFileURL.path)
    }

    public static func deleteVaultFile() throws {
        if vaultExists {
            try FileManager.default.removeItem(at: vaultFileURL)
        }
    }

    public var rawFileData: Data? {
        return try? Data(contentsOf: Self.vaultFileURL)
    }

    // MARK: - Save Vault Atomically
    public func save() throws {
        var vaultFile = VaultFile()
        try vaultFile.setDatabase(database, using: masterKey, slots: slots)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let fileData = try encoder.encode(vaultFile)

        do {
            try fileData.write(to: Self.vaultFileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw VaultRepositoryError.saveFailed
        }
    }

    // MARK: - Entry Management
    public var entries: [VaultEntry] {
        return database.entries
    }

    public func getEntry(by id: UUID) -> VaultEntry? {
        return database.entries.first(where: { $0.id == id })
    }

    public func addEntry(_ entry: VaultEntry) throws {
        database.entries.append(entry)
        try save()
    }

    public func updateEntry(_ entry: VaultEntry) throws {
        if let index = database.entries.firstIndex(where: { $0.id == entry.id }) {
            database.entries[index] = entry
            try save()
        }
    }

    public func removeEntry(id: UUID) throws {
        database.entries.removeAll(where: { $0.id == id })
        try save()
    }

    public func moveEntry(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var mutableEntries = database.entries
        let itemsToMove = source.map { mutableEntries[$0] }
        for index in source.reversed() {
            mutableEntries.remove(at: index)
        }
        let insertIndex = destination > source.first ?? 0 ? destination - source.count : destination
        mutableEntries.insert(contentsOf: itemsToMove, at: min(insertIndex, mutableEntries.count))
        database.entries = mutableEntries
        try save()
    }

    public func toggleFavorite(for id: UUID) throws {
        if let index = database.entries.firstIndex(where: { $0.id == id }) {
            database.entries[index].isFavorite.toggle()
            try save()
        }
    }

    public func incrementUsage(for id: UUID) throws {
        if let index = database.entries.firstIndex(where: { $0.id == id }) {
            database.entries[index].usageCount += 1
            database.entries[index].lastUsedTimestamp = Int64(Date().timeIntervalSince1970)
            try save()
        }
    }

    // MARK: - Group Management
    public var groups: [VaultGroup] {
        return database.groups
    }

    public func addGroup(name: String) throws -> VaultGroup {
        let group = VaultGroup(name: name)
        database.groups.append(group)
        try save()
        return group
    }

    public func updateGroup(id: UUID, name: String) throws {
        if let index = database.groups.firstIndex(where: { $0.id == id }) {
            database.groups[index].name = name
            try save()
        }
    }

    public func removeGroup(id: UUID) throws {
        database.groups.removeAll(where: { $0.id == id })
        // remove references from entries
        for i in 0..<database.entries.count {
            database.entries[i].groups.remove(id)
        }
        try save()
    }

    // MARK: - Credential Updates
    public func updatePassword(newPassword: String) throws {
        let newPasswordSlot = try PasswordSlot.create(masterKey: masterKey, password: newPassword, isBackup: false)

        // keep backup slots or biometric slots if present
        var newSlots: [Slot] = [newPasswordSlot]
        for slot in slots {
            if let passSlot = slot as? PasswordSlot, passSlot.isBackup {
                newSlots.append(passSlot)
            } else if slot is BiometricSlot {
                newSlots.append(slot)
            }
        }
        self.slots = newSlots
        try save()
    }

    public func setBackupPassword(_ backupPassword: String?) throws {
        // remove existing backup slots
        var newSlots = slots.filter {
            if let passSlot = $0 as? PasswordSlot {
                return !passSlot.isBackup
            }
            return true
        }

        if let pass = backupPassword, !pass.isEmpty {
            let backupSlot = try PasswordSlot.create(masterKey: masterKey, password: pass, isBackup: true)
            newSlots.append(backupSlot)
        }

        self.slots = newSlots
        try save()
    }

    public func setBiometricSlot(_ slot: BiometricSlot?) throws {
        var newSlots = slots.filter { !($0 is BiometricSlot) }
        if let bioSlot = slot {
            newSlots.append(bioSlot)
        }
        self.slots = newSlots
        try save()
    }
}
