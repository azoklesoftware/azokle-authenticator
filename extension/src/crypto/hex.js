// src/crypto/hex.js

/**
 * Converts a Uint8Array or ArrayBuffer to a hex string.
 * @param {Uint8Array|ArrayBuffer} buffer 
 * @returns {string}
 */
export function encodeHex(buffer) {
    const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
    let hex = '';
    for (let i = 0; i < bytes.length; i++) {
        hex += bytes[i].toString(16).padStart(2, '0');
    }
    return hex;
}

/**
 * Converts a hex string to a Uint8Array.
 * @param {string} hex 
 * @returns {Uint8Array}
 */
export function decodeHex(hex) {
    const cleanHex = hex.trim();
    if (cleanHex.length % 2 !== 0) {
        throw new Error("Invalid hex string length");
    }
    const array = new Uint8Array(cleanHex.length / 2);
    for (let i = 0; i < cleanHex.length; i += 2) {
        array[i / 2] = parseInt(cleanHex.substr(i, 2), 16);
    }
    return array;
}
