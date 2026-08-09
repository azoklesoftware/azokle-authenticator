// src/importers/bitwarden.js

/**
 * Parses Bitwarden JSON export or CSV file content for TOTP entries.
 * @param {string} fileContent 
 * @returns {Array<Object>} List of Azokle-compatible VaultEntry items
 */
export function parseBitwarden(fileContent) {
    const entries = [];

    try {
        const json = JSON.parse(fileContent);
        const items = json.items || [];

        for (const item of items) {
            const totp = item.login ? item.login.totp : null;
            if (totp) {
                const name = item.login.username || item.name || '';
                const issuer = item.name || 'Bitwarden';
                entries.push(createVaultEntryFromTotpUri(totp, name, issuer));
            }
        }
    } catch (e) {
        // Fallback to CSV parsing if not JSON
        const lines = fileContent.split('\n');
        if (lines.length > 1) {
            const header = lines[0].split(',');
            const totpIndex = header.findIndex(h => h.trim().toLowerCase().includes('login_totp'));
            const nameIndex = header.findIndex(h => h.trim().toLowerCase().includes('name'));
            const usernameIndex = header.findIndex(h => h.trim().toLowerCase().includes('login_username'));

            if (totpIndex !== -1) {
                for (let i = 1; i < lines.length; i++) {
                    const row = lines[i].split(',');
                    if (row[totpIndex] && row[totpIndex].trim()) {
                        const name = row[usernameIndex] ? row[usernameIndex].trim() : '';
                        const issuer = row[nameIndex] ? row[nameIndex].trim() : 'Bitwarden';
                        entries.push(createVaultEntryFromTotpUri(row[totpIndex].trim(), name, issuer));
                    }
                }
            }
        }
    }

    return entries;
}

function createVaultEntryFromTotpUri(totpString, defaultName, defaultIssuer) {
    let secret = totpString;
    let issuer = defaultIssuer;
    let name = defaultName;

    if (totpString.startsWith('otpauth://')) {
        try {
            const url = new URL(totpString);
            secret = url.searchParams.get('secret') || secret;
            issuer = url.searchParams.get('issuer') || issuer;
            const pathName = decodeURIComponent(url.pathname.replace(/^\/\w+\//, ''));
            if (pathName) name = pathName;
        } catch (e) {}
    }

    return {
        uuid: crypto.randomUUID(),
        type: 'totp',
        name,
        issuer,
        note: 'Imported from Bitwarden',
        favorite: false,
        groups: [],
        info: {
            secret,
            algo: 'SHA1',
            digits: 6,
            period: 30
        }
    };
}
