//
//  OTPType.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public enum OTPType: String, Codable, CaseIterable, Identifiable {
    case totp = "totp"
    case hotp = "hotp"
    case steam = "steam"
    case motp = "motp"
    case yaotp = "yaotp"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .totp: return "TOTP (Time-based)"
        case .hotp: return "HOTP (Counter-based)"
        case .steam: return "Steam Guard"
        case .motp: return "mOTP (Mobile PIN)"
        case .yaotp: return "Yandex OTP"
        }
    }
}

public enum OTPAlgorithm: String, Codable, CaseIterable, Identifiable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
    case md5 = "MD5"

    public var id: String { rawValue }
}
