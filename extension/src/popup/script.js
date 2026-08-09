// src/popup/script.js
import { parseAndDecryptVault } from '../vault/parser.js';
import { exportEncryptedVault, downloadVaultFile } from '../vault/exporter.js';
import { generateHtmlExport } from '../vault/html-exporter.js';
import { importExternalVault } from '../importers/index.js';
import { generateCode } from '../otp/index.js';
import { formatOtpCode } from '../otp/formatter.js';
import { store } from '../ui/store.js';
import { getActiveTabDomain, findMatchingEntry } from '../ui/domain-matcher.js';
import { logAuditEvent, EventType, getAuditLogs } from '../audit/index.js';

let masterKey = null;
let currentRawVaultContent = null;
let originalVaultHeader = null;
let refreshInterval = null;
let pendingPinCallback = null;
let activeTabDomain = null;

// DOM Elements
const views = {
    unlock: document.getElementById('view-unlock'),
    otp: document.getElementById('view-otp')
};

const sections = {
    setup: document.getElementById('setup-section'),
    unlock: document.getElementById('unlock-section'),
    suggested: document.getElementById('suggested-section'),
    suggestedCardContainer: document.getElementById('suggested-card-container')
};

const ui = {
    lockBtn: document.getElementById('lock-btn'),
    settingsBtn: document.getElementById('settings-btn'),
    addBtn: document.getElementById('add-btn'),
    vaultFile: document.getElementById('vault-file'),
    masterPassword: document.getElementById('master-password'),
    unlockBtn: document.getElementById('unlock-btn'),
    unlockError: document.getElementById('unlock-error'),
    otpList: document.getElementById('otp-list'),
    searchInput: document.getElementById('search-input'),
    sortSelect: document.getElementById('sort-select'),
    viewModeSelect: document.getElementById('view-mode-select'),
    groupChips: document.getElementById('group-chips'),
    template: document.getElementById('otp-card-template'),
    // Settings Modal
    settingsModal: document.getElementById('settings-modal'),
    settingsCloseBtn: document.getElementById('settings-close-btn'),
    prefTapReveal: document.getElementById('pref-tap-reveal'),
    prefShowNext: document.getElementById('pref-show-next'),
    prefMinimizeCopy: document.getElementById('pref-minimize-copy'),
    prefCodeGrouping: document.getElementById('pref-code-grouping'),
    prefCopyBehavior: document.getElementById('pref-copy-behavior'),
    exportAzokleBtn: document.getElementById('export-azokle-btn'),
    exportHtmlBtn: document.getElementById('export-html-btn'),
    viewAuditBtn: document.getElementById('view-audit-btn'),
    // Audit Modal
    auditModal: document.getElementById('audit-modal'),
    auditLogList: document.getElementById('audit-log-list'),
    auditCloseBtn: document.getElementById('audit-close-btn'),
    // PIN Modal
    pinModal: document.getElementById('pin-modal'),
    pinInput: document.getElementById('pin-input'),
    pinSubmitBtn: document.getElementById('pin-submit-btn'),
    pinCancelBtn: document.getElementById('pin-cancel-btn'),
    // Add Entry Modal
    addModal: document.getElementById('add-modal'),
    addIssuer: document.getElementById('add-issuer'),
    addAccount: document.getElementById('add-account'),
    addSecret: document.getElementById('add-secret'),
    addSubmitBtn: document.getElementById('add-submit-btn'),
    addCancelBtn: document.getElementById('add-cancel-btn')
};

