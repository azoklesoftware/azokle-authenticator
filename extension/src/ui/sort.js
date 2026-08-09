// src/ui/sort.js

/**
 * Sorts vault entries using the 7 SortCategory modes matching SortCategory.java.
 * Favorites are always pinned to top.
 * 
 * @param {Array<Object>} entries 
 * @param {string} category CUSTOM | ACCOUNT | ACCOUNT_REVERSED | ISSUER | ISSUER_REVERSED | USAGE_COUNT | LAST_USED
 * @param {Object} [usageCounts] UUID -> count
 * @param {Object} [lastUsedTimestamps] UUID -> timestamp
 * @returns {Array<Object>} Sorted copy of entries
 */
export function sortEntries(entries, category = 'ISSUER', usageCounts = {}, lastUsedTimestamps = {}) {
    const sorted = [...entries];

    sorted.sort((a, b) => {
        // Favorites pinned to top
        if (a.favorite && !b.favorite) return -1;
        if (!a.favorite && b.favorite) return 1;

        switch (category) {
            case 'ACCOUNT': {
                const comp = (a.name || '').localeCompare(b.name || '');
                return comp !== 0 ? comp : (a.issuer || '').localeCompare(b.issuer || '');
            }
            case 'ACCOUNT_REVERSED': {
                const comp = (b.name || '').localeCompare(a.name || '');
                return comp !== 0 ? comp : (b.issuer || '').localeCompare(a.issuer || '');
            }
            case 'ISSUER_REVERSED': {
                const comp = (b.issuer || b.name || '').localeCompare(a.issuer || a.name || '');
                return comp !== 0 ? comp : (b.name || '').localeCompare(a.name || '');
            }
            case 'USAGE_COUNT': {
                const countA = usageCounts[a.uuid] || a.usageCount || 0;
                const countB = usageCounts[b.uuid] || b.usageCount || 0;
                return countB - countA;
            }
            case 'LAST_USED': {
                const timeA = lastUsedTimestamps[a.uuid] || a.lastUsedTimestamp || 0;
                const timeB = lastUsedTimestamps[b.uuid] || b.lastUsedTimestamp || 0;
                return timeB - timeA;
            }
            case 'CUSTOM':
                return 0; // Preserves custom drag-and-drop order

            case 'ISSUER':
            default: {
                const comp = (a.issuer || a.name || '').localeCompare(b.issuer || b.name || '');
                return comp !== 0 ? comp : (a.name || '').localeCompare(b.name || '');
            }
        }
    });

    return sorted;
}
