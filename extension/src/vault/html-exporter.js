// src/vault/html-exporter.js
import { encodeBase32 } from '../crypto/base32.js';
import { encodeHex } from '../crypto/hex.js';

/**
 * Generates HTML export string matching Android VaultHtmlExporter.java format.
 * 
 * @param {Array<Object>} entries List of VaultEntry objects
 * @returns {string} Standalone HTML document string
 */
export function generateHtmlExport(entries) {
    let rowsHtml = '';

    entries.forEach(entry => {
        const info = entry.info || {};
        const isMotp = entry.type === 'motp';
        const isYandex = entry.type === 'yandex';
        const isHotp = entry.type === 'hotp';

        let secretStr = '';
        if (info.secret) {
            const bytes = typeof info.secret === 'string' ? new TextEncoder().encode(info.secret) : info.secret;
            secretStr = isMotp ? encodeHex(bytes) : (typeof info.secret === 'string' ? info.secret : encodeBase32(bytes));
        }

        const pinStr = isMotp || isYandex ? (info.pin || '-') : '-';
        const counterStr = isHotp ? (info.counter !== undefined ? info.counter : '0') : '-';

        rowsHtml += `
        <tr>
            <td>${escapeHtml(entry.issuer || '-')}</td>
            <td>${escapeHtml(entry.name || '-')}</td>
            <td>${escapeHtml((entry.type || 'totp').toUpperCase())}</td>
            <td>${escapeHtml(entry.uuid || '-')}</td>
            <td>${escapeHtml(entry.note || '-')}</td>
            <td>${entry.favorite ? 'true' : 'false'}</td>
            <td>${escapeHtml(info.algo || 'SHA1')}</td>
            <td>${info.digits || 6}</td>
            <td class="code">${escapeHtml(secretStr)}</td>
            <td>${counterStr}</td>
            <td>${escapeHtml(pinStr)}</td>
        </tr>`;
    });

    return `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Azokle Auth Backup</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 24px; background: #0F172A; color: #F8FAFC; }
        h1 { margin-bottom: 20px; color: #0EA5E9; }
        table { width: 100%; border-collapse: collapse; background: rgba(30, 41, 59, 0.8); border-radius: 8px; overflow: hidden; }
        th, td { padding: 12px 14px; text-align: left; border-bottom: 1px solid rgba(255,255,255,0.1); font-size: 13px; }
        th { background: rgba(0,0,0,0.3); color: #94A3B8; font-weight: 600; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; }
        tr:hover { background: rgba(255,255,255,0.05); }
        .code { font-family: monospace; color: #38BDF8; font-weight: 600; }
    </style>
</head>
<body>
    <h1>Azokle Auth — Vault Backup Export</h1>
    <table>
        <thead>
            <tr>
                <th>Issuer</th>
                <th>Name</th>
                <th>Type</th>
                <th>UUID</th>
                <th>Note</th>
                <th>Favorite</th>
                <th>Algo</th>
                <th>Digits</th>
                <th>Secret</th>
                <th>Counter</th>
                <th>PIN</th>
            </tr>
        </thead>
        <tbody>
            ${rowsHtml}
        </tbody>
    </table>
</body>
</html>`;
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
