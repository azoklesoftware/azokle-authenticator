// src/importers/twofas.js

/**
 * Parses 2FAS JSON export file.
 * @param {string} fileContent 
 * @returns {Array<Object>}
 */
export function parse2FAS(fileContent) {
    const json = JSON.parse(fileContent);
    const services = json.services || json || [];
    const entries = [];

    for (const service of services) {
        if (!service.secret) continue;

        const otpInfo = service.otp || {};
        entries.push({
            uuid: crypto.randomUUID(),
            type: (otpInfo.tokenType || 'totp').toLowerCase(),
            name: service.name || otpInfo.account || '',
            issuer: service.name || otpInfo.issuer || '2FAS',
            note: 'Imported from 2FAS',
            favorite: false,
            groups: [],
            info: {
                secret: service.secret,
                algo: otpInfo.algorithm || 'SHA1',
                digits: otpInfo.digits || 6,
                period: otpInfo.period || 30
            }
        });
    }

    return entries;
}
