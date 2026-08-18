//
//  Encoding.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation

public enum EncodingError: Error {
    case invalidBase32
    case invalidHex
    case invalidBase64
}

// MARK: - Hex Encoding / Decoding
public struct Hex {
    public static func encode(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    public static func decode(_ string: String) -> Data? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count % 2 == 0 else { return nil }

        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let nextIndex = clean.index(index, offsetBy: 2)
            let byteString = clean[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

// MARK: - Base32 Encoding / Decoding (RFC 4648)
public struct Base32 {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    private static let decodeMap: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (i, char) in alphabet.enumerated() {
            map[char] = UInt8(i)
            // also support lowercase
            map[Character(char.lowercased())] = UInt8(i)
        }
        // Aliases commonly found in standard TOTP inputs: 0 -> O, 1 -> L or I, 8 -> B
        map["0"] = map["O"]
        map["1"] = map["L"]
        map["8"] = map["B"]
        return map
    }()

    public static func decode(_ string: String) -> Data? {
        let clean = string
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
            .uppercased()

        guard !clean.isEmpty else { return Data() }

        var buffer: UInt32 = 0
        var bitsLeft: Int = 0
        var output = Data()

        for char in clean {
            guard let val = decodeMap[char] else {
                return nil
            }

            buffer = (buffer << 5) | UInt32(val)
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xFF)
                output.append(byte)
            }
        }

        return output
    }

    public static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }

        var output = ""
        var buffer: UInt32 = 0
        var bitsLeft: Int = 0

        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitsLeft += 8

            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = Int((buffer >> bitsLeft) & 0x1F)
                let charIndex = alphabet.index(alphabet.startIndex, offsetBy: index)
                output.append(alphabet[charIndex])
            }
        }

        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            let charIndex = alphabet.index(alphabet.startIndex, offsetBy: index)
            output.append(alphabet[charIndex])
        }

        return output
    }
}
