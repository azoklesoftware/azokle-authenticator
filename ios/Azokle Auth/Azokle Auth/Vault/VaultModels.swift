//
//  VaultModels.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

// MARK: - OTP Info Model
public struct OtpInfoModel: Codable, Equatable {
    public var secret: String // Hex or Base32
    public var algo: OTPAlgorithm
    public var digits: Int
    public var period: Int
    public var counter: UInt64
    public var pin: String?

    enum CodingKeys: String, CodingKey {
        case secret
        case algo
        case digits
        case period
        case counter
        case pin
    }

    public init(
        secret: String,
        algo: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: UInt64 = 0,
        pin: String? = nil
    ) {
        self.secret = secret
        self.algo = algo
        self.digits = digits
        self.period = period
        self.counter = counter
        self.pin = pin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.secret = try container.decodeIfPresent(String.self, forKey: .secret) ?? ""
        let algoString = try container.decodeIfPresent(String.self, forKey: .algo) ?? "SHA1"
        self.algo = OTPAlgorithm(rawValue: algoString.uppercased()) ?? .sha1
        self.digits = try container.decodeIfPresent(Int.self, forKey: .digits) ?? 6
        self.period = try container.decodeIfPresent(Int.self, forKey: .period) ?? 30
        self.counter = try container.decodeIfPresent(UInt64.self, forKey: .counter) ?? 0
        self.pin = try container.decodeIfPresent(String.self, forKey: .pin)
    }

    /// Converts raw secret to binary Data (attempts Base32 first, then Hex, then UTF-8)
    public var secretData: Data {
        if let b32Data = Base32.decode(secret), !b32Data.isEmpty {
            return b32Data
        }
        if let hexData = Hex.decode(secret), !hexData.isEmpty {
            return hexData
        }
        return secret.data(using: .utf8) ?? Data()
    }
}

// MARK: - Vault Entry
public struct VaultEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: OTPType
    public var name: String
    public var issuer: String
    public var note: String
    public var isFavorite: Bool
    public var icon: String?
    public var info: OtpInfoModel
    public var groups: Set<UUID>
    public var usageCount: Int
    public var lastUsedTimestamp: Int64

    enum CodingKeys: String, CodingKey {
        case id = "uuid"
        case type
        case name
        case issuer
        case note
        case isFavorite = "favorite"
        case icon
        case info
        case groups
        case usageCount = "usage_count"
        case lastUsedTimestamp = "last_used_timestamp"
    }

    public init(
        id: UUID = UUID(),
        type: OTPType = .totp,
        name: String,
        issuer: String,
        note: String = "",
        isFavorite: Bool = false,
        icon: String? = nil,
        info: OtpInfoModel,
        groups: Set<UUID> = [],
        usageCount: Int = 0,
        lastUsedTimestamp: Int64 = 0
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.issuer = issuer
        self.note = note
        self.isFavorite = isFavorite
        self.icon = icon
        self.info = info
        self.groups = groups
        self.usageCount = usageCount
        self.lastUsedTimestamp = lastUsedTimestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.id = UUID(uuidString: idString) ?? UUID()
        let typeString = try container.decodeIfPresent(String.self, forKey: .type) ?? "totp"
        self.type = OTPType(rawValue: typeString.lowercased()) ?? .totp
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.issuer = try container.decodeIfPresent(String.self, forKey: .issuer) ?? ""
        self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.info = try container.decode(OtpInfoModel.self, forKey: .info)

        if let groupStrings = try container.decodeIfPresent([String].self, forKey: .groups) {
            self.groups = Set(groupStrings.compactMap { UUID(uuidString: $0) })
        } else {
            self.groups = []
        }

        self.usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        self.lastUsedTimestamp = try container.decodeIfPresent(Int64.self, forKey: .lastUsedTimestamp) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(issuer, forKey: .issuer)
        try container.encode(note, forKey: .note)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(info, forKey: .info)
        let groupStrings = groups.map { $0.uuidString }
        try container.encode(groupStrings, forKey: .groups)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(lastUsedTimestamp, forKey: .lastUsedTimestamp)
    }

    /// Generates formatted OTP token and live progress
    public func currentProgress(timestamp: TimeInterval = Date().timeIntervalSince1970) -> TOTPProgress {
        switch type {
        case .totp:
            return TOTPEngine.generateProgress(
                secret: info.secretData,
                algorithm: info.algo,
                digits: info.digits,
                period: info.period,
                timestamp: timestamp
            )
        case .hotp:
            let code = HOTPEngine.generateCode(
                secret: info.secretData,
                algorithm: info.algo,
                counter: info.counter,
                digits: info.digits
            )
            return TOTPProgress(code: code, progress: 1.0, remainingSeconds: 0, totalPeriod: 0)
        case .steam:
            return SteamEngine.generateProgress(secret: info.secretData, timestamp: timestamp)
        case .motp:
            let hexSecret = Hex.encode(info.secretData)
            return MOTPEngine.generateProgress(secretHex: hexSecret, pin: info.pin ?? "", timestamp: timestamp)
        case .yaotp:
            return YAOTPEngine.generateProgress(
                secret: info.secretData,
                pin: info.pin ?? "",
                digits: info.digits,
                period: info.period,
                timestamp: timestamp
            )
        }
    }
}

// MARK: - Vault Group
public struct VaultGroup: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String

    enum CodingKeys: String, CodingKey {
        case id = "uuid"
        case name
    }

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.id = UUID(uuidString: idString) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

// MARK: - Internal Vault Database Container
public struct VaultDatabase: Codable {
    public var version: Int = 1
    public var entries: [VaultEntry]
    public var groups: [VaultGroup]

    public init(version: Int = 1, entries: [VaultEntry] = [], groups: [VaultGroup] = []) {
        self.version = version
        self.entries = entries
        self.groups = groups
    }
}
