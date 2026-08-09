// src/otp/steam.js
import { decodeBase32 } from '../crypto/base32.js';

const STEAM_ALPHABET = "23456789BCDFGHJKMNPQRTVWXY";

/**
 * Generates Steam Guard 5-character OTP.
 * @param {Uint8Array|string} secret 
 * @param {number} [timeSeconds]
 * @returns {Promise<string>}
 */
export async function generateSteamOTP(secret, timeSeconds = Math.floor(Date.now() / 1000)) {
    const secretBytes = typeof secret === 'string' ? decodeBase32(secret) : secret;
    const period = 30;
    const counter = Math.floor(timeSeconds / period);

    const cryptoKey = await crypto.subtle.importKey(
        'raw',
        secretBytes,
        { name: 'HMAC', hash: { name: 'SHA-1' } },
        false,
        ['sign']
    );

    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(counter), false);

    const signature = new Uint8Array(await crypto.subtle.sign('HMAC', cryptoKey, new Uint8Array(buffer)));

    const offset = signature[signature.length - 1] & 0xf;
    let fullCode =
        ((signature[offset] & 0x7f) << 24) |
        ((signature[offset + 1] & 0xff) << 16) |
        ((signature[offset + 2] & 0xff) << 8) |
        (signature[offset + 3] & 0xff);

    let code = "";
    for (let i = 0; i < 5; i++) {
        code += STEAM_ALPHABET[fullCode % STEAM_ALPHABET.length];
        fullCode = Math.floor(fullCode / STEAM_ALPHABET.length);
    }

    return code;
}
