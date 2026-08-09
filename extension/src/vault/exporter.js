// src/vault/exporter.js
import { encodeHex } from '../crypto/hex.js';
import { encryptAesGcmText } from '../crypto/aes-gcm.js';

function bytesToBase64(bytes) {
    let bin = '';
    const len = bytes.byteLength;
    for (let i = 0; i < len; i += 8192) {
        const chunk = bytes.subarray(i, Math.min(i + 8192, len));
        bin += String.fromCharCode.apply(null, chunk);
    }
    return btoa(bin);
}

/**
 * Encrypts updated vault content with the active masterKey and builds a valid VaultFile JSON string.
 * 
 * @param {Object} vaultContent { version: 3, entries: [...], groups: [...] }
 * @param {Uint8Array} masterKey 256-bit AES master key
 * @param {Object} [originalHeader] Optional original header to preserve slot configuration
 * @returns {Promise<string>} Encrypted Vault JSON string
 */
export async function exportEncryptedVault(vaultContent, masterKey, originalHeader = null) {
    const jsonText = JSON.stringify(vaultContent, null, 4);
    const { ciphertext, nonce, tag } = await encryptAesGcmText(jsonText, masterKey);

    const base64Ciphertext = bytesToBase64(ciphertext);

    const exportHeader = originalHeader ? { ...originalHeader } : {
        slots: [],
        params: {
            nonce: encodeHex(nonce),
            tag: encodeHex(tag)
        }
    };

    if (exportHeader.params) {
        exportHeader.params.nonce = encodeHex(nonce);
        exportHeader.params.tag = encodeHex(tag);
    }

    const vaultFileObj = {
        version: 1,
        header: exportHeader,
        db: base64Ciphertext
    };

    return JSON.stringify(vaultFileObj, null, 4);
}

/**
 * Triggers a browser download of the vault file.
 * @param {string} contentJson 
 * @param {string} [filename="azokle_backup.azokle"] 
 */
export function downloadVaultFile(contentJson, filename = "azokle_backup.azokle") {
    const blob = new Blob([contentJson], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}
