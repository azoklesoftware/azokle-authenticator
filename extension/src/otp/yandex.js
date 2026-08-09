// src/otp/yandex.js
import { decodeBase32 } from '../crypto/base32.js';

const encoder = new TextEncoder();

/**
 * Generates Yandex OTP code.
 * @param {Uint8Array|string} secret 
 * @param {string} pin 
 * @param {number} [timeSeconds]
 * @returns {Promise<string>}
 */
export async function generateYandexOTP(secret, pin, timeSeconds = Math.floor(Date.now() / 1000)) {
    if (!pin) {
        throw new Error("PIN required for Yandex OTP generation");
    }

    let secretBytes = typeof secret === 'string' ? decodeBase32(secret) : secret;
    if (secretBytes.length > 16) {
        secretBytes = secretBytes.slice(0, 16);
    }

    // Combine pin + secretBytes for key
    const pinBytes = encoder.encode(pin);
    const combinedKeyBytes = new Uint8Array(pinBytes.length + secretBytes.length);
    combinedKeyBytes.set(pinBytes, 0);
    combinedKeyBytes.set(secretBytes, pinBytes.length);

    const counter = Math.floor(timeSeconds / 30);
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(counter), false);

    const cryptoKey = await crypto.subtle.importKey(
        'raw',
        combinedKeyBytes,
        { name: 'HMAC', hash: { name: 'SHA-256' } },
        false,
        ['sign']
    );

    const signature = new Uint8Array(await crypto.subtle.sign('HMAC', cryptoKey, new Uint8Array(buffer)));

    const offset = signature[signature.length - 1] & 0xf;
    const binary =
        ((signature[offset] & 0x7f) << 24) |
        ((signature[offset + 1] & 0xff) << 16) |
        ((signature[offset + 2] & 0xff) << 8) |
        (signature[offset + 3] & 0xff);

    const otp = binary % 100000000;
    return otp.toString().padStart(8, '0');
}
