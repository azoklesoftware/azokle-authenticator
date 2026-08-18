//
//  SCrypt.swift
//  Azokle Auth
//
//  Created by Azokle.
//

import Foundation
import CryptoKit

public struct SCryptParameters: Codable, Equatable {
    public let n: Int
    public let r: Int
    public let p: Int
    public let salt: String

    public init(n: Int = 32768, r: Int = 8, p: Int = 1, salt: String) {
        self.n = n
        self.r = r
        self.p = p
        self.salt = salt
    }

    public init(n: Int = 32768, r: Int = 8, p: Int = 1, saltData: Data) {
        self.n = n
        self.r = r
        self.p = p
        self.salt = Hex.encode(saltData)
    }

    public var saltData: Data? {
        return Hex.decode(salt)
    }
}

public final class SCrypt {

    /// Derives a key using the scrypt algorithm (RFC 7914)
    public static func generate(password: Data, salt: Data, n: Int = 32768, r: Int = 8, p: Int = 1, dkLen: Int = 32) throws -> Data {
        guard n > 1 && (n & (n - 1)) == 0 else {
            throw CryptoError.invalidData
        }
        guard (UInt64(r) * UInt64(p)) < (1 << 30) else {
            throw CryptoError.invalidData
        }

        // 1. Initial PBKDF2 expansion: B_0 ... B_{p-1} = PBKDF2-HMAC-SHA256(P, S, 1, p * 128 * r)
        let blockSize = 128 * r
        var B = try pbkdf2HmacSha256(password: password, salt: salt, iterations: 1, keyLength: p * blockSize)

        // 2. ROMix for each chunk of size 128*r
        for i in 0..<p {
            let offset = i * blockSize
            let chunk = B.subdata(in: offset..<(offset + blockSize))
            let mixedChunk = roMix(block: chunk, n: n, r: r)
            B.replaceSubrange(offset..<(offset + blockSize), with: mixedChunk)
        }

        // 3. Final PBKDF2 expansion: PBKDF2-HMAC-SHA256(P, B, 1, dkLen)
        return try pbkdf2HmacSha256(password: password, salt: B, iterations: 1, keyLength: dkLen)
    }

    public static func generate(password: String, params: SCryptParameters, dkLen: Int = 32) throws -> Data {
        guard let saltData = params.saltData, let passData = password.data(using: .utf8) else {
            throw CryptoError.invalidData
        }
        return try generate(password: passData, salt: saltData, n: params.n, r: params.r, p: params.p, dkLen: dkLen)
    }

    // MARK: - PBKDF2-HMAC-SHA256
    public static func pbkdf2HmacSha256(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
        var derivedKey = Data()
        var blockIndex: UInt32 = 1
        let key = SymmetricKey(data: password)

        while derivedKey.count < keyLength {
            var saltBlock = salt
            var indexBigEndian = blockIndex.bigEndian
            withUnsafeBytes(of: &indexBigEndian) { saltBlock.append(contentsOf: $0) }

            var u = Data(HMAC<SHA256>.authenticationCode(for: saltBlock, using: key))
            var f = u

            if iterations > 1 {
                for _ in 1..<iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    for k in 0..<f.count {
                        f[k] ^= u[k]
                    }
                }
            }

            let needed = min(keyLength - derivedKey.count, f.count)
            derivedKey.append(f.prefix(needed))
            blockIndex += 1
        }

