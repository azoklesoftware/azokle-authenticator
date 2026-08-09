// src/vault/decryptor.js
import { decodeHex } from '../crypto/hex.js';
import { deriveScryptKey } from '../crypto/scrypt.js';
import { decryptAesGcm, decryptAesGcmText } from '../crypto/aes-gcm.js';

/**
 * Recovers the 256-bit Master Key from an encrypted Azokle Auth vault using a user password.
 * Tries all available PasswordSlots (primary and backup passwords).
 * 
 * @param {Object} vaultJson Parsed VaultFile object (version, header, db)
 * @param {string} password Master password entered by user
 * @returns {Promise<{masterKey: Uint8Array, slotUuid: string}>}
 */
export async function recoverMasterKey(vaultJson, password) {
    if (!vaultJson.header || !vaultJson.header.slots || vaultJson.header.slots.length === 0) {
        throw new Error("Vault is not encrypted or has no credential slots.");
    }

    // Filter all Password slots (type === 1)
    const passwordSlots = vaultJson.header.slots.filter(slot => slot.type === 1);
    if (passwordSlots.length === 0) {
        throw new Error("Vault does not contain a password credential slot.");
    }

    let lastError = null;

    // Try each password slot (Primary, Backup, Repaired)
    for (const passwordSlot of passwordSlots) {
        try {
            const n = passwordSlot.n || 32768;
            const r = passwordSlot.r || 8;
            const p = passwordSlot.p || 1;
            const saltBytes = decodeHex(passwordSlot.salt);
            const encryptedKeyBytes = decodeHex(passwordSlot.key);
            const nonceBytes = decodeHex(passwordSlot.key_params.nonce);
            const tagBytes = decodeHex(passwordSlot.key_params.tag);

            // Derive wrapper key via scrypt
            const wrapperKeyBytes = await deriveScryptKey(password, saltBytes, n, r, p, 32);

            // Decrypt master key
            const masterKeyBytes = await decryptAesGcm(encryptedKeyBytes, nonceBytes, tagBytes, wrapperKeyBytes);
            return {
                masterKey: masterKeyBytes,
                slotUuid: passwordSlot.uuid
            };
        } catch (err) {
            lastError = err;
        }
    }

    throw new Error("Invalid password or corrupted vault slot.");
}

/**
 * Decrypts the vault content (db) using the recovered master key.
 * @param {Object} vaultJson 
 * @param {Uint8Array} masterKey 
 * @returns {Promise<Object>} Decrypted content object { version, entries, groups }
 */
export async function decryptVaultDb(vaultJson, masterKey) {
    if (typeof vaultJson.db === 'object') {
        // Plaintext vault
        return vaultJson.db;
    }

    if (typeof vaultJson.db !== 'string') {
        throw new Error("Invalid vault database content format.");
    }

    const dbCiphertextBytes = Uint8Array.from(atob(vaultJson.db), c => c.charCodeAt(0));
    const nonceBytes = decodeHex(vaultJson.header.params.nonce);
    const tagBytes = decodeHex(vaultJson.header.params.tag);

    const decryptedJsonText = await decryptAesGcmText(dbCiphertextBytes, nonceBytes, tagBytes, masterKey);
    return JSON.parse(decryptedJsonText);
}
