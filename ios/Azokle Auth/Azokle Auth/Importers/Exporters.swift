//
//  Exporters.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public enum ExportFormat: String, CaseIterable, Identifiable {
    case encryptedJSON = "Encrypted Vault (JSON)"
    case plainJSON = "Plaintext (JSON)"
    case uriList = "URI List (otpauth://)"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .encryptedJSON, .plainJSON: return "json"
        case .uriList: return "txt"
        }
    }
}

public final class VaultExporter {

    public static func export(repository: VaultRepository, format: ExportFormat, useBackupPasswordOnly: Bool = false) throws -> Data {
        switch format {
        case .encryptedJSON:
            var vaultFile = VaultFile()
            try vaultFile.setDatabase(repository.database, using: repository.masterKey, slots: repository.slots)
            if useBackupPasswordOnly {
                vaultFile = vaultFile.exportable()
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(vaultFile)

        case .plainJSON:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(repository.database)

        case .uriList:
            var lines: [String] = []
            for entry in repository.entries {
                let uri = buildOtpauthURI(entry: entry)
                lines.append(uri)
            }
            let content = lines.joined(separator: "\n")
            return content.data(using: .utf8) ?? Data()
        }
    }

    public static func buildOtpauthURI(entry: VaultEntry) -> String {
        let typeStr = entry.type.rawValue
        var label = ""
        if !entry.issuer.isEmpty && !entry.name.isEmpty {
            label = "\(entry.issuer):\(entry.name)"
        } else if !entry.issuer.isEmpty {
            label = entry.issuer
        } else {
            label = entry.name
        }

        let encodedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? label
        var urlString = "otpauth://\(typeStr)/\(encodedLabel)?secret=\(entry.info.secret)"

        if !entry.issuer.isEmpty {
            let encodedIssuer = entry.issuer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entry.issuer
            urlString += "&issuer=\(encodedIssuer)"
        }

        if entry.info.algo != .sha1 {
            urlString += "&algorithm=\(entry.info.algo.rawValue)"
        }

        if entry.info.digits != 6 {
            urlString += "&digits=\(entry.info.digits)"
        }

        if entry.type == .totp && entry.info.period != 30 {
            urlString += "&period=\(entry.info.period)"
        }

        if entry.type == .hotp {
            urlString += "&counter=\(entry.info.counter)"
        }

        if let pin = entry.info.pin, !pin.isEmpty {
            urlString += "&pin=\(pin)"
        }

        return urlString
    }
}
