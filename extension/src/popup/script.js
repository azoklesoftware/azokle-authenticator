// src/popup/script.js
import { parseAndDecryptVault } from '../vault/parser.js';
import { exportEncryptedVault, downloadVaultFile } from '../vault/exporter.js';
import { importExternalVault } from '../importers/index.js';
import { generateCode } from '../otp/index.js';
import { getRemainingSeconds } from '../otp.js';
import { store } from '../ui/store.js';
import { getActiveTabDomain, findMatchingEntry } from '../ui/domain-matcher.js';

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
    exportBtn: document.getElementById('export-btn'),
    addBtn: document.getElementById('add-btn'),
    vaultFile: document.getElementById('vault-file'),
    masterPassword: document.getElementById('master-password'),
    unlockBtn: document.getElementById('unlock-btn'),
    unlockError: document.getElementById('unlock-error'),
    otpList: document.getElementById('otp-list'),
    searchInput: document.getElementById('search-input'),
    sortSelect: document.getElementById('sort-select'),
    groupChips: document.getElementById('group-chips'),
    template: document.getElementById('otp-card-template'),
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
    bindEvents();
    
    // Check active tab domain
    activeTabDomain = await getActiveTabDomain();

    // Load local metrics
    const storage = await chrome.storage.local.get(['encryptedVault', 'usageCounts', 'lastUsedTimestamps']);
    if (storage.usageCounts) store.setState({ usageCounts: storage.usageCounts });
    if (storage.lastUsedTimestamps) store.setState({ lastUsedTimestamps: storage.lastUsedTimestamps });

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
        chrome.runtime.sendMessage({ type: "LOCK_VAULT" }, () => window.close());
    });

    ui.exportBtn.addEventListener('click', handleExportVault);

    ui.addBtn.addEventListener('click', () => {
        ui.addIssuer.value = '';
        ui.addAccount.value = '';
        ui.addSecret.value = '';
        ui.addModal.classList.remove('hidden');
        ui.addIssuer.focus();
    });

    ui.addCancelBtn.addEventListener('click', () => ui.addModal.classList.add('hidden'));
    ui.addSubmitBtn.addEventListener('click', handleAddEntry);

    ui.searchInput.addEventListener('input', (e) => {
        store.setSearchQuery(e.target.value);
    });

    ui.sortSelect.addEventListener('change', (e) => {
        store.setSortCategory(e.target.value);
    });

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

            // Check if it's an external vault (2FAS, Bitwarden)
            const externalEntries = importExternalVault(content);
            if (externalEntries && externalEntries.length > 0) {
                const newVault = { version: 3, entries: externalEntries, groups: [] };
                store.setVault(newVault);
                showOtpView();
                alert(`Successfully imported ${externalEntries.length} entries!`);
                return;
            }

            // Otherwise, store raw native Azokle content
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

        // Save original header for re-exporting
        try {
            const parsed = JSON.parse(currentRawVaultContent);
            originalVaultHeader = parsed.header || null;
        } catch(e) {}

        chrome.runtime.sendMessage({ type: "UNLOCK_VAULT", key: masterKey });
        store.setVault(content);
        showOtpView();

    } catch (e) {
        console.error("Unlock Error:", e);
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
    ui.exportBtn.classList.remove('hidden');
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
    const entries = store.getFilteredAndSortedEntries();
    ui.otpList.innerHTML = '';

    // Active Tab Domain Matching
    if (activeTabDomain && entries.length > 0) {
        const matched = findMatchingEntry(entries, activeTabDomain);
        if (matched) {
            sections.suggestedCardContainer.innerHTML = '';
            const cardNode = createOtpCard(matched);
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
        const cardNode = createOtpCard(entry);
        ui.otpList.appendChild(cardNode);
    });

    updateProgressRings();
}

function createOtpCard(entry) {
    const clone = ui.template.content.cloneNode(true);
    const card = clone.querySelector('.otp-card');
    const issuerNode = clone.querySelector('.otp-issuer');
    const accountNode = clone.querySelector('.otp-account');
    const codeNode = clone.querySelector('.otp-code');
    const starNode = clone.querySelector('.favorite-star');

    issuerNode.textContent = entry.issuer || 'Unknown';
    accountNode.textContent = entry.name || 'Account';
    
    if (entry.favorite) {
        starNode.classList.remove('hidden');
    }

    // Generate code
    generateCode(entry).then(code => {
        const formatted = code.length === 6 ? `${code.slice(0, 3)} ${code.slice(3)}` : code;
        codeNode.textContent = formatted;
    }).catch(() => {
        codeNode.textContent = 'RE-PIN';
    });

    card.addEventListener('click', async () => {
        if (entry.type === 'motp' || entry.type === 'yandex') {
            if (!entry.info.pin) {
                promptPin(entry, async (pin) => {
                    entry.info.pin = pin;
                    const newCode = await generateCode(entry);
                    copyCode(card, entry.uuid, newCode);
                });
                return;
            }
        }
        const currentCode = await generateCode(entry);
        copyCode(card, entry.uuid, currentCode);
    });

    return card;
}

function copyCode(cardNode, entryUuid, rawCode) {
    navigator.clipboard.writeText(rawCode);
    store.incrementUsage(entryUuid);

    cardNode.classList.add('copied');
    setTimeout(() => cardNode.classList.remove('copied'), 1500);
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

    // Auto-save/encrypt to local storage if masterKey exists
    if (masterKey) {
        const fullVaultContent = { version: 3, entries: updatedEntries, groups: currentVault.groups };
        const encryptedJson = await exportEncryptedVault(fullVaultContent, masterKey, originalVaultHeader);
        await chrome.storage.local.set({ encryptedVault: encryptedJson });
        currentRawVaultContent = encryptedJson;
    }
}

async function handleExportVault() {
    if (!masterKey) {
        alert("Vault must be unlocked to export.");
        return;
    }

    const currentVault = store.getState();
    const fullVaultContent = { version: 3, entries: currentVault.entries, groups: currentVault.groups };
    
    const encryptedJson = await exportEncryptedVault(fullVaultContent, masterKey, originalVaultHeader);
    downloadVaultFile(encryptedJson, "azokle_backup.azokle");
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
