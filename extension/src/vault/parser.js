// src/vault/parser.js
import { recoverMasterKey, decryptVaultDb } from './decryptor.js';

/**
 * Parses and decrypts an Azokle Auth vault file.
 * Handles both encrypted (.azokle) and plaintext vaults.
 * 
 * @param {string} fileContent Raw JSON string of the vault file
 * @param {string} [password] Required if vault is encrypted
 * @returns {Promise<{content: Object, masterKey: Uint8Array|null, isEncrypted: boolean}>}
 */
export async function parseAndDecryptVault(fileContent, password = "") {
    let vaultJson;
    try {
        vaultJson = JSON.parse(fileContent);
    } catch (e) {
        throw new Error("File content is not valid JSON.");
    }

    // Check if vault is encrypted
    const isEncrypted = Boolean(
        vaultJson.header && 
        vaultJson.header.slots && 
        vaultJson.header.slots.length > 0 &&
        typeof vaultJson.db === 'string'
    );

    if (!isEncrypted) {
        // Plaintext vault
        const content = typeof vaultJson.db === 'object' ? vaultJson.db : vaultJson;
        return {
            content,
            masterKey: null,
            isEncrypted: false
        };
    }

    if (!password) {
        throw new Error("Password required to unlock encrypted vault.");
    }

    // Recover master key from slot and decrypt DB
    const { masterKey } = await recoverMasterKey(vaultJson, password);
    const content = await decryptVaultDb(vaultJson, masterKey);

    return {
        content,
        masterKey,
        isEncrypted: true
    };
}
