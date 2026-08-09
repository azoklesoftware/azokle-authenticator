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
let toastTimeout = null;

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
    dropZone: document.getElementById('drop-zone'),
    vaultFile: document.getElementById('vault-file'),
    masterPassword: document.getElementById('master-password'),
    unlockBtn: document.getElementById('unlock-btn'),
    unlockError: document.getElementById('unlock-error'),
    otpList: document.getElementById('otp-list'),
    searchInput: document.getElementById('search-input'),
    clearSearchBtn: document.getElementById('clear-search-btn'),
    groupChips: document.getElementById('group-chips'),
    toastBanner: document.getElementById('toast-banner'),
    template: document.getElementById('otp-card-template'),
    // Settings Drawer Modal
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
    
    activeTabDomain = await getActiveTabDomain();

    // Sync preferences
    const prefs = store.getState().preferences;
    ui.prefTapReveal.checked = prefs.pref_tap_to_reveal;
    ui.prefShowNext.checked = prefs.pref_show_next_code;
    ui.prefMinimizeCopy.checked = prefs.pref_minimize_on_copy;
    ui.prefCodeGrouping.value = prefs.pref_code_group_size_string;
    ui.prefCopyBehavior.value = prefs.pref_current_copy_behavior;

    syncButtonGroups(prefs);

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

function syncButtonGroups(prefs) {
    document.querySelectorAll('.btn-group-item[data-sort]').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.sort === prefs.pref_current_sort_category);
    });
    document.querySelectorAll('.btn-group-item[data-mode]').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.mode === prefs.pref_current_view_mode);
    });
}

function bindEvents() {
    // Drag & Drop File Handling
    ui.dropZone.addEventListener('click', () => ui.vaultFile.click());
    ui.dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        ui.dropZone.classList.add('drag-over');
    });
    ui.dropZone.addEventListener('dragleave', () => ui.dropZone.classList.remove('drag-over'));
    ui.dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        ui.dropZone.classList.remove('drag-over');
        if (e.dataTransfer.files.length > 0) {
            handleFile(e.dataTransfer.files[0]);
        }
    });

    ui.vaultFile.addEventListener('change', (e) => {
        if (e.target.files.length > 0) handleFile(e.target.files[0]);
    });

    ui.unlockBtn.addEventListener('click', handleUnlock);
    ui.masterPassword.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleUnlock();
    });
    
    ui.lockBtn.addEventListener('click', () => {
        if (refreshInterval) {
            clearInterval(refreshInterval);
            refreshInterval = null;
        }
        if (masterKey) {
            try { new Uint8Array(masterKey.buffer || masterKey).fill(0); } catch(e){}
        }
        masterKey = null;
        chrome.runtime.sendMessage({ type: "LOCK_VAULT" }, () => window.close());
    });

    ui.settingsBtn.addEventListener('click', () => openModal(ui.settingsModal));
    ui.settingsCloseBtn.addEventListener('click', () => closeModal(ui.settingsModal));

    ui.exportAzokleBtn.addEventListener('click', handleExportAzokle);
    ui.exportHtmlBtn.addEventListener('click', handleExportHtml);
    ui.viewAuditBtn.addEventListener('click', showAuditModal);
    ui.auditCloseBtn.addEventListener('click', () => closeModal(ui.auditModal));

    ui.addBtn.addEventListener('click', () => {
        ui.addIssuer.value = '';
        ui.addAccount.value = '';
        ui.addSecret.value = '';
        openModal(ui.addModal);
        ui.addIssuer.focus();
    });

    ui.addCancelBtn.addEventListener('click', () => closeModal(ui.addModal));
    ui.addSubmitBtn.addEventListener('click', handleAddEntry);

    // Search Controls
    ui.searchInput.addEventListener('input', (e) => {
        const val = e.target.value;
        ui.clearSearchBtn.classList.toggle('hidden', !val);
        store.setSearchQuery(val);
    });

    ui.clearSearchBtn.addEventListener('click', () => {
        ui.searchInput.value = '';
        ui.clearSearchBtn.classList.add('hidden');
        store.setSearchQuery('');
        ui.searchInput.focus();
    });

    // Segmented Button Groups
    document.querySelectorAll('.btn-group-item[data-sort]').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.btn-group-item[data-sort]').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            store.updatePreference('pref_current_sort_category', btn.dataset.sort);
        });
    });

    document.querySelectorAll('.btn-group-item[data-mode]').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.btn-group-item[data-mode]').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            store.updatePreference('pref_current_view_mode', btn.dataset.mode);
        });
    });

    // Drawer Tabs Switcher
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-pane').forEach(p => p.classList.add('hidden'));
            btn.classList.add('active');
            document.getElementById(btn.dataset.tab).classList.remove('hidden');
        });
    });

    // Custom Toggles
    ui.prefTapReveal.addEventListener('change', (e) => store.updatePreference('pref_tap_to_reveal', e.target.checked));
    ui.prefShowNext.addEventListener('change', (e) => store.updatePreference('pref_show_next_code', e.target.checked));
    ui.prefMinimizeCopy.addEventListener('change', (e) => store.updatePreference('pref_minimize_on_copy', e.target.checked));
    ui.prefCodeGrouping.addEventListener('change', (e) => store.updatePreference('pref_code_group_size_string', e.target.value));
    ui.prefCopyBehavior.addEventListener('change', (e) => store.updatePreference('pref_current_copy_behavior', e.target.value));

    ui.pinSubmitBtn.addEventListener('click', handlePinSubmit);
    ui.pinCancelBtn.addEventListener('click', handlePinCancel);

    // Keyboard accessibility: Escape key closes active modal
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            document.querySelectorAll('.modal.active').forEach(modal => closeModal(modal));
        }
    });

    chrome.runtime.onMessage.addListener((request) => {
        if (request.type === "VAULT_LOCKED") window.close();
    });
}

