// src/crypto.js
/**
 * Web Crypto API wrapper for 100% offline privacy-first extension.
 * This implements AES-256-GCM for vault encryption and decryption.
 */

// Helper to convert string to ArrayBuffer
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

/**
 * Derives an AES-GCM key from a master password.
 * @param {string} password 
 * @param {Uint8Array} salt 
 * @returns {Promise<CryptoKey>}
 */
export async function deriveKey(password, salt) {
    const keyMaterial = await crypto.subtle.importKey(
        "raw",
        textEncoder.encode(password),
        { name: "PBKDF2" },
        false,
        ["deriveBits", "deriveKey"]
    );
    
    return crypto.subtle.deriveKey(
        {
            name: "PBKDF2",
            salt: salt,
            iterations: 100000,
            hash: "SHA-256"
        },
        keyMaterial,
        { name: "AES-GCM", length: 256 },
        true,
        ["encrypt", "decrypt"]
    );
}

/**
 * Encrypts a string payload (JSON vault) using AES-256-GCM.
 * @param {string} plaintext 
 * @param {CryptoKey} key 
 * @returns {Promise<{ciphertext: string, iv: string}>} base64 encoded
 */
export async function encryptVault(plaintext, key) {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const encoded = textEncoder.encode(plaintext);
    
    const ciphertext = await crypto.subtle.encrypt(
        { name: "AES-GCM", iv: iv },
        key,
        encoded
    );
    
    return {
        ciphertext: btoa(String.fromCharCode(...new Uint8Array(ciphertext))),
        iv: btoa(String.fromCharCode(...iv))
    };
}

/**
 * Decrypts a vault string payload using AES-256-GCM.
 * @param {string} ciphertextBase64 
 * @param {string} ivBase64 
 * @param {CryptoKey} key 
 * @returns {Promise<string>}
 */
export async function decryptVault(ciphertextBase64, ivBase64, key) {
    const ciphertextBytes = Uint8Array.from(atob(ciphertextBase64), c => c.charCodeAt(0));
    const ivBytes = Uint8Array.from(atob(ivBase64), c => c.charCodeAt(0));
    
    const decrypted = await crypto.subtle.decrypt(
        { name: "AES-GCM", iv: ivBytes },
        key,
        ciphertextBytes
    );
    
    return textDecoder.decode(decrypted);
}