async function init() {
    await store.init();
    bindEvents();
    
    // Check active tab domain
    activeTabDomain = await getActiveTabDomain();

    // Sync preferences to controls
    const prefs = store.getState().preferences;
    ui.sortSelect.value = prefs.pref_current_sort_category;
    ui.viewModeSelect.value = prefs.pref_current_view_mode;
    ui.prefTapReveal.checked = prefs.pref_tap_to_reveal;
    ui.prefShowNext.checked = prefs.pref_show_next_code;
    ui.prefMinimizeCopy.checked = prefs.pref_minimize_on_copy;
    ui.prefCodeGrouping.value = prefs.pref_code_group_size_string;
    ui.prefCopyBehavior.value = prefs.pref_current_copy_behavior;

    // Load encrypted vault
    const storage = await chrome.storage.local.get('encryptedVault');
    if (!storage.encryptedVault) {
        sections.setup.classList.remove('hidden');
    } else {
        currentRawVaultContent = storage.encryptedVault;
        sections.unlock.classList.remove('hidden');
        ui.masterPassword.focus();

        chrome.runtime.sendMessage({ type: "GET_KEY" }, async (response) => {
            if (response && response.key) {
                masterKey = response.key;
                await unlockWithKey(currentRawVaultContent, masterKey);
            }
        });
    }

    store.subscribe(() => {
        renderGroupChips();
        renderOtps();
    });
}

function bindEvents() {
    ui.vaultFile.addEventListener('change', handleFileUpload);
    ui.unlockBtn.addEventListener('click', handleUnlock);
    ui.masterPassword.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleUnlock();
    });
    
    ui.lockBtn.addEventListener('click', () => {
        // Zero out master key bytes in memory for security
        if (masterKey && masterKey.buffer) {
            try { new Uint8Array(masterKey.buffer).fill(0); } catch(e){}
        }
        masterKey = null;
        chrome.runtime.sendMessage({ type: "LOCK_VAULT" }, () => window.close());
    });

    ui.settingsBtn.addEventListener('click', () => ui.settingsModal.classList.remove('hidden'));
    ui.settingsCloseBtn.addEventListener('click', () => ui.settingsModal.classList.add('hidden'));

    ui.exportAzokleBtn.addEventListener('click', handleExportAzokle);
    ui.exportHtmlBtn.addEventListener('click', handleExportHtml);
    ui.viewAuditBtn.addEventListener('click', showAuditModal);
    ui.auditCloseBtn.addEventListener('click', () => ui.auditModal.classList.add('hidden'));

    ui.addBtn.addEventListener('click', () => {
        ui.addIssuer.value = '';
        ui.addAccount.value = '';
        ui.addSecret.value = '';
        ui.addModal.classList.remove('hidden');
        ui.addIssuer.focus();
    });

    ui.addCancelBtn.addEventListener('click', () => ui.addModal.classList.add('hidden'));
    ui.addSubmitBtn.addEventListener('click', handleAddEntry);

    ui.searchInput.addEventListener('input', (e) => store.setSearchQuery(e.target.value));

    ui.sortSelect.addEventListener('change', (e) => store.updatePreference('pref_current_sort_category', e.target.value));

    ui.viewModeSelect.addEventListener('change', (e) => store.updatePreference('pref_current_view_mode', e.target.value));

    // Preference bindings
    ui.prefTapReveal.addEventListener('change', (e) => store.updatePreference('pref_tap_to_reveal', e.target.checked));
    ui.prefShowNext.addEventListener('change', (e) => store.updatePreference('pref_show_next_code', e.target.checked));
    ui.prefMinimizeCopy.addEventListener('change', (e) => store.updatePreference('pref_minimize_on_copy', e.target.checked));
    ui.prefCodeGrouping.addEventListener('change', (e) => store.updatePreference('pref_code_group_size_string', e.target.value));
    ui.prefCopyBehavior.addEventListener('change', (e) => store.updatePreference('pref_current_copy_behavior', e.target.value));

    ui.pinSubmitBtn.addEventListener('click', handlePinSubmit);
    ui.pinCancelBtn.addEventListener('click', handlePinCancel);
    ui.pinInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handlePinSubmit();
    });

    chrome.runtime.onMessage.addListener((request) => {
        if (request.type === "VAULT_LOCKED") window.close();
    });
}