        return derivedKey
    }

    // MARK: - ROMix
    private static func roMix(block: Data, n: Int, r: Int) -> Data {
        let uint32Count = (128 * r) / 4
        var X = [UInt32](repeating: 0, count: uint32Count)
        block.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt32.self)
            for i in 0..<uint32Count {
                X[i] = UInt32(littleEndian: src[i])
            }
        }

        // Flat contiguous buffer for V table (n * uint32Count UInt32s)
        var V = [UInt32](repeating: 0, count: n * uint32Count)

        for i in 0..<n {
            let offset = i * uint32Count
            for k in 0..<uint32Count {
                V[offset + k] = X[k]
            }
            blockMix(X: &X, r: r)
        }

        let mask = n - 1
        for _ in 0..<n {
            // integerify(X)
            let j = Int(X[uint32Count - 16] & UInt32(mask))
            let offset = j * uint32Count
            for k in 0..<uint32Count {
                X[k] ^= V[offset + k]
            }
            blockMix(X: &X, r: r)
        }

        var result = Data(capacity: 128 * r)
        for i in 0..<uint32Count {
            var le = X[i].littleEndian
            withUnsafeBytes(of: &le) { result.append(contentsOf: $0) }
        }
        return result
    }

    // MARK: - BlockMix
    private static func blockMix(X: inout [UInt32], r: Int) {
        var Y = [UInt32](repeating: 0, count: 32 * r)
        var B = [UInt32](repeating: 0, count: 16)

        // B = X[2r - 1]
        let lastBlockOffset = (2 * r - 1) * 16
        for i in 0..<16 {
            B[i] = X[lastBlockOffset + i]
        }

        for i in 0..<(2 * r) {
            let offset = i * 16
            for k in 0..<16 {
                B[k] ^= X[offset + k]
            }
            salsa20_8(&B)

            let destOffset = (i % 2 == 0) ? (i / 2) * 16 : (r + (i - 1) / 2) * 16
            for k in 0..<16 {
                Y[destOffset + k] = B[k]
            }
        }

        X = Y
    }

    // MARK: - Salsa20/8 Core
    private static func salsa20_8(_ B: inout [UInt32]) {
        var x = B

        func rotl(_ val: UInt32, _ count: UInt32) -> UInt32 {
            return (val << count) | (val >> (32 - count))
        }

        for _ in 0..<4 {
            // Column rounds
            x[ 4] ^= rotl(x[ 0] &+ x[12],  7);  x[ 8] ^= rotl(x[ 4] &+ x[ 0],  9)
            x[12] ^= rotl(x[ 8] &+ x[ 4], 13);  x[ 0] ^= rotl(x[12] &+ x[ 8], 18)
            x[ 9] ^= rotl(x[ 5] &+ x[ 1],  7);  x[13] ^= rotl(x[ 9] &+ x[ 5],  9)
            x[ 1] ^= rotl(x[13] &+ x[ 9], 13);  x[ 5] ^= rotl(x[ 1] &+ x[13], 18)
            x[14] ^= rotl(x[10] &+ x[ 6],  7);  x[ 2] ^= rotl(x[14] &+ x[10],  9)
            x[ 6] ^= rotl(x[ 2] &+ x[14], 13);  x[10] ^= rotl(x[ 6] &+ x[ 2], 18)
            x[ 3] ^= rotl(x[15] &+ x[11],  7);  x[ 7] ^= rotl(x[ 3] &+ x[15],  9)
            x[11] ^= rotl(x[ 7] &+ x[ 3], 13);  x[15] ^= rotl(x[11] &+ x[ 7], 18)

            // Row rounds
            x[ 1] ^= rotl(x[ 0] &+ x[ 3],  7);  x[ 2] ^= rotl(x[ 1] &+ x[ 0],  9)
            x[ 3] ^= rotl(x[ 2] &+ x[ 1], 13);  x[ 0] ^= rotl(x[ 3] &+ x[ 2], 18)
            x[ 6] ^= rotl(x[ 5] &+ x[ 4],  7);  x[ 7] ^= rotl(x[ 6] &+ x[ 5],  9)
            x[ 4] ^= rotl(x[ 7] &+ x[ 6], 13);  x[ 5] ^= rotl(x[ 4] &+ x[ 7], 18)
            x[11] ^= rotl(x[10] &+ x[ 9],  7);  x[ 8] ^= rotl(x[11] &+ x[10],  9)
            x[ 9] ^= rotl(x[ 8] &+ x[11], 13);  x[10] ^= rotl(x[ 9] &+ x[ 8], 18)
            x[12] ^= rotl(x[15] &+ x[14],  7);  x[13] ^= rotl(x[12] &+ x[15],  9)
            x[14] ^= rotl(x[13] &+ x[12], 13);  x[15] ^= rotl(x[14] &+ x[13], 18)
        }

        for i in 0..<16 {
            B[i] = B[i] &+ x[i]
        }
    }
}
