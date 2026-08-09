// src/ui/avatars.js

// 19 Material Design level 700 colors matching TextDrawableHelper.java
const MATERIAL_700_COLORS = [
    '#D32F2F', '#C2185B', '#7B1FA2', '#512DA8',
    '#303F9F', '#1976D2', '#0288D1', '#0097A7',
    '#00796B', '#388E3C', '#689F38', '#AFB42B',
    '#FBC02D', '#FFA000', '#F57C00', '#E64A19',
    '#5D4037', '#616161', '#455A64'
];

/**
 * Deterministic color generator matching Android's ColorGenerator algorithm.
 * @param {string} text 
 * @returns {string} Hex color code
 */
export function getAvatarColor(text) {
    if (!text) return MATERIAL_700_COLORS[0];
    let hash = 0;
    for (let i = 0; i < text.length; i++) {
        hash = (hash << 5) - hash + text.charCodeAt(i);
        hash |= 0;
    }
    const index = Math.abs(hash) % MATERIAL_700_COLORS.length;
    return MATERIAL_700_COLORS[index];
}

/**
 * Generates an HTML avatar element for an entry (or SVG data URI).
 * @param {string} issuer Entry issuer or account name
 * @returns {Object} { letter: string, color: string }
 */
export function generateLetterAvatar(issuer) {
    const cleanText = (issuer || '?').trim();
    const letter = cleanText.charAt(0).toUpperCase();
    const color = getAvatarColor(cleanText);
    return { letter, color };
}
