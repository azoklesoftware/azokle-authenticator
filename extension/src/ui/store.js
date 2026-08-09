// src/ui/store.js
import { prefs, defaultPreferences } from '../prefs/index.js';
import { filterEntriesBySearch } from './search.js';
import { sortEntries } from './sort.js';
import { logAuditEvent, EventType } from '../audit/index.js';

class Store {
    constructor() {
        this.state = {
            entries: [],
            groups: [],
            activeGroupUuid: null,
            searchQuery: '',
            preferences: { ...defaultPreferences },
            usageCounts: {},
            lastUsedTimestamps: {}
        };
        this.listeners = new Set();
    }

    async init() {
        const loadedPrefs = await prefs.load();
        const storage = await chrome.storage.local.get(['usageCounts', 'lastUsedTimestamps']);
        this.setState({
            preferences: loadedPrefs,
            usageCounts: storage.usageCounts || {},
            lastUsedTimestamps: storage.lastUsedTimestamps || {}
        });
    }

    getState() {
        return this.state;
    }

    subscribe(listener) {
        this.listeners.add(listener);
        return () => this.listeners.delete(listener);
    }

    notify() {
        for (const listener of this.listeners) {
            listener(this.state);
        }
    }

    setState(patch) {
        this.state = { ...this.state, ...patch };
        this.notify();
    }

    async updatePreference(key, value) {
        await prefs.set(key, value);
        const updated = prefs.getAll();
        this.setState({ preferences: updated });
    }

    setVault(content) {
        const entries = content.entries || [];
        const groups = content.groups || [];
        this.setState({ entries, groups });
        logAuditEvent(EventType.VAULT_UNLOCKED);
    }

    setActiveGroup(groupUuid) {
        this.setState({ activeGroupUuid: groupUuid });
    }

    setSearchQuery(query) {
        this.setState({ searchQuery: query });
    }

    incrementUsage(entryUuid) {
        const counts = { ...this.state.usageCounts };
        const timestamps = { ...this.state.lastUsedTimestamps };
        
        counts[entryUuid] = (counts[entryUuid] || 0) + 1;
        timestamps[entryUuid] = Date.now();
        
        this.setState({
            usageCounts: counts,
            lastUsedTimestamps: timestamps
        });

        chrome.storage.local.set({
            usageCounts: counts,
            lastUsedTimestamps: timestamps
        });
    }

    getFilteredAndSortedEntries() {
        let { entries, groups, activeGroupUuid, searchQuery, preferences, usageCounts, lastUsedTimestamps } = this.state;
        
        // 1. Group filter
        if (activeGroupUuid) {
            entries = entries.filter(e => e.groups && e.groups.includes(activeGroupUuid));
        }

        // 2. Bitmasked Search filter
        if (searchQuery.trim()) {
            entries = filterEntriesBySearch(entries, searchQuery, preferences.pref_search_behavior_mask, groups);
        }

        // 3. 7-Way Sort
        return sortEntries(entries, preferences.pref_current_sort_category, usageCounts, lastUsedTimestamps);
    }
}

export const store = new Store();
