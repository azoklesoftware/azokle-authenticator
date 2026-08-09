// src/ui/search.js
import { SEARCH_IN_ISSUER, SEARCH_IN_NAME, SEARCH_IN_NOTE, SEARCH_IN_GROUPS } from '../prefs/index.js';

/**
 * Filters vault entries based on bitmasked search preferences matching Android search behavior.
 * 
 * @param {Array<Object>} entries 
 * @param {string} query 
 * @param {number} mask Bitmask (ISSUER | NAME | NOTE | GROUPS)
 * @param {Array<Object>} [groups] Array of VaultGroup objects
 * @returns {Array<Object>} Filtered entries
 */
export function filterEntriesBySearch(entries, query, mask, groups = []) {
    if (!query || !query.trim()) return entries;
    const q = query.toLowerCase().trim();

    const groupMap = new Map();
    groups.forEach(g => groupMap.set(g.uuid, (g.name || '').toLowerCase()));

    return entries.filter(entry => {
        if ((mask & SEARCH_IN_ISSUER) && (entry.issuer || '').toLowerCase().includes(q)) {
            return true;
        }
        if ((mask & SEARCH_IN_NAME) && (entry.name || '').toLowerCase().includes(q)) {
            return true;
        }
        if ((mask & SEARCH_IN_NOTE) && (entry.note || '').toLowerCase().includes(q)) {
            return true;
        }
        if ((mask & SEARCH_IN_GROUPS) && entry.groups && entry.groups.length > 0) {
            const hasMatch = entry.groups.some(gUuid => {
                const groupName = groupMap.get(gUuid);
                return groupName && groupName.includes(q);
            });
            if (hasMatch) return true;
        }
        return false;
    });
}
