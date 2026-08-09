// src/ui/store.js

class Store {
    constructor() {
        this.state = {
            entries: [],
            groups: [],
            activeGroupUuid: null,
            searchQuery: '',
            sortCategory: 'issuer', // 'custom', 'issuer', 'account', 'usage_count', 'last_used'
            settings: {
                tapToReveal: false,
                codeGrouping: 'GROUPING_THREES',
                autoLockMinutes: 5,
                minimizeOnCopy: false
            },
            usageCounts: {},
            lastUsedTimestamps: {}
        };
        this.listeners = new Set();
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

    setVault(content) {
        const entries = content.entries || [];
        const groups = content.groups || [];
        this.setState({ entries, groups });
    }

    setActiveGroup(groupUuid) {
        this.setState({ activeGroupUuid: groupUuid });
    }

    setSearchQuery(query) {
        this.setState({ searchQuery: query });
    }

    setSortCategory(category) {
        this.setState({ sortCategory: category });
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

        // Persist locally
        chrome.storage.local.set({
            usageCounts: counts,
            lastUsedTimestamps: timestamps
        });
    }

    getFilteredAndSortedEntries() {
        let { entries, activeGroupUuid, searchQuery, sortCategory, usageCounts, lastUsedTimestamps } = this.state;
        
        // 1. Group filtering
        if (activeGroupUuid) {
            entries = entries.filter(e => e.groups && e.groups.includes(activeGroupUuid));
        }

        // 2. Search filtering (Issuer, Name, Note)
        if (searchQuery.trim()) {
            const q = searchQuery.toLowerCase().trim();
            entries = entries.filter(e => {
                const name = (e.name || '').toLowerCase();
                const issuer = (e.issuer || '').toLowerCase();
                const note = (e.note || '').toLowerCase();
                return name.includes(q) || issuer.includes(q) || note.includes(q);
            });
        }

        // 3. Sorting
        const sorted = [...entries];
        
        // Favorites always stay on top
        sorted.sort((a, b) => {
            if (a.favorite && !b.favorite) return -1;
            if (!a.favorite && b.favorite) return 1;

            switch (sortCategory) {
                case 'account':
                    return (a.name || '').localeCompare(b.name || '');
                case 'usage_count': {
                    const countA = usageCounts[a.uuid] || 0;
                    const countB = usageCounts[b.uuid] || 0;
                    return countB - countA;
                }
                case 'last_used': {
                    const timeA = lastUsedTimestamps[a.uuid] || 0;
                    const timeB = lastUsedTimestamps[b.uuid] || 0;
                    return timeB - timeA;
                }
                case 'issuer':
                default:
                    return (a.issuer || a.name || '').localeCompare(b.issuer || b.name || '');
            }
        });

        return sorted;
    }
}

export const store = new Store();
