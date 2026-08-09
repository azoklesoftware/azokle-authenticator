// src/otp.js
import * as OTPAuth from 'otpauth';

/**
 * Parses a standard otpauth:// URI and returns an OTPAuth.TOTP or HOTP instance.
 * @param {string} uri 
 * @returns {OTPAuth.TOTP | OTPAuth.HOTP | null}
 */
export function parseURI(uri) {
    try {
        return OTPAuth.URI.parse(uri);
    } catch (e) {
        console.error("Failed to parse OTP URI", e);
        return null;
    }
}

/**
 * Generates the current token for a given OTP instance.
 * @param {OTPAuth.TOTP | OTPAuth.HOTP} otpInstance 
 * @returns {string}
 */
export function generateToken(otpInstance) {
    return otpInstance.generate();
}

/**
 * Calculates the remaining seconds for the current TOTP period.
 * @param {OTPAuth.TOTP} totpInstance 
 * @returns {number}
 */
export function getRemainingSeconds(totpInstance) {
    const epoch = Math.floor(Date.now() / 1000);
    const period = totpInstance.period || 30;
    return period - (epoch % period);
}
