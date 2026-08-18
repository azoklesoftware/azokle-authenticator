//
//  ExtendedImporters.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

// MARK: - andOTP Importer
public struct AndOtpImporter {
    public static func parse(data: Data, password: String? = nil) throws -> [VaultEntry] {
        var jsonData = data

        // Check if andOTP encrypted backup (starts with 12-byte IV or header)
        if let password = password, !password.isEmpty {
            jsonData = try decryptAndOtp(data: data, password: password)
        }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw ImporterError.unsupportedFormat
        }

        var entries: [VaultEntry] = []
        for obj in jsonArray {
            let secret = obj["secret"] as? String ?? ""
            let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
            guard !cleanSecret.isEmpty else { continue }

            let label = obj["label"] as? String ?? ""
            let issuer = obj["issuer"] as? String ?? ""
            let typeStr = (obj["type"] as? String ?? "TOTP").uppercased()
            let digits = obj["digits"] as? Int ?? 6
            let period = obj["period"] as? Int ?? 30
            let counter = UInt64(obj["counter"] as? Int ?? 0)
            let algoStr = (obj["algorithm"] as? String ?? "SHA1").uppercased()

            let algo: OTPAlgorithm
            if algoStr.contains("256") { algo = .sha256 }
            else if algoStr.contains("512") { algo = .sha512 }
            else { algo = .sha1 }

            let otpType: OTPType
            if typeStr == "HOTP" { otpType = .hotp }
            else if typeStr == "STEAM" { otpType = .steam }
            else if typeStr == "MOTP" { otpType = .motp }
            else { otpType = .totp }

            var accountName = label
            var parsedIssuer = issuer
            if parsedIssuer.isEmpty && label.contains(" - ") {
                let parts = label.components(separatedBy: " - ")
                parsedIssuer = parts[0].trimmingCharacters(in: .whitespaces)
                accountName = parts[1].trimmingCharacters(in: .whitespaces)
            } else if parsedIssuer.isEmpty && label.contains(":") {
                let parts = label.components(separatedBy: ":")
                parsedIssuer = parts[0].trimmingCharacters(in: .whitespaces)
                accountName = parts[1].trimmingCharacters(in: .whitespaces)
            }

            let info = OtpInfoModel(
                secret: cleanSecret,
                algo: algo,
                digits: digits,
                period: period,
                counter: counter
            )

            let entry = VaultEntry(
                type: otpType,
                name: accountName,
                issuer: parsedIssuer.isEmpty ? "andOTP Token" : parsedIssuer,
                info: info
            )
            entries.append(entry)
        }

        return entries
    }

    private static func decryptAndOtp(data: Data, password: String) throws -> Data {
        // andOTP uses 12-byte IV + AES-GCM ciphertext + 16-byte tag, or PBKDF2-derived key
        guard data.count > 28 else { throw ImporterError.unsupportedFormat }
        let iv = data.prefix(12)
        let tag = data.suffix(16)
        let ciphertext = data.dropFirst(12).dropLast(16)

        // Derive 256-bit key from password using PBKDF2-HMAC-SHA1 or SHA256 (andOTP standard iterations: 140000)
        let salt = iv // andOTP uses IV as salt
        let derivedKeyData = try SCrypt.pbkdf2HmacSha256(password: password.data(using: .utf8)!, salt: salt, iterations: 140000, keyLength: 32)
        let symmetricKey = SymmetricKey(data: derivedKeyData)

        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
}

// MARK: - Authy Importer
public struct AuthyImporter {
    public static func parse(data: Data) throws -> [VaultEntry] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ImporterError.unsupportedFormat
        }

        var entries: [VaultEntry] = []
        for obj in jsonArray {
            let secret = obj["decryptedSecret"] as? String ?? obj["secret"] as? String ?? ""
            let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
            guard !cleanSecret.isEmpty else { continue }

            let name = obj["name"] as? String ?? obj["account"] as? String ?? ""
            let issuer = obj["originalName"] as? String ?? obj["issuer"] as? String ?? obj["name"] as? String ?? "Authy"
            let digits = obj["digits"] as? Int ?? (obj["keyType"] as? String == "authy" ? 7 : 6)
            let period = obj["period"] as? Int ?? 30

            let info = OtpInfoModel(
                secret: cleanSecret,
                algo: .sha1,
                digits: digits,
                period: period
            )

            entries.append(VaultEntry(
                type: .totp,
                name: name,
                issuer: issuer,
                info: info
            ))
        }

        return entries
    }
}

// MARK: - Authenticator Pro Importer
public struct AuthenticatorProImporter {
    public static func parse(data: Data) throws -> [VaultEntry] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authenticators = root["authenticators"] as? [[String: Any]] else {
            throw ImporterError.unsupportedFormat
        }

