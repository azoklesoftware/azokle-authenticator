// src/otp/hotp.js
import { decodeBase32 } from '../crypto/base32.js';

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
 * Generates an HOTP code.
 * @param {Uint8Array|string} secret Base32 string or Uint8Array
 * @param {number} counter 
 * @param {Object} [options]
 * @param {string} [options.algorithm='SHA1']
 * @param {number} [options.digits=6]
 * @returns {Promise<string>}
 */
export async function generateHOTP(secret, counter, options = {}) {
    const secretBytes = typeof secret === 'string' ? decodeBase32(secret) : secret;
    let hashName = 'SHA-1';
    const cleanAlgo = String(algorithm).toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (cleanAlgo.includes('256')) hashName = 'SHA-256';
    else if (cleanAlgo.includes('512')) hashName = 'SHA-512';

    const cryptoKey = await crypto.subtle.importKey(
        'raw',
        secretBytes,
        { name: 'HMAC', hash: { name: hashName } },
        false,
        ['sign']
    );

    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(counter), false);

    const signature = await crypto.subtle.sign('HMAC', cryptoKey, new Uint8Array(buffer));
    return truncate(new Uint8Array(signature), digits);
}
