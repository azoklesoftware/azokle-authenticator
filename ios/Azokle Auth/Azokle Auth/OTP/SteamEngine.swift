//
//  SteamEngine.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public final class SteamEngine {
    private static let steamChars = Array("23456789BCDFGHJKMNPQRTVWXY")

    public static func generateCode(secret: Data, timestamp: TimeInterval = Date().timeIntervalSince1970) -> String {
        guard !secret.isEmpty else { return "00000" }

        let counter = TOTPEngine.calculateCounter(timestamp: timestamp, period: 30)
        let hash = HOTPEngine.generateHash(secret: secret, algorithm: .sha1, counter: counter)
        guard hash.count >= 4 else { return "00000" }

        let offset = Int(hash[hash.count - 1] & 0x0F)
        guard offset + 4 <= hash.count else { return "00000" }

        let p0 = UInt32(hash[offset] & 0x7F) << 24
        let p1 = UInt32(hash[offset + 1] & 0xFF) << 16
        let p2 = UInt32(hash[offset + 2] & 0xFF) << 8
        let p3 = UInt32(hash[offset + 3] & 0xFF)
        var fullCode = p0 | p1 | p2 | p3

        var steamCode = ""
        let charCount = UInt32(steamChars.count)

        for _ in 0..<5 {
            let charIndex = Int(fullCode % charCount)
            steamCode.append(steamChars[charIndex])
            fullCode /= charCount
        }

        return steamCode
    }

    public static func generateProgress(secret: Data, timestamp: TimeInterval = Date().timeIntervalSince1970) -> TOTPProgress {
        let code = generateCode(secret: secret, timestamp: timestamp)
        let period = 30
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
