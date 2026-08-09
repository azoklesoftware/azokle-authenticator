// src/ui/password-strength.js

/**
 * Calculates password entropy and score (0 to 4) matching PasswordStrengthHelper.java.
 * 
 * Score levels:
 * 0: Too Weak (#FF5252)
 * 1: Weak (#FF5252)
 * 2: Fair (#FFC107)
 * 3: Strong (#8BC34A)
 * 4: Very Strong (#4CAF50)
 * 
 * @param {string} password 
 * @returns {{ score: number, entropy: number, label: string, color: string }}
 */
export function evaluatePasswordStrength(password) {
    if (!password || password.length === 0) {
        return { score: 0, entropy: 0, label: '', color: '#FF5252' };
    }

    let poolSize = 0;
    if (/[a-z]/.test(password)) poolSize += 26;
    if (/[A-Z]/.test(password)) poolSize += 26;
    if (/[0-9]/.test(password)) poolSize += 10;
    if (/[^a-zA-Z0-9]/.test(password)) poolSize += 32;

    const entropy = Math.floor(password.length * Math.log2(poolSize || 1));

    let score = 0;
    if (entropy < 28) score = 0;
    else if (entropy < 36) score = 1;
    else if (entropy < 60) score = 2;
    else if (entropy < 80) score = 3;
    else score = 4;

    const labels = ['Too Weak', 'Weak', 'Fair', 'Strong', 'Very Strong'];
    const colors = ['#FF5252', '#FF5252', '#FFC107', '#8BC34A', '#4CAF50'];

    return {
        score,
        entropy,
        label: labels[score],
        color: colors[score]
    };
}
