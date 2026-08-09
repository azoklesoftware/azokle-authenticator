// src/importers/index.js
import { parseBitwarden } from './bitwarden.js';
import { parse2FAS } from './twofas.js';

/**
 * Universal importer dispatcher.
 * Auto-detects 2FAS, Bitwarden, or standard Azokle formats.
 * 
 * @param {string} fileContent 
 * @returns {Array<Object>|null} Extracted entries or null if native Azokle format
 */
export function importExternalVault(fileContent) {
    try {
        const json = JSON.parse(fileContent);
        
        // Native Azokle format (has version and db or header)
        if (json.version !== undefined && (json.db !== undefined || json.header !== undefined)) {
            return null; // Handled by native Azokle parser
        }

        // 2FAS format (has schemaVersion or services)
        if (json.services || json.schemaVersion) {
            return parse2FAS(fileContent);
        }

        // Bitwarden format (has items array)
        if (json.items && Array.isArray(json.items)) {
            return parseBitwarden(fileContent);
        }
    } catch (e) {
        // Try Bitwarden CSV parser
        if (fileContent.includes('login_totp')) {
            return parseBitwarden(fileContent);
        }
    }

    return null;
}
