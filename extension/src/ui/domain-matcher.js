// src/ui/domain-matcher.js

/**
 * Gets the current active browser tab domain (hostname).
 * @returns {Promise<string|null>} e.g. "github.com"
 */
export async function getActiveTabDomain() {
    try {
        if (typeof chrome === 'undefined' || !chrome.tabs) return null;
        
        const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
        if (!tabs || tabs.length === 0 || !tabs[0].url) return null;

        const url = new URL(tabs[0].url);
        // Ignore internal chrome:// and extension:// URLs
        if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;

        return url.hostname.replace(/^www\./i, '').toLowerCase();
    } catch (e) {
        console.warn("Could not query active tab domain:", e);
        return null;
    }
}

/**
 * Finds vault entries matching the active domain.
 * @param {Array<Object>} entries List of VaultEntry objects
 * @param {string} domain Domain string, e.g. "github.com"
 * @returns {Object|null} Matching entry or null
 */
export function findMatchingEntry(entries, domain) {
    if (!domain || !entries || entries.length === 0) return null;

    const domainParts = domain.toLowerCase().split('.');
    const mainBrand = domainParts.length >= 2 ? domainParts[domainParts.length - 2] : domain;

    // 1. Direct domain string match in issuer or name
    let match = entries.find(e => {
        const issuer = (e.issuer || '').toLowerCase();
        const name = (e.name || '').toLowerCase();
        const note = (e.note || '').toLowerCase();
        return issuer.includes(domain) || name.includes(domain) || note.includes(domain);
    });

    if (match) return match;

    // 2. Main brand string match (e.g. "github" matching "GitHub")
    if (mainBrand.length > 2) {
        match = entries.find(e => {
            const issuer = (e.issuer || '').toLowerCase();
            const name = (e.name || '').toLowerCase();
            return issuer.includes(mainBrand) || name.includes(mainBrand);
        });
    }

    return match || null;
}
