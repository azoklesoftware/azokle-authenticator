//
//  TOTPEngine.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public struct TOTPProgress {
    public let code: String
    public let progress: Double // 0.0 to 1.0 remaining
    public let remainingSeconds: Int
    public let totalPeriod: Int

    public init(code: String, progress: Double, remainingSeconds: Int, totalPeriod: Int) {
        self.code = code
        self.progress = progress
        self.remainingSeconds = remainingSeconds
        self.totalPeriod = totalPeriod
    }
}

public final class TOTPEngine {

    public static func calculateCounter(timestamp: TimeInterval = Date().timeIntervalSince1970, period: Int = 30) -> UInt64 {
        return UInt64(floor(timestamp / Double(period)))
    }

    public static func generateCode(secret: Data, algorithm: OTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30, timestamp: TimeInterval = Date().timeIntervalSince1970) -> String {
        let counter = calculateCounter(timestamp: timestamp, period: period)
        return HOTPEngine.generateCode(secret: secret, algorithm: algorithm, counter: counter, digits: digits)
    }

    public static func generateProgress(secret: Data, algorithm: OTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30, timestamp: TimeInterval = Date().timeIntervalSince1970) -> TOTPProgress {
        let code = generateCode(secret: secret, algorithm: algorithm, digits: digits, period: period, timestamp: timestamp)
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
