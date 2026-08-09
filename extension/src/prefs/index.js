// src/prefs/index.js

export const AUTO_LOCK_OFF = 1 << 0;
export const AUTO_LOCK_ON_BACK_BUTTON = 1 << 1;
export const AUTO_LOCK_ON_MINIMIZE = 1 << 2;
export const AUTO_LOCK_ON_DEVICE_LOCK = 1 << 3;

export const SEARCH_IN_ISSUER = 1 << 0;
export const SEARCH_IN_NAME = 1 << 1;
export const SEARCH_IN_NOTE = 1 << 2;
export const SEARCH_IN_GROUPS = 1 << 3;

export const defaultPreferences = {
    // UI & Appearance
    pref_tap_to_reveal: false,
    pref_tap_to_reveal_time: 30,
    pref_highlight_entry: false,
    pref_pause_entry: false,
    pref_show_icons: true,
    pref_show_next_code: false,
    pref_expiration_state: true,
    pref_code_group_size_string: 'GROUPING_THREES', // HALVES, NO_GROUPING, GROUPING_TWOS, GROUPING_THREES, GROUPING_FOURS
    pref_current_sort_category: 'ISSUER',           // CUSTOM, ACCOUNT, ACCOUNT_REVERSED, ISSUER, ISSUER_REVERSED, USAGE_COUNT, LAST_USED
    pref_current_view_mode: 'NORMAL',               // NORMAL, COMPACT, SMALL, TILES
    pref_account_name_position: 'END',
    pref_shared_issuer_account_name: false,
    pref_current_theme: 'SYSTEM',

    // Behavior & Copying
    pref_current_copy_behavior: 'SINGLETAP',       // NEVER, SINGLETAP, DOUBLETAP
    pref_minimize_on_copy: false,
    pref_focus_search: false,
    pref_warn_time_sync: true,

    // Security & Locks
    pref_auto_lock_mask: AUTO_LOCK_ON_MINIMIZE | AUTO_LOCK_ON_DEVICE_LOCK,
    pref_search_behavior_mask: SEARCH_IN_ISSUER | SEARCH_IN_NAME,
    pref_panic_trigger: false,
    pref_timeout: -1,                              // -1 = infinite or background default

    // Password Reminders
    pref_password_reminder_freq: 'BIWEEKLY',       // NEVER, WEEKLY, BIWEEKLY, MONTHLY
    pref_password_reminder_counter: 0,

    // Persisted Filters
    pref_group_filter_uuids: []
};

class PreferencesManager {
    constructor() {
        this.prefs = { ...defaultPreferences };
    }

    async load() {
        const stored = await chrome.storage.local.get('appPreferences');
        if (stored.appPreferences) {
            this.prefs = { ...defaultPreferences, ...stored.appPreferences };
        }
        return this.prefs;
    }

    async set(key, value) {
        this.prefs[key] = value;
        await chrome.storage.local.set({ appPreferences: this.prefs });
    }

    async setAll(patch) {
        this.prefs = { ...this.prefs, ...patch };
        await chrome.storage.local.set({ appPreferences: this.prefs });
    }

    get(key) {
        return this.prefs[key] !== undefined ? this.prefs[key] : defaultPreferences[key];
    }

    getAll() {
        return { ...this.prefs };
    }
}

export const prefs = new PreferencesManager();
