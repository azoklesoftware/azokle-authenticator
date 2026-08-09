// src/crypto/aes-gcm.js

/**
 * AES-256-GCM encryption/decryption matching Android Azokle Auth format.
 */

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

/**
 * Import a raw 256-bit key into WebCrypto CryptoKey.
 * @param {Uint8Array} rawKeyBytes 
 * @returns {Promise<CryptoKey>}
 */
export async function importRawKey(rawKeyBytes) {
    return crypto.subtle.importKey(
        "raw",
        rawKeyBytes,
        { name: "AES-GCM", length: 256 },
        false,
        ["encrypt", "decrypt"]
    );
}

/**
 * Decrypts AES-256-GCM payload where ciphertext and tag are provided separately.
 * @param {Uint8Array} ciphertext 
 * @param {Uint8Array} nonce 12 bytes
 * @param {Uint8Array} tag 16 bytes
 * @param {Uint8Array|CryptoKey} key 
 * @returns {Promise<Uint8Array>} Decrypted bytes
 */
export async function decryptAesGcm(ciphertext, nonce, tag, key) {
    const cryptoKey = key instanceof CryptoKey ? key : await importRawKey(key);
    
    // Concatenate ciphertext and tag for WebCrypto
    const payload = new Uint8Array(ciphertext.length + tag.length);
    payload.set(ciphertext, 0);
    payload.set(tag, ciphertext.length);

    const decryptedBuffer = await crypto.subtle.decrypt(
        {
            name: "AES-GCM",
            iv: nonce,
            tagLength: 128
        },
        cryptoKey,
        payload
    );

    return new Uint8Array(decryptedBuffer);
}

/**
 * Encrypts data with AES-256-GCM.
 * @param {Uint8Array} plaintext 
 * @param {Uint8Array|CryptoKey} key 
 * @returns {Promise<{ciphertext: Uint8Array, nonce: Uint8Array, tag: Uint8Array}>}
 */
export async function encryptAesGcm(plaintext, key) {
    const cryptoKey = key instanceof CryptoKey ? key : await importRawKey(key);
    const nonce = crypto.getRandomValues(new Uint8Array(12));

    const resultBuffer = await crypto.subtle.encrypt(
        {
            name: "AES-GCM",
            iv: nonce,
            tagLength: 128
        },
        cryptoKey,
        plaintext
    );

    const result = new Uint8Array(resultBuffer);
    const ciphertext = result.slice(0, result.length - 16);
    const tag = result.slice(result.length - 16);

    return { ciphertext, nonce, tag };
}

/**
 * Helper to convert text to/from AES-GCM decryption
 */
export async function decryptAesGcmText(ciphertext, nonce, tag, key) {
    const bytes = await decryptAesGcm(ciphertext, nonce, tag, key);
    return textDecoder.decode(bytes);
}

export async function encryptAesGcmText(text, key) {
    const bytes = textEncoder.encode(text);
    return encryptAesGcm(bytes, key);
}
