//
//  MOTPEngine.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public final class MOTPEngine {

    public static func generateCode(secretHex: String, pin: String, timestamp: TimeInterval = Date().timeIntervalSince1970) -> String {
        let epoch10s = Int(floor(timestamp / 10.0))
        let payload = "\(epoch10s)\(secretHex)\(pin)"
        guard let data = payload.data(using: .utf8) else { return "000000" }

        let digest = Insecure.MD5.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(6))
    }

    public static func generateProgress(secretHex: String, pin: String, timestamp: TimeInterval = Date().timeIntervalSince1970) -> TOTPProgress {
        let code = generateCode(secretHex: secretHex, pin: pin, timestamp: timestamp)
        let period = 10
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
