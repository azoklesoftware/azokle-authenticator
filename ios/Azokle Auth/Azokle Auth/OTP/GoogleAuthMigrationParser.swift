//
//  GoogleAuthMigrationParser.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public struct GoogleMigrationEntry {
    public let secret: Data
    public let name: String
    public let issuer: String
    public let algorithm: OTPAlgorithm
    public let digits: Int
    public let type: OTPType
    public let counter: UInt64
}

public struct GoogleMigrationPayload {
    public let entries: [GoogleMigrationEntry]
    public let version: Int
    public let batchSize: Int
    public let batchIndex: Int
    public let batchId: Int
}

public final class GoogleAuthMigrationParser {

    /// Parses an `otpauth-migration://offline?data=...` URL
    public static func parse(url: URL) -> GoogleMigrationPayload? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "otpauth-migration",
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" })?.value
        else {
            return nil
        }

        var base64 = dataItem
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: " ", with: "+")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let rawData = Data(base64Encoded: base64) else {
            return nil
        }

        return decodeMigrationPayload(data: rawData)
    }

    private static func decodeMigrationPayload(data: Data) -> GoogleMigrationPayload? {
        var reader = ProtoReader(data: data)
        var entries: [GoogleMigrationEntry] = []
        var version = 1
        var batchSize = 1
        var batchIndex = 0
        var batchId = 0

        while !reader.isAtEnd {
            guard let (fieldNumber, wireType) = reader.readTag() else { break }
            switch (fieldNumber, wireType) {
            case (1, 2): // repeated OtpParameters otp_parameters = 1;
                if let subData = reader.readLengthDelimited(),
                   let entry = decodeOtpParameters(data: subData) {
                    entries.append(entry)
                }
            case (2, 0): // int32 version = 2;
                version = Int(reader.readVarint() ?? 1)
            case (3, 0): // int32 batch_size = 3;
                batchSize = Int(reader.readVarint() ?? 1)
            case (4, 0): // int32 batch_index = 4;
                batchIndex = Int(reader.readVarint() ?? 0)
            case (5, 0): // int32 batch_id = 5;
                batchId = Int(reader.readVarint() ?? 0)
            default:
                reader.skip(wireType: wireType)
            }
        }

        return GoogleMigrationPayload(
            entries: entries,
            version: version,
            batchSize: batchSize,
            batchIndex: batchIndex,
            batchId: batchId
        )
    }

    private static func decodeOtpParameters(data: Data) -> GoogleMigrationEntry? {
        var reader = ProtoReader(data: data)
        var secret = Data()
        var name = ""
        var issuer = ""
        var algorithm: OTPAlgorithm = .sha1
        var digits = 6
        var type: OTPType = .totp
        var counter: UInt64 = 0

        while !reader.isAtEnd {
            guard let (fieldNumber, wireType) = reader.readTag() else { break }
            switch (fieldNumber, wireType) {
            case (1, 2): // bytes secret = 1;
                secret = reader.readLengthDelimited() ?? Data()
            case (2, 2): // string name = 2;
                name = reader.readString() ?? ""
            case (3, 2): // string issuer = 3;
                issuer = reader.readString() ?? ""
            case (4, 0): // Algorithm algorithm = 4;
                let algoVal = reader.readVarint() ?? 1
                switch algoVal {
                case 1: algorithm = .sha1
                case 2: algorithm = .sha256
                case 3: algorithm = .sha512
                case 4: algorithm = .md5
                default: algorithm = .sha1
                }
            case (5, 0): // DigitCount digits = 5;
                let digitVal = reader.readVarint() ?? 1
                digits = (digitVal == 2) ? 8 : 6
            case (6, 0): // OtpType type = 6;
                let typeVal = reader.readVarint() ?? 2
                type = (typeVal == 1) ? .hotp : .totp
            case (7, 0): // int64 counter = 7;
                counter = reader.readVarint() ?? 0
            default:
                reader.skip(wireType: wireType)
            }
        }

        // If issuer is empty, check if name contains format "Issuer:Account"
        if issuer.isEmpty && name.contains(":") {
            let parts = name.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                issuer = parts[0].trimmingCharacters(in: .whitespaces)
                name = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        return GoogleMigrationEntry(
            secret: secret,
            name: name,
            issuer: issuer,
            algorithm: algorithm,
            digits: digits,
            type: type,
            counter: counter
        )
    }

    /// Encodes a list of VaultEntry objects into an `otpauth-migration://offline?data=...` URL string
    public static func encodePayload(entries: [VaultEntry], batchIndex: Int = 0, batchSize: Int = 1, batchId: Int = 1) -> String? {
        var writer = ProtoWriter()

        for entry in entries {
            var entryWriter = ProtoWriter()

            // 1. secret (bytes)
            entryWriter.writeBytes(fieldNumber: 1, value: entry.info.secretData)

            // 2. name (string)
            entryWriter.writeString(fieldNumber: 2, value: entry.name)

            // 3. issuer (string)
            entryWriter.writeString(fieldNumber: 3, value: entry.issuer)

            // 4. algorithm
            let algoVal: UInt64
            switch entry.info.algo {
            case .sha1: algoVal = 1
            case .sha256: algoVal = 2
            case .sha512: algoVal = 3
            case .md5: algoVal = 4
            }
            entryWriter.writeVarint(fieldNumber: 4, value: algoVal)

            // 5. digits
            let digitsVal: UInt64 = (entry.info.digits == 8) ? 2 : 1
            entryWriter.writeVarint(fieldNumber: 5, value: digitsVal)

            // 6. type
            let typeVal: UInt64 = (entry.type == .hotp) ? 1 : 2
            entryWriter.writeVarint(fieldNumber: 6, value: typeVal)

            // 7. counter
            if entry.type == .hotp {
                entryWriter.writeVarint(fieldNumber: 7, value: entry.info.counter)
            }

            writer.writeBytes(fieldNumber: 1, value: entryWriter.data)
        }

        // version = 1
        writer.writeVarint(fieldNumber: 2, value: 1)
        // batch_size
        writer.writeVarint(fieldNumber: 3, value: UInt64(batchSize))
        // batch_index
        writer.writeVarint(fieldNumber: 4, value: UInt64(batchIndex))
        // batch_id
        writer.writeVarint(fieldNumber: 5, value: UInt64(batchId))

        let base64 = writer.data.base64EncodedString()
        guard let encodedData = base64.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) else {
            return nil
        }

        return "otpauth-migration://offline?data=\(encodedData)"
    }

    public static func parse(url: String) throws -> [VaultEntry] {
        guard let parsedUrl = URL(string: url), let payload = parse(url: parsedUrl) else {
            throw ImporterError.unsupportedFormat
        }

        return payload.entries.map { e in
            let secretB32 = Base32.encode(e.secret)
            let info = OtpInfoModel(secret: secretB32, algo: e.algorithm, digits: e.digits, period: 30, counter: e.counter)
            return VaultEntry(type: e.type, name: e.name, issuer: e.issuer, info: info)
        }
    }
}