async function handleFileUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (event) => {
        try {
            const content = event.target.result;
            const externalEntries = importExternalVault(content);
            if (externalEntries && externalEntries.length > 0) {
                const newVault = { version: 3, entries: externalEntries, groups: [] };
                store.setVault(newVault);
                showOtpView();
                alert(`Successfully imported ${externalEntries.length} entries!`);
                return;
            }

            await chrome.storage.local.set({ encryptedVault: content });
            currentRawVaultContent = content;

            sections.setup.classList.add('hidden');
            sections.unlock.classList.remove('hidden');
            ui.masterPassword.focus();
        } catch (err) {
            alert("Invalid vault format. Please select a valid file.");
        }
    };
    reader.readAsText(file);
}

async function handleUnlock() {
    const password = ui.masterPassword.value.trim();
    if (!password) return;

    ui.unlockError.classList.add('hidden');
    ui.unlockBtn.disabled = true;
    ui.unlockBtn.querySelector('span').textContent = 'Deriving Key (scrypt)...';

    try {
        const { content, masterKey: derivedKey } = await parseAndDecryptVault(currentRawVaultContent, password);
        masterKey = derivedKey;

        try {
            const parsed = JSON.parse(currentRawVaultContent);
            originalVaultHeader = parsed.header || null;
        } catch(e) {}

        chrome.runtime.sendMessage({ type: "UNLOCK_VAULT", key: masterKey });
        store.setVault(content);
        showOtpView();

    } catch (e) {
        console.error("Unlock Error:", e);
        logAuditEvent(EventType.VAULT_UNLOCK_FAILED_PASSWORD);
        ui.unlockError.querySelector('span').textContent = e.message || 'Invalid password or corrupted vault.';
        ui.unlockError.classList.remove('hidden');
    } finally {
        ui.unlockBtn.disabled = false;
        ui.unlockBtn.querySelector('span').textContent = 'Unlock';
        ui.masterPassword.value = '';
    }
}

async function unlockWithKey(vaultContentString, key) {
    try {
        const { content } = await parseAndDecryptVault(vaultContentString, "");
        store.setVault(content);
        showOtpView();
    } catch(err) {
        sections.unlock.classList.remove('hidden');
    }
}

function showOtpView() {
    views.unlock.classList.add('hidden');
    views.otp.classList.remove('hidden');
    ui.lockBtn.classList.remove('hidden');
    ui.settingsBtn.classList.remove('hidden');
    ui.addBtn.classList.remove('hidden');

    renderGroupChips();
    renderOtps();
    startOtpLoop();
}

function renderGroupChips() {
    const { groups, activeGroupUuid } = store.getState();
    ui.groupChips.innerHTML = '';

    if (!groups || groups.length === 0) return;

    const allChip = document.createElement('button');
    allChip.className = `chip ${activeGroupUuid === null ? 'active' : ''}`;
    allChip.textContent = 'All';
    allChip.onclick = () => store.setActiveGroup(null);
    ui.groupChips.appendChild(allChip);

    groups.forEach(g => {
        const chip = document.createElement('button');
        chip.className = `chip ${activeGroupUuid === g.uuid ? 'active' : ''}`;
        chip.textContent = g.name;
        chip.onclick = () => store.setActiveGroup(g.uuid);
        ui.groupChips.appendChild(chip);
    });
}

function renderOtps() {
    const { preferences } = store.getState();
    const entries = store.getFilteredAndSortedEntries();
    
    // ViewMode styling
    const viewModeClass = `view-${(preferences.pref_current_view_mode || 'NORMAL').toLowerCase()}`;
    ui.otpList.className = `otp-list ${viewModeClass}`;
    ui.otpList.innerHTML = '';

    // Active Tab Domain Matching
    if (activeTabDomain && entries.length > 0) {
        const matched = findMatchingEntry(entries, activeTabDomain);
        if (matched) {
            sections.suggestedCardContainer.innerHTML = '';
            const cardNode = createOtpCard(matched, preferences);
            sections.suggestedCardContainer.appendChild(cardNode);
            sections.suggested.classList.remove('hidden');
        } else {
            sections.suggested.classList.add('hidden');
        }
    } else {
        sections.suggested.classList.add('hidden');
    }

    if (entries.length === 0) {
        ui.otpList.innerHTML = `<div style="text-align: center; color: var(--text-secondary); margin-top: 40px;">No authentication tokens found.</div>`;
        return;
    }

    entries.forEach(entry => {
        const cardNode = createOtpCard(entry, preferences);
        ui.otpList.appendChild(cardNode);
    });

    updateProgressRings();
}

