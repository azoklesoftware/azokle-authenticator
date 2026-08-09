// src/otp/uri-parser.js

/**
 * Parses an otpauth:// URI into a standard VaultEntry object.
 * @param {string} uriString 
 * @returns {Object} Vault entry object
 */
export function parseOtpauthUri(uriString) {
    if (!uriString || !uriString.trim().startsWith('otpauth://')) {
        throw new Error('Invalid URI: Must start with otpauth://');
    }

    const url = new URL(uriString.trim());
    const type = url.host.toLowerCase(); // totp or hotp or steam
    let path = decodeURIComponent(url.pathname.replace(/^\//, ''));

    let issuer = '';
    let name = '';

    if (path.includes(':')) {
        const parts = path.split(':');
        issuer = parts[0].trim();
        name = parts.slice(1).join(':').trim();
    } else {
        name = path.trim();
    }

    const params = new URLSearchParams(url.search);
    if (!issuer && params.has('issuer')) {
        issuer = params.get('issuer').trim();
    }

    const rawSecret = params.get('secret');
    if (!rawSecret) {
        throw new Error('Missing required secret parameter in URI');
    }

    const secret = rawSecret.trim().replace(/[\s=\-]+/g, '');
    const period = parseInt(params.get('period') || '30', 10);
    const digits = parseInt(params.get('digits') || '6', 10);
    const algorithm = (params.get('algorithm') || 'SHA1').toUpperCase();
    const counter = parseInt(params.get('counter') || '0', 10);

    return {
        uuid: crypto.randomUUID(),
        issuer: issuer || 'Unknown',
        name: name || 'Account',
        secret: secret,
        type: type === 'hotp' ? 'hotp' : (type === 'steam' ? 'steam' : 'totp'),
        period: isNaN(period) ? 30 : period,
        digits: isNaN(digits) ? 6 : digits,
        algorithm: algorithm,
        counter: isNaN(counter) ? 0 : counter,
        favorite: false,
        note: '',
        groups: []
    };
}
