// src/otp/totp.js
import { decodeBase32 } from '../crypto/base32.js';

/**
 * Dynamic truncation per RFC 4226 / RFC 6238
 */
function truncate(hmacBytes, digits) {
    const offset = hmacBytes[hmacBytes.length - 1] & 0xf;
    const binary =
        ((hmacBytes[offset] & 0x7f) << 24) |
        ((hmacBytes[offset + 1] & 0xff) << 16) |
        ((hmacBytes[offset + 2] & 0xff) << 8) |
        (hmacBytes[offset + 3] & 0xff);

    const otp = binary % Math.pow(10, digits);
    return otp.toString().padStart(digits, '0');
}

/**
 * Calculates HMAC using Web Crypto API.
 * @param {Uint8Array} secret 
 * @param {Uint8Array} counterBytes 
 * @param {string} algo SHA-1, SHA-256, SHA-512
 * @returns {Promise<Uint8Array>}
 */
async function calculateHmac(secret, counterBytes, algo = 'SHA-1') {
    let hashName = 'SHA-1';
    const cleanAlgo = String(algo).toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (cleanAlgo.includes('256')) hashName = 'SHA-256';
    else if (cleanAlgo.includes('512')) hashName = 'SHA-512';

    const cryptoKey = await crypto.subtle.importKey(
        'raw',
        secret,
        { name: 'HMAC', hash: { name: hashName } },
        false,
        ['sign']
    );

    const signature = await crypto.subtle.sign('HMAC', cryptoKey, counterBytes);
    return new Uint8Array(signature);
}

/**
 * Generates a TOTP code.
 * @param {Uint8Array|string} secret Base32 string or Uint8Array
 * @param {Object} [options]
 * @param {string} [options.algorithm='SHA1'] SHA1, SHA256, SHA512
 * @param {number} [options.digits=6]
 * @param {number} [options.period=30]
 * @param {number} [options.timeSeconds=Date.now()/1000]
 * @returns {Promise<string>}
 */
export async function generateTOTP(secret, options = {}) {
    const secretBytes = typeof secret === 'string' ? decodeBase32(secret) : secret;
    const algorithm = (options.algorithm || 'SHA1').toUpperCase();
    const digits = options.digits || 6;
    const period = options.period || 30;
    const timeSeconds = options.timeSeconds || Math.floor(Date.now() / 1000);

    const counter = Math.floor(timeSeconds / period);
    
    // Convert counter to 8-byte big-endian buffer
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(counter), false);

    const hmac = await calculateHmac(secretBytes, new Uint8Array(buffer), algorithm);
    return truncate(hmac, digits);
}
