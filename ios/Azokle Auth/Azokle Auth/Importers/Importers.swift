//
//  Importers.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public struct ImportedVaultResult {
    public let entries: [VaultEntry]
    public let groups: [VaultGroup]
    public let sourceName: String
}

public enum ImporterError: Error, LocalizedError {
    case unsupportedFormat
    case noValidTokensFound
    case invalidFile

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "File format is not recognized or supported"
        case .noValidTokensFound: return "No valid 2FA tokens found in the imported file"
        case .invalidFile: return "Unable to read or parse the selected file"
        }
    }
}

public final class UniversalImporter {

    public static func parse(data: Data, fileName: String? = nil, password: String? = nil) throws -> ImportedVaultResult {
        if let jsonString = String(data: data, encoding: .utf8) {
            // 1. Try Azokle / Aegis JSON format
            if let result = parseAzokleOrAegisJSON(data: data) {
                return result
            }

            // 2. Try 2FAS JSON format
            if let result = parse2FASJSON(data: data) {
                return result
            }

            // 3. Try andOTP JSON format
            if let andOtpEntries = try? AndOtpImporter.parse(data: data, password: password), !andOtpEntries.isEmpty {
                return ImportedVaultResult(entries: andOtpEntries, groups: [], sourceName: "andOTP Backup")
            }

            // 4. Try Authenticator Pro JSON format
            if let proEntries = try? AuthenticatorProImporter.parse(data: data), !proEntries.isEmpty {
                return ImportedVaultResult(entries: proEntries, groups: [], sourceName: "Authenticator Pro")
            }

            // 5. Try Authy JSON format
            if let authyEntries = try? AuthyImporter.parse(data: data), !authyEntries.isEmpty {
                return ImportedVaultResult(entries: authyEntries, groups: [], sourceName: "Authy Backup")
            }

            // 6. Try FreeOTP / FreeOTP+ format
            if let freeOtpEntries = try? FreeOtpImporter.parse(data: data), !freeOtpEntries.isEmpty {
                return ImportedVaultResult(entries: freeOtpEntries, groups: [], sourceName: "FreeOTP / FreeOTP+")
            }

            // 7. Try WinAuth XML format
            if let winAuthEntries = try? WinAuthImporter.parse(data: data), !winAuthEntries.isEmpty {
                return ImportedVaultResult(entries: winAuthEntries, groups: [], sourceName: "WinAuth XML")
            }

            // 8. Try Bitwarden JSON format
            if let result = parseBitwardenJSON(data: data) {
                return result
            }

            // 9. Try newline-separated otpauth:// URIs
            if let result = parseOtpauthUriList(text: jsonString) {
                return result
            }

            // 10. Try Bitwarden CSV format
            if let result = parseBitwardenCSV(text: jsonString) {
                return result
            }
        }

        throw ImporterError.unsupportedFormat
    }

    // MARK: - 1. Azokle / Aegis / andOTP JSON Parser
    private static func parseAzokleOrAegisJSON(data: Data) -> ImportedVaultResult? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var entriesArray: [[String: Any]]?

        // Check if top-level has "db" object
        if let db = jsonObject["db"] as? [String: Any], let entries = db["entries"] as? [[String: Any]] {
            entriesArray = entries
        } else if let entries = jsonObject["entries"] as? [[String: Any]] {
            entriesArray = entries
        }

        guard let entries = entriesArray, !entries.isEmpty else { return nil }

        var parsedEntries: [VaultEntry] = []
        var parsedGroups: [VaultGroup] = []

        if let db = jsonObject["db"] as? [String: Any], let groups = db["groups"] as? [[String: Any]] {
            for g in groups {
                if let name = g["name"] as? String {
                    let uuid = (g["uuid"] as? String).flatMap(UUID.init) ?? UUID()
                    parsedGroups.append(VaultGroup(id: uuid, name: name))
                }
            }
        }

        for dict in entries {
            if let entryData = try? JSONSerialization.data(withJSONObject: dict),
               let entry = try? JSONDecoder().decode(VaultEntry.self, from: entryData) {
                parsedEntries.append(entry)
            }
        }

