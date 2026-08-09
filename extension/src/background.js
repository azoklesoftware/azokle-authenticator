// background.js
/**
 * Azokle Auth Extension - Background Service Worker
 * Ensures 100% offline operation and manages secure in-memory sessions.
 */

// In-memory secure storage for the derived master key.
// NEVER written to disk.
let masterKey = null;
let lockTimeout = null;

const SESSION_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Resets the session timeout
 */
function resetTimeout() {
    if (lockTimeout) clearTimeout(lockTimeout);
    if (masterKey) {
        lockTimeout = setTimeout(() => {
            lockVault();
        }, SESSION_TIMEOUT_MS);
    }
}

/**
 * Locks the vault by clearing the master key from memory.
 */
function lockVault() {
    masterKey = null;
    if (lockTimeout) clearTimeout(lockTimeout);
    console.log("Vault automatically locked for security.");
    
    // Notify popup if it's open
    chrome.runtime.sendMessage({ type: "VAULT_LOCKED" }).catch(() => {});
}

// Listen for messages from the popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.type === "UNLOCK_VAULT") {
        // In a real implementation, we would derive the key here or receive it.
        // For security, key derivation should happen in the background to prevent 
        // the popup context from leaking it if inspected.
        masterKey = request.key; 
        resetTimeout();
        sendResponse({ success: true });
    } else if (request.type === "LOCK_VAULT") {
        lockVault();
        sendResponse({ success: true });
    } else if (request.type === "IS_UNLOCKED") {
        resetTimeout();
        sendResponse({ unlocked: masterKey !== null });
    } else if (request.type === "GET_KEY") {
        // Internal secure request
        resetTimeout();
        sendResponse({ key: masterKey });
    }
    return true; // Keep message channel open for async responses if needed
});