        var entries: [VaultEntry] = []
        for obj in authenticators {
            let secret = obj["secret"] as? String ?? ""
            let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
            guard !cleanSecret.isEmpty else { continue }

            let issuer = obj["issuer"] as? String ?? ""
            let name = obj["username"] as? String ?? obj["account"] as? String ?? ""
            let digits = obj["digits"] as? Int ?? 6
            let period = obj["period"] as? Int ?? 30
            let counter = UInt64(obj["counter"] as? Int ?? 0)
            let algoStr = (obj["algorithm"] as? String ?? "SHA1").uppercased()
            let typeStr = (obj["type"] as? String ?? "TOTP").uppercased()

            let algo: OTPAlgorithm = algoStr.contains("256") ? .sha256 : (algoStr.contains("512") ? .sha512 : .sha1)
            let type: OTPType = (typeStr == "HOTP") ? .hotp : ((typeStr == "STEAM") ? .steam : .totp)

            let info = OtpInfoModel(
                secret: cleanSecret,
                algo: algo,
                digits: digits,
                period: period,
                counter: counter
            )

            entries.append(VaultEntry(
                type: type,
                name: name,
                issuer: issuer.isEmpty ? "Authenticator Pro" : issuer,
                info: info
            ))
        }

        return entries
    }
}

// MARK: - FreeOTP / FreeOTP+ Importer
public struct FreeOtpImporter {
    public static func parse(data: Data) throws -> [VaultEntry] {
        // 1. Try FreeOTP+ JSON format
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tokens = root["tokens"] as? [[String: Any]] {
            var entries: [VaultEntry] = []
            for item in tokens {
                guard let secret = item["secret"] as? String, !secret.isEmpty else { continue }
                let issuer = item["issuer"] as? String ?? ""
                let name = item["label"] as? String ?? ""
                let digits = item["digits"] as? Int ?? 6
                let period = item["period"] as? Int ?? 30
                let typeStr = (item["type"] as? String ?? "TOTP").uppercased()
                let algoStr = (item["algo"] as? String ?? "SHA1").uppercased()

                let algo: OTPAlgorithm = algoStr.contains("256") ? .sha256 : (algoStr.contains("512") ? .sha512 : .sha1)
                let type: OTPType = typeStr == "HOTP" ? .hotp : .totp

                let info = OtpInfoModel(
                    secret: secret,
                    algo: algo,
                    digits: digits,
                    period: period
                )
                entries.append(VaultEntry(type: type, name: name, issuer: issuer, info: info))
            }
            if !entries.isEmpty { return entries }
        }

        // 2. Try XML format (tokens.xml string containing <string name="...">...)
        if let xmlString = String(data: data, encoding: .utf8), xmlString.contains("<string") {
            var entries: [VaultEntry] = []
            let pattern = "<string name=\"([^\"]+)\">([^<]+)<\\/string>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = xmlString as NSString
                let matches = regex.matches(in: xmlString, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    guard match.numberOfRanges >= 3 else { continue }
                    let tokenJson = nsString.substring(with: match.range(at: 2))
                    if let tokenData = tokenJson.data(using: .utf8),
                       let tokenObj = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
                       let secretBytes = tokenObj["secret"] as? [Int] {
                        let secretData = Data(secretBytes.map { UInt8($0 & 0xFF) })
                        let secretB32 = Base32.encode(secretData)
                        let issuer = tokenObj["issuerInt"] as? String ?? tokenObj["issuerExt"] as? String ?? ""
                        let label = tokenObj["label"] as? String ?? ""
                        let digits = tokenObj["digits"] as? Int ?? 6
                        let period = tokenObj["period"] as? Int ?? 30

                        let info = OtpInfoModel(secret: secretB32, algo: .sha1, digits: digits, period: period)
                        entries.append(VaultEntry(type: .totp, name: label, issuer: issuer, info: info))
                    }
                }
            }
            if !entries.isEmpty { return entries }
        }

        throw ImporterError.unsupportedFormat
    }
}

// MARK: - WinAuth XML Importer
public struct WinAuthImporter {
    public static func parse(data: Data) throws -> [VaultEntry] {
        guard let xmlString = String(data: data, encoding: .utf8), xmlString.contains("<WinAuth") || xmlString.contains("<authenticator") else {
            throw ImporterError.unsupportedFormat
        }

        var entries: [VaultEntry] = []
        // Match <name>...</name> and <secretdata>...</secretdata> or <secret>...</secret>
        let secretPattern = "<secretdata>([A-Za-z0-9+/=]+)<\\/secretdata>|<secret>([A-Za-z0-9=]+)<\\/secret>"
        let namePattern = "<name>([^<]+)<\\/name>"

        if let secretRegex = try? NSRegularExpression(pattern: secretPattern),
           let nameRegex = try? NSRegularExpression(pattern: namePattern) {
            let ns = xmlString as NSString
            let secretMatches = secretRegex.matches(in: xmlString, range: NSRange(location: 0, length: ns.length))
            let nameMatches = nameRegex.matches(in: xmlString, range: NSRange(location: 0, length: ns.length))

            for i in 0..<min(secretMatches.count, nameMatches.count) {
                let name = ns.substring(with: nameMatches[i].range(at: 1))
                var secret = ""
                if secretMatches[i].range(at: 1).location != NSNotFound {
                    secret = ns.substring(with: secretMatches[i].range(at: 1))
                } else if secretMatches[i].range(at: 2).location != NSNotFound {
                    secret = ns.substring(with: secretMatches[i].range(at: 2))
                }

                if !secret.isEmpty {
                    let info = OtpInfoModel(secret: secret, algo: .sha1, digits: 6, period: 30)
                    entries.append(VaultEntry(type: .totp, name: name, issuer: name, info: info))
                }
            }
        }

        if entries.isEmpty { throw ImporterError.unsupportedFormat }
        return entries
    }
}
