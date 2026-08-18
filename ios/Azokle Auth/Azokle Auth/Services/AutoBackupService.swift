//
//  AutoBackupService.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import Combine

public struct BackupSnapshot: Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let fileURL: URL
    public let entryCount: Int
    public let fileSizeBytes: Int64

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

public final class AutoBackupService: ObservableObject {
    public static let shared = AutoBackupService()

    @Published public var snapshots: [BackupSnapshot] = []

    private let backupsDirectory: URL

    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        backupsDirectory = paths[0].appendingPathComponent("Backups", isDirectory: true)

        try? FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true, attributes: [
            .protectionKey: FileProtectionType.complete
        ])

        reloadSnapshots()
    }

    public func reloadSnapshots() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            snapshots = []
            return
        }

        var list: [BackupSnapshot] = []
        for file in files where file.pathExtension == "json" {
            let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            let size = Int64(resourceValues?.fileSize ?? 0)
            let date = resourceValues?.creationDate ?? Date()

            // Count entries in snapshot if readable
            var entryCount = 0
            if let data = try? Data(contentsOf: file),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let db = obj["db"] as? [String: Any],
               let entries = db["entries"] as? [Any] {
                entryCount = entries.count
            }

            list.append(BackupSnapshot(
                id: UUID(),
                timestamp: date,
                fileURL: file,
                entryCount: entryCount,
                fileSizeBytes: size
            ))
        }

        snapshots = list.sorted { $0.timestamp > $1.timestamp }
    }

    public func createSnapshot(vaultData: Data, retentionLimit: Int = 10) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "azokle_backup_\(formatter.string(from: Date())).json"
        let targetURL = backupsDirectory.appendingPathComponent(filename)

        do {
            try vaultData.write(to: targetURL, options: [.atomic, .completeFileProtection])
            pruneSnapshots(retentionLimit: retentionLimit)
            reloadSnapshots()
            AuditLogService.shared.log(type: .vaultBackupCreated, reference: filename)
        } catch {
            print("Failed to write auto-backup snapshot: \(error)")
        }
    }

    public func pruneSnapshots(retentionLimit: Int) {
        guard retentionLimit > 0 else { return } // -1 is infinite
        reloadSnapshots()

        if snapshots.count > retentionLimit {
            let excess = snapshots.suffix(from: retentionLimit)
            for item in excess {
                try? FileManager.default.removeItem(at: item.fileURL)
            }
        }
    }

    public func deleteSnapshot(_ snapshot: BackupSnapshot) {
        try? FileManager.default.removeItem(at: snapshot.fileURL)
        reloadSnapshots()
    }
}
