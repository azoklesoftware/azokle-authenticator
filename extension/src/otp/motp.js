// src/otp/motp.js
import { md5 } from '@noble/hashes/legacy.js';
import { encodeHex } from '../crypto/hex.js';
import { decodeBase32 } from '../crypto/base32.js';

const encoder = new TextEncoder();

/**
 * Generates an mOTP code.
 * @param {Uint8Array|string} secret 
 * @param {string} pin 4-digit PIN
 * @param {number} [timeSeconds]
 * @returns {string}
 */
export function generateMOTP(secret, pin, timeSeconds = Math.floor(Date.now() / 1000)) {
    if (!pin) {
        throw new Error("PIN required for mOTP code generation");
    }

    const secretBytes = typeof secret === 'string' ? decodeBase32(secret) : secret;
    const secretHex = encodeHex(secretBytes);
    const epochStep = Math.floor(timeSeconds / 10).toString();

    // mOTP input: epochStep + secretHex + pin
    const inputStr = epochStep + secretHex + pin;
    const hashBytes = md5(encoder.encode(inputStr));
    const hashHex = encodeHex(hashBytes);

    return hashHex.substring(0, 6);
}