function openModal(modalEl) {
    modalEl.classList.add('active');
}

function closeModal(modalEl) {
    modalEl.classList.remove('active');
}

function handleFile(file) {
    const reader = new FileReader();
    reader.onload = async (event) => {
        try {
            const content = event.target.result;
            const externalEntries = importExternalVault(content);
            if (externalEntries && externalEntries.length > 0) {
                const newVault = { version: 3, entries: externalEntries, groups: [] };
                store.setVault(newVault);
                showOtpView();
                showToast(`Imported ${externalEntries.length} entries!`);
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

    // Show Skeleton Loaders during decryption
    showSkeletons();

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
        ui.unlockBtn.querySelector('span').textContent = 'Unlock Vault';
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

function showSkeletons() {
    ui.otpList.innerHTML = `
        <div class="skeleton-card"></div>
        <div class="skeleton-card"></div>
        <div class="skeleton-card"></div>
    `;
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
        ui.otpList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">🔐</div>
                <h3>No Authentication Tokens</h3>
                <p style="font-size:12px;">Try a different search or click "+" to add an entry.</p>
            </div>`;
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
    const typeBadge = clone.querySelector('.type-badge');

    card.dataset.type = entry.type || 'totp';
    typeBadge.textContent = (entry.type || 'totp').toUpperCase();
    issuerNode.textContent = entry.issuer || 'Unknown';
    accountNode.textContent = entry.name || 'Account';
    
    if (entry.favorite) starNode.classList.remove('hidden');

    const tapToReveal = preferences.pref_tap_to_reveal;
    const grouping = preferences.pref_code_group_size_string;
    const showNext = preferences.pref_show_next_code;

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

    showToast("Copied to clipboard!");

    if (preferences.pref_minimize_on_copy) {
        setTimeout(() => window.close(), 300);
    }
}

function showToast(message) {
    ui.toastBanner.textContent = message;
    ui.toastBanner.classList.add('show');
    if (toastTimeout) clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => {
        ui.toastBanner.classList.remove('show');
    }, 1800);
}

async function handleAddEntry() {
    const issuer = ui.addIssuer.value.trim();
    const name = ui.addAccount.value.trim();
    const secret = ui.addSecret.value.trim().replace(/[\s\-]+/g, '');

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
        info: { secret, algo: 'SHA1', digits: 6, period: 30 }
    };

    const currentVault = store.getState();
    const updatedEntries = [newEntry, ...currentVault.entries];
    
    store.setState({ entries: updatedEntries });
    closeModal(ui.addModal);

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
    closeModal(ui.settingsModal);
    ui.auditLogList.innerHTML = '';
    
    const logs = await getAuditLogs();
    if (logs.length === 0) {
        ui.auditLogList.innerHTML = `<div style="text-align:center; color:var(--text-muted); padding:20px;">No audit events recorded.</div>`;
    } else {
        logs.forEach(log => {
            const div = document.createElement('div');
            div.style.cssText = "padding:8px; background:rgba(255,255,255,0.04); border-radius:6px; font-size:11px;";
            const timeStr = new Date(log.timestamp).toLocaleTimeString();
            div.innerHTML = `
                <div style="display:flex; justify-content:space-between; font-weight:600; color:var(--primary-color);">
                    <span>${log.eventType}</span>
                    <span style="color:var(--text-muted); font-size:10px;">${timeStr}</span>
                </div>
                <div style="color:var(--text-secondary); margin-top:2px;">${log.reference || ''}</div>
            `;
            ui.auditLogList.appendChild(div);
        });
    }

    openModal(ui.auditModal);
}

function promptPin(entry, callback) {
    pendingPinCallback = callback;
    ui.pinInput.value = '';
    openModal(ui.pinModal);
    ui.pinInput.focus();
}

function handlePinSubmit() {
    const pin = ui.pinInput.value.trim();
    if (pin && pendingPinCallback) {
        closeModal(ui.pinModal);
        pendingPinCallback(pin);
        pendingPinCallback = null;
    }
}

function handlePinCancel() {
    closeModal(ui.pinModal);
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
    const circumference = 69.115;
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

    document.querySelectorAll('.ring-seconds').forEach(secNode => {
        secNode.textContent = remaining;
    });
}

document.addEventListener('DOMContentLoaded', init);
