//
//  HOTPEngine.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public final class HOTPEngine {

    public static func generateHash(secret: Data, algorithm: OTPAlgorithm, counter: UInt64) -> Data {
        var counterBigEndian = counter.bigEndian
        var counterData = Data()
        withUnsafeBytes(of: &counterBigEndian) { counterData.append(contentsOf: $0) }

        let key = SymmetricKey(data: secret)

        switch algorithm {
        case .sha1:
            return Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
        case .sha256:
            return Data(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            return Data(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        case .md5:
            return Data(HMAC<Insecure.MD5>.authenticationCode(for: counterData, using: key))
        }
    }

    public static func generateCode(secret: Data, algorithm: OTPAlgorithm = .sha1, counter: UInt64, digits: Int = 6) -> String {
        guard !secret.isEmpty else { return String(repeating: "0", count: digits) }

        let hash = generateHash(secret: secret, algorithm: algorithm, counter: counter)
        guard hash.count >= 4 else { return String(repeating: "0", count: digits) }

        let offset = Int(hash[hash.count - 1] & 0x0F)
        guard offset + 4 <= hash.count else { return String(repeating: "0", count: digits) }

        let p0 = UInt32(hash[offset] & 0x7F) << 24
        let p1 = UInt32(hash[offset + 1] & 0xFF) << 16
        let p2 = UInt32(hash[offset + 2] & 0xFF) << 8
        let p3 = UInt32(hash[offset + 3] & 0xFF)
        let binaryCode = p0 | p1 | p2 | p3

        let modulus = UInt32(pow(10.0, Double(digits)))
        let code = binaryCode % modulus
        return String(format: "%0*u", digits, code)
    }
}
