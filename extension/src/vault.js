// src/vault.js
import { decryptVault } from './crypto.js';

/**
 * Parses an Azokle Auth vault file (which is a JSON containing the ciphertext and iv).
 * @param {string} fileContent The content of the .azokle backup file
 * @param {CryptoKey} key The derived AES-GCM key
 * @returns {Promise<Array<Object>>} The array of OTP entries
 */
export async function parseAzokleVault(fileContent, key) {
    try {
        const payload = JSON.parse(fileContent);
        
        if (!payload.ciphertext || !payload.iv) {
            throw new Error("Invalid vault format. Missing ciphertext or iv.");
        }
        
        const decryptedJson = await decryptVault(payload.ciphertext, payload.iv, key);
        return JSON.parse(decryptedJson);
    } catch (e) {
        console.error("Failed to parse or decrypt vault", e);
        throw e;
    }
}
