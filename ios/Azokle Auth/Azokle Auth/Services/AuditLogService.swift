//
//  AuditLogService.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import Combine

public enum AuditEventType: String, Codable, CaseIterable {
    case vaultUnlocked = "VAULT_UNLOCKED"
    case vaultBackupCreated = "VAULT_BACKUP_CREATED"
    case vaultExported = "VAULT_EXPORTED"
    case entryShared = "ENTRY_SHARED"
    case failedPassword = "VAULT_UNLOCK_FAILED_PASSWORD"
    case failedBiometrics = "VAULT_UNLOCK_FAILED_BIOMETRICS"

    public var title: String {
        switch self {
        case .vaultUnlocked: return "Vault Unlocked"
        case .vaultBackupCreated: return "Backup Created"
        case .vaultExported: return "Vault Exported"
        case .entryShared: return "Token Shared"
        case .failedPassword: return "Failed Password Attempt"
        case .failedBiometrics: return "Failed Biometric Attempt"
        }
    }
}

public struct AuditLogItem: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: AuditEventType
    public let reference: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), eventType: AuditEventType, reference: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.reference = reference
    }
}

public final class AuditLogService: ObservableObject {
    public static let shared = AuditLogService()

    @Published public private(set) var logs: [AuditLogItem] = []

    private static var logFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("audit_logs.json")
    }

    private init() {
        loadLogs()
    }

    public func record(_ type: AuditEventType, reference: String? = nil) {
        let item = AuditLogItem(eventType: type, reference: reference)
        logs.insert(item, at: 0)
        // Keep latest 1000 entries
        if logs.count > 1000 {
            logs.removeLast(logs.count - 1000)
        }
        saveLogs()
    }

    public func clear() {
        logs.removeAll()
        saveLogs()
    }

    private func loadLogs() {
        guard let data = try? Data(contentsOf: Self.logFileURL),
              let loaded = try? JSONDecoder().decode([AuditLogItem].self, from: data)
        else {
            return
        }
        self.logs = loaded
    }

    private func saveLogs() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        try? data.write(to: Self.logFileURL, options: .atomic)
    }
}
