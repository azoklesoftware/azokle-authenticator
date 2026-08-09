// src/crypto/base32.js

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

/**
 * Decodes a Base32 string to Uint8Array.
 * @param {string} base32 
 * @returns {Uint8Array}
 */
export function decodeBase32(base32) {
    const cleaned = base32.toUpperCase().replace(/=+$/, '').replace(/\s+/g, '');
    let bits = 0;
    let value = 0;
    const output = [];

    for (let i = 0; i < cleaned.length; i++) {
        const index = ALPHABET.indexOf(cleaned[i]);
        if (index === -1) {
            throw new Error(`Invalid Base32 character: ${cleaned[i]}`);
        }
        value = (value << 5) | index;
        bits += 5;

        if (bits >= 8) {
            output.push((value >>> (bits - 8)) & 0xFF);
            bits -= 8;
        }
    }

    return new Uint8Array(output);
}

/**
 * Encodes Uint8Array to Base32 string.
 * @param {Uint8Array} bytes 
 * @returns {string}
 */
export function encodeBase32(bytes) {
    let bits = 0;
    let value = 0;
    let output = '';

    for (let i = 0; i < bytes.length; i++) {
        value = (value << 8) | bytes[i];
        bits += 8;

        while (bits >= 5) {
            output += ALPHABET[(value >>> (bits - 5)) & 31];
            bits -= 5;
        }
    }

    if (bits > 0) {
        output += ALPHABET[(value << (5 - bits)) & 31];
    }

    return output;
}