function createOtpCard(entry, preferences) {
    const clone = ui.template.content.cloneNode(true);
    const card = clone.querySelector('.otp-card');
    const issuerNode = clone.querySelector('.otp-issuer');
    const accountNode = clone.querySelector('.otp-account');
    const codeNode = clone.querySelector('.otp-code');
    const nextCodeNode = clone.querySelector('.otp-next-code');
    const starNode = clone.querySelector('.favorite-star');

    issuerNode.textContent = entry.issuer || 'Unknown';
    accountNode.textContent = entry.name || 'Account';
    
    if (entry.favorite) starNode.classList.remove('hidden');

    const tapToReveal = preferences.pref_tap_to_reveal;
    const grouping = preferences.pref_code_group_size_string;
    const showNext = preferences.pref_show_next_code;

    // Code calculation
    generateCode(entry).then(code => {
        const formatted = formatOtpCode(code, grouping);
        codeNode.textContent = tapToReveal ? '• • • • • •' : formatted;

        if (showNext && entry.type === 'totp') {
            const period = (entry.info && entry.info.period) || 30;
            const nextTime = Math.floor(Date.now() / 1000) + period;
            generateCode(entry, { timeSeconds: nextTime }).then(nextCode => {
                nextCodeNode.textContent = `Next: ${formatOtpCode(nextCode, grouping)}`;
                nextCodeNode.classList.remove('hidden');
            });
        }
    }).catch(() => {
        codeNode.textContent = 'RE-PIN';
    });

    const copyBehavior = preferences.pref_current_copy_behavior || 'SINGLETAP';
    
    let clickTimeout = null;
    card.addEventListener('click', async () => {
        if (tapToReveal && codeNode.textContent.startsWith('•')) {
            const rawCode = await generateCode(entry);
            codeNode.textContent = formatOtpCode(rawCode, grouping);
            setTimeout(() => {
                codeNode.textContent = '• • • • • •';
            }, (preferences.pref_tap_to_reveal_time || 30) * 1000);
            return;
        }

        if (copyBehavior === 'NEVER') return;

        if (copyBehavior === 'DOUBLETAP') {
            if (!clickTimeout) {
                clickTimeout = setTimeout(() => { clickTimeout = null; }, 300);
            } else {
                clearTimeout(clickTimeout);
                clickTimeout = null;
                executeCopy(card, entry, preferences);
            }
        } else {
            executeCopy(card, entry, preferences);
        }
    });

    return card;
}

async function executeCopy(cardNode, entry, preferences) {
    if (entry.type === 'motp' || entry.type === 'yandex') {
        if (!entry.info.pin) {
            promptPin(entry, async (pin) => {
                entry.info.pin = pin;
                const newCode = await generateCode(entry);
                performClipboardWrite(cardNode, entry.uuid, newCode, preferences);
            });
            return;
        }
    }
    const currentCode = await generateCode(entry);
    performClipboardWrite(cardNode, entry.uuid, currentCode, preferences);
}

function performClipboardWrite(cardNode, entryUuid, rawCode, preferences) {
    navigator.clipboard.writeText(rawCode);
    store.incrementUsage(entryUuid);

    cardNode.classList.add('copied');
    setTimeout(() => cardNode.classList.remove('copied'), 1500);

    if (preferences.pref_minimize_on_copy) {
        setTimeout(() => window.close(), 300);
    }
}

