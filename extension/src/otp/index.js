// src/otp/index.js
import { generateTOTP } from './totp.js';
import { generateHOTP } from './hotp.js';
import { generateSteamOTP } from './steam.js';
import { generateMOTP } from './motp.js';
import { generateYandexOTP } from './yandex.js';

/**
 * Dispatcher to generate an OTP code for any VaultEntry object.
 * 
 * @param {Object} entry Vault entry (type, info, etc.)
 * @param {Object} [options]
 * @param {number} [options.timeSeconds] Current epoch time in seconds
 * @param {number} [options.hotpCounter] Optional override counter for HOTP
 * @param {string} [options.pin] Optional PIN for mOTP/Yandex
 * @returns {Promise<string>} Generated OTP code
 */
export async function generateCode(entry, options = {}) {
    const type = (entry.type || 'totp').toLowerCase();
    const info = entry.info || {};
    const secret = info.secret || '';
    const timeSeconds = options.timeSeconds || Math.floor(Date.now() / 1000);

    switch (type) {
        case 'totp':
            return generateTOTP(secret, {
                algorithm: info.algo || 'SHA1',
                digits: info.digits || 6,
                period: info.period || 30,
                timeSeconds
            });

        case 'hotp': {
            const counter = options.hotpCounter !== undefined ? options.hotpCounter : (info.counter || 0);
            return generateHOTP(secret, counter, {
                algorithm: info.algo || 'SHA1',
                digits: info.digits || 6
            });
        }

        case 'steam':
            return generateSteamOTP(secret, timeSeconds);

        case 'motp': {
            const pin = options.pin || info.pin || '';
            return generateMOTP(secret, pin, timeSeconds);
        }

        case 'yandex': {
            const pin = options.pin || info.pin || '';
            return generateYandexOTP(secret, pin, timeSeconds);
        }

        default:
            throw new Error(`Unsupported OTP algorithm type: ${type}`);
    }
}
