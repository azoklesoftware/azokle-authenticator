//
//  YAOTPEngine.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public final class YAOTPEngine {
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    public static func generateCode(secret: Data, pin: String, digits: Int = 8, period: Int = 30, timestamp: TimeInterval = Date().timeIntervalSince1970) -> String {
        guard let pinBytes = pin.data(using: .utf8) else { return String(repeating: "a", count: digits) }

        var pinWithSecret = pinBytes
        pinWithSecret.append(secret)

        var keyHash = Data(SHA256.hash(data: pinWithSecret))
        if keyHash.first == 0 {
            keyHash = keyHash.dropFirst()
        }

        let counter = UInt64(floor(timestamp / Double(period)))
        let periodHash = HOTPEngine.generateHash(secret: keyHash, algorithm: .sha256, counter: counter)
        guard periodHash.count >= 8 else { return String(repeating: "a", count: digits) }

        let offset = Int(periodHash[periodHash.count - 1] & 0x0F)
        guard offset + 8 <= periodHash.count else { return String(repeating: "a", count: digits) }

        var sub = periodHash.subdata(in: offset..<(offset + 8))
        sub[0] &= 0x7F

        var otpValue: UInt64 = 0
        for b in sub {
            otpValue = (otpValue << 8) | UInt64(b)
        }

        let alphabetLen = UInt64(alphabet.count)
        let modulus = UInt64(pow(Double(alphabetLen), Double(digits)))
        var codeNumber = otpValue % modulus

        var chars = [Character](repeating: "a", count: digits)
        for i in stride(from: digits - 1, through: 0, by: -1) {
            let charIndex = Int(codeNumber % alphabetLen)
            chars[i] = alphabet[charIndex]
            codeNumber /= alphabetLen
        }

        return String(chars)
    }

    public static func generateProgress(secret: Data, pin: String, digits: Int = 8, period: Int = 30, timestamp: TimeInterval = Date().timeIntervalSince1970) -> TOTPProgress {
        let code = generateCode(secret: secret, pin: pin, digits: digits, period: period, timestamp: timestamp)
        let elapsed = timestamp.truncatingRemainder(dividingBy: Double(period))
        let remaining = Double(period) - elapsed
        let progress = remaining / Double(period)
        let remainingSeconds = Int(ceil(remaining))

        return TOTPProgress(
            code: code,
            progress: max(0.0, min(1.0, progress)),
            remainingSeconds: remainingSeconds,
            totalPeriod: period
        )
    }
}