async function handleAddEntry() {
    const issuer = ui.addIssuer.value.trim();
    const name = ui.addAccount.value.trim();
    const secret = ui.addSecret.value.trim();

    if (!issuer || !secret) {
        alert("Please provide at least an Issuer and Secret Key.");
        return;
    }

    const newEntry = {
        uuid: crypto.randomUUID(),
        type: 'totp',
        name: name || issuer,
        issuer: issuer,
        note: '',
        favorite: false,
        groups: [],
        info: {
            secret,
            algo: 'SHA1',
            digits: 6,
            period: 30
        }
    };

    const currentVault = store.getState();
    const updatedEntries = [newEntry, ...currentVault.entries];
    
    store.setState({ entries: updatedEntries });
    ui.addModal.classList.add('hidden');

    if (masterKey) {
        const fullVaultContent = { version: 3, entries: updatedEntries, groups: currentVault.groups };
        const encryptedJson = await exportEncryptedVault(fullVaultContent, masterKey, originalVaultHeader);
        await chrome.storage.local.set({ encryptedVault: encryptedJson });
        currentRawVaultContent = encryptedJson;
    }
}

async function handleExportAzokle() {
    if (!masterKey) {
        alert("Vault must be unlocked to export.");
        return;
    }

    const currentVault = store.getState();
    const fullVaultContent = { version: 3, entries: currentVault.entries, groups: currentVault.groups };
    
    const encryptedJson = await exportEncryptedVault(fullVaultContent, masterKey, originalVaultHeader);
    downloadVaultFile(encryptedJson, "azokle_backup.azokle");
    logAuditEvent(EventType.VAULT_EXPORTED, "azokle_backup.azokle");
}

function handleExportHtml() {
    const currentVault = store.getState();
    const htmlString = generateHtmlExport(currentVault.entries);
    downloadVaultFile(htmlString, "azokle_backup.html");
    logAuditEvent(EventType.VAULT_EXPORTED, "azokle_backup.html");
}

async function showAuditModal() {
    ui.settingsModal.classList.add('hidden');
    ui.auditLogList.innerHTML = '';
    
    const logs = await getAuditLogs();
    if (logs.length === 0) {
        ui.auditLogList.innerHTML = `<div style="text-align:center; color:var(--text-secondary); padding:20px;">No audit events recorded.</div>`;
    } else {
        logs.forEach(log => {
            const div = document.createElement('div');
            div.className = 'audit-item';
            const timeStr = new Date(log.timestamp).toLocaleTimeString();
            div.innerHTML = `
                <span class="audit-time">${timeStr}</span>
                <div class="audit-type">${log.eventType}</div>
                <div style="color:var(--text-secondary); margin-top:2px;">${log.reference || ''}</div>
            `;
            ui.auditLogList.appendChild(div);
        });
    }

    ui.auditModal.classList.remove('hidden');
}

function promptPin(entry, callback) {
    pendingPinCallback = callback;
    ui.pinInput.value = '';
    ui.pinModal.classList.remove('hidden');
    ui.pinInput.focus();
}

function handlePinSubmit() {
    const pin = ui.pinInput.value.trim();
    if (pin && pendingPinCallback) {
        ui.pinModal.classList.add('hidden');
        pendingPinCallback(pin);
        pendingPinCallback = null;
    }
}

function handlePinCancel() {
    ui.pinModal.classList.add('hidden');
    pendingPinCallback = null;
}

function startOtpLoop() {
    if (refreshInterval) clearInterval(refreshInterval);
    refreshInterval = setInterval(() => {
        const seconds = Math.floor(Date.now() / 1000) % 30;
        const remaining = 30 - seconds;
        updateProgressRings(remaining);

        if (remaining === 30) {
            renderOtps();
        }
    }, 1000);
}

function updateProgressRings(remaining = 30 - (Math.floor(Date.now() / 1000) % 30)) {
    const circumference = 62.831;
    const offset = circumference - (remaining / 30) * circumference;

    document.querySelectorAll('.progress-ring-value').forEach(ring => {
        ring.style.strokeDashoffset = offset;
        if (remaining <= 5) {
            ring.classList.add('danger');
            ring.classList.remove('warning');
        } else if (remaining <= 10) {
            ring.classList.add('warning');
            ring.classList.remove('danger');
        } else {
            ring.classList.remove('warning', 'danger');
        }
    });
}

document.addEventListener('DOMContentLoaded', init);
