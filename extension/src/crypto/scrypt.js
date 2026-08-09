// src/crypto/scrypt.js
import { scrypt } from 'scrypt-js';

const encoder = new TextEncoder();

/**
 * Derives a key using scrypt (matching Android Azokle Auth scrypt parameters).
 * @param {string|Uint8Array} password 
 * @param {Uint8Array} salt 
 * @param {number} N 
 * @param {number} r 
 * @param {number} p 
 * @param {number} keyLengthBytes Default 32 bytes (256-bit)
 * @returns {Promise<Uint8Array>}
 */
export async function deriveScryptKey(password, salt, N = 32768, r = 8, p = 1, keyLengthBytes = 32) {
    const passwordBytes = typeof password === 'string' ? encoder.encode(password) : password;
    
    // scrypt(password, salt, N, r, p, dkLen)
    const derivedKey = await scrypt(passwordBytes, salt, N, r, p, keyLengthBytes);
    return new Uint8Array(derivedKey);
}