        guard !parsedEntries.isEmpty else { return nil }
        return ImportedVaultResult(entries: parsedEntries, groups: parsedGroups, sourceName: "Azokle / Aegis")
    }

    // MARK: - 2. 2FAS JSON Parser
    private static func parse2FASJSON(data: Data) -> ImportedVaultResult? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let services = jsonObject["services"] as? [[String: Any]],
              !services.isEmpty
        else {
            return nil
        }

        var parsedEntries: [VaultEntry] = []

        for item in services {
            guard let name = item["name"] as? String ?? item["service"] as? String,
                  let otp = item["otp"] as? [String: Any],
                  let secret = otp["secret"] as? String, !secret.isEmpty
            else {
                continue
            }

            let account = otp["account"] as? String ?? ""
            let tokenType = (otp["tokenType"] as? String)?.lowercased() ?? "totp"
            let digits = otp["digits"] as? Int ?? 6
            let period = otp["period"] as? Int ?? 30
            let algoStr = (otp["algorithm"] as? String)?.uppercased() ?? "SHA1"
            let algo = OTPAlgorithm(rawValue: algoStr) ?? .sha1

            let type: OTPType
            switch tokenType {
            case "hotp": type = .hotp
            case "steam": type = .steam
            case "motp": type = .motp
            case "yaotp": type = .yaotp
            default: type = .totp
            }

            let info = OtpInfoModel(secret: secret, algo: algo, digits: digits, period: period)
            let entry = VaultEntry(
                type: type,
                name: account,
                issuer: name,
                note: "",
                isFavorite: false,
                info: info
            )
            parsedEntries.append(entry)
        }

        guard !parsedEntries.isEmpty else { return nil }
        return ImportedVaultResult(entries: parsedEntries, groups: [], sourceName: "2FAS")
    }

    // MARK: - 3. Bitwarden JSON Parser
    private static func parseBitwardenJSON(data: Data) -> ImportedVaultResult? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = jsonObject["items"] as? [[String: Any]],
              !items.isEmpty
        else {
            return nil
        }

        var parsedEntries: [VaultEntry] = []

        for item in items {
            guard let login = item["login"] as? [String: Any],
                  let totpUriString = login["totp"] as? String, !totpUriString.isEmpty
            else {
                continue
            }

            let itemName = item["name"] as? String ?? ""
            let username = login["username"] as? String ?? ""

            if let entry = parseSingleOtpauthURI(uriString: totpUriString, fallbackIssuer: itemName, fallbackName: username) {
                parsedEntries.append(entry)
            }
        }

        guard !parsedEntries.isEmpty else { return nil }
        return ImportedVaultResult(entries: parsedEntries, groups: [], sourceName: "Bitwarden")
    }

    // MARK: - 4. Plaintext otpauth:// URI List Parser
    private static func parseOtpauthUriList(text: String) -> ImportedVaultResult? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("otpauth://") || $0.hasPrefix("otpauth-migration://") }

        guard !lines.isEmpty else { return nil }

        var parsedEntries: [VaultEntry] = []

        for line in lines {
            if line.hasPrefix("otpauth-migration://") {
                if let url = URL(string: line), let migration = GoogleAuthMigrationParser.parse(url: url) {
                    for item in migration.entries {
                        let secretB32 = Base32.encode(item.secret)
                        let info = OtpInfoModel(secret: secretB32, algo: item.algorithm, digits: item.digits, period: 30, counter: item.counter)
                        let entry = VaultEntry(type: item.type, name: item.name, issuer: item.issuer, info: info)
                        parsedEntries.append(entry)
                    }
                }
            } else if let entry = parseSingleOtpauthURI(uriString: line) {
                parsedEntries.append(entry)
            }
        }

        guard !parsedEntries.isEmpty else { return nil }
        return ImportedVaultResult(entries: parsedEntries, groups: [], sourceName: "URI List")
    }

    // MARK: - 5. Bitwarden CSV Parser
    private static func parseBitwardenCSV(text: String) -> ImportedVaultResult? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { return nil }
        let header = lines[0].lowercased()
        guard header.contains("totp") else { return nil }

        // Find totp column index
        let headerCols = header.components(separatedBy: ",")
        guard let totpIndex = headerCols.firstIndex(where: { $0.contains("totp") }),
              let nameIndex = headerCols.firstIndex(where: { $0.contains("name") })
        else {
            return nil
        }

        var parsedEntries: [VaultEntry] = []

        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",")
            guard cols.count > totpIndex else { continue }
            let totpVal = cols[totpIndex].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            let nameVal = cols.count > nameIndex ? cols[nameIndex].replacingOccurrences(of: "\"", with: "") : ""

            if !totpVal.isEmpty, let entry = parseSingleOtpauthURI(uriString: totpVal, fallbackIssuer: nameVal) {
                parsedEntries.append(entry)
            }
        }

        guard !parsedEntries.isEmpty else { return nil }
        return ImportedVaultResult(entries: parsedEntries, groups: [], sourceName: "Bitwarden CSV")
    }

    // MARK: - Helper: Parse Single otpauth:// URI
    public static func parseSingleOtpauthURI(uriString: String, fallbackIssuer: String = "", fallbackName: String = "") -> VaultEntry? {
        // If the string is just a raw base32 secret
        if !uriString.hasPrefix("otpauth://") {
            if Base32.decode(uriString) != nil {
                let info = OtpInfoModel(secret: uriString)
                return VaultEntry(type: .totp, name: fallbackName, issuer: fallbackIssuer, info: info)
            }
            return nil
        }

        guard let url = URL(string: uriString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let typeStr = components.host?.lowercased() ?? "totp"
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var issuer = fallbackIssuer
        var accountName = fallbackName

        if let labelDecoded = path.removingPercentEncoding {
            if labelDecoded.contains(":") {
                let parts = labelDecoded.split(separator: ":", maxSplits: 1).map(String.init)
                issuer = parts[0].trimmingCharacters(in: .whitespaces)
                accountName = parts[1].trimmingCharacters(in: .whitespaces)
            } else {
                accountName = labelDecoded
            }
        }

        var secret = ""
        var algo: OTPAlgorithm = .sha1
        var digits = 6
        var period = 30
        var counter: UInt64 = 0
        var pin: String? = nil

        if let queryItems = components.queryItems {
            for item in queryItems {
                let val = item.value ?? ""
                switch item.name.lowercased() {
                case "secret":
                    secret = val.uppercased().replacingOccurrences(of: " ", with: "")
                case "issuer":
                    issuer = val
                case "algorithm":
                    algo = OTPAlgorithm(rawValue: val.uppercased()) ?? .sha1
                case "digits":
                    digits = Int(val) ?? 6
                case "period":
                    period = Int(val) ?? 30
                case "counter":
                    counter = UInt64(val) ?? 0
                case "pin":
                    pin = val
                default:
                    break
                }
            }
        }

        guard !secret.isEmpty else { return nil }

        let type: OTPType
        switch typeStr {
        case "hotp": type = .hotp
        case "steam": type = .steam
        case "motp": type = .motp
        case "yaotp": type = .yaotp
        default: type = .totp
        }

        let info = OtpInfoModel(secret: secret, algo: algo, digits: digits, period: period, counter: counter, pin: pin)
        return VaultEntry(
            type: type,
            name: accountName,
            issuer: issuer,
            note: "",
            isFavorite: false,
            info: info
        )
    }
}