// MARK: - Lightweight Protobuf Binary Wire Writer
private struct ProtoWriter {
    var data = Data()

    mutating func writeVarint(fieldNumber: Int, value: UInt64) {
        writeTag(fieldNumber: fieldNumber, wireType: 0)
        var val = value
        while val >= 0x80 {
            data.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        data.append(UInt8(val & 0x7F))
    }

    mutating func writeBytes(fieldNumber: Int, value: Data) {
        writeTag(fieldNumber: fieldNumber, wireType: 2)
        writeRawVarint(UInt64(value.count))
        data.append(value)
    }

    mutating func writeString(fieldNumber: Int, value: String) {
        guard let strData = value.data(using: .utf8) else { return }
        writeBytes(fieldNumber: fieldNumber, value: strData)
    }

    private mutating func writeTag(fieldNumber: Int, wireType: Int) {
        let tag = UInt64((fieldNumber << 3) | wireType)
        writeRawVarint(tag)
    }

    private mutating func writeRawVarint(_ value: UInt64) {
        var val = value
        while val >= 0x80 {
            data.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        data.append(UInt8(val & 0x7F))
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "+&=")
        return cs
    }()
}

// MARK: - Lightweight Protobuf Binary Wire Reader
private struct ProtoReader {
    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    var isAtEnd: Bool {
        return offset >= data.count
    }

    mutating func readTag() -> (fieldNumber: Int, wireType: Int)? {
        guard let varint = readVarint() else { return nil }
        let wireType = Int(varint & 0x07)
        let fieldNumber = Int(varint >> 3)
        return (fieldNumber, wireType)
    }

    mutating func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if (byte & 0x80) == 0 {
                return result
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    mutating func readLengthDelimited() -> Data? {
        guard let length = readVarint() else { return nil }
        let len = Int(length)
        guard offset + len <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + len))
        offset += len
        return sub
    }

    mutating func readString() -> String? {
        guard let bytes = readLengthDelimited() else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    mutating func skip(wireType: Int) {
        switch wireType {
        case 0: // Varint
            _ = readVarint()
        case 1: // 64-bit
            offset += 8
        case 2: // Length-delimited
            if let len = readVarint() {
                offset += Int(len)
            }
        case 5: // 32-bit
            offset += 4
        default:
            break
        }
    }
}
