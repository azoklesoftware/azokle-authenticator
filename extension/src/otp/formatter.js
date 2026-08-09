// src/otp/formatter.js

/**
 * Formats an OTP string based on the active CodeGrouping strategy matching Android preferences.
 * 
 * @param {string} code Raw code, e.g. "123456"
 * @param {string} mode HALVES | NO_GROUPING | GROUPING_TWOS | GROUPING_THREES | GROUPING_FOURS
 * @returns {string} Formatted string, e.g. "123 456"
 */
export function formatOtpCode(code, mode = 'GROUPING_THREES') {
    if (!code || typeof code !== 'string') return '';
    
    switch (mode) {
        case 'NO_GROUPING':
            return code;

        case 'HALVES': {
            const mid = Math.ceil(code.length / 2);
            return `${code.slice(0, mid)} ${code.slice(mid)}`;
        }

        case 'GROUPING_TWOS':
            return chunkString(code, 2);

        case 'GROUPING_FOURS':
            return chunkString(code, 4);

        case 'GROUPING_THREES':
        default:
            return chunkString(code, 3);
    }
}

function chunkString(str, size) {
    const numChunks = Math.ceil(str.length / size);
    const chunks = new Array(numChunks);
    for (let i = 0, o = 0; i < numChunks; ++i, o += size) {
        chunks[i] = str.substr(o, size);
    }
    return chunks.join(' ');
}
