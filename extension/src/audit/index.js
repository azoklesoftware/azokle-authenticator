// src/audit/index.js

export const EventType = {
    VAULT_UNLOCKED: 'VAULT_UNLOCKED',
    VAULT_BACKUP_CREATED: 'VAULT_BACKUP_CREATED',
    VAULT_ANDROID_BACKUP_CREATED: 'VAULT_ANDROID_BACKUP_CREATED',
    VAULT_EXPORTED: 'VAULT_EXPORTED',
    ENTRY_SHARED: 'ENTRY_SHARED',
    VAULT_UNLOCK_FAILED_PASSWORD: 'VAULT_UNLOCK_FAILED_PASSWORD',
    VAULT_UNLOCK_FAILED_BIOMETRICS: 'VAULT_UNLOCK_FAILED_BIOMETRICS'
};

/**
 * Logs a security event to the local audit log.
 * @param {string} eventType 
 * @param {string} [reference] Optional details or filename
 */
export async function logAuditEvent(eventType, reference = null) {
    try {
        const stored = await chrome.storage.local.get('auditLog');
        const logs = stored.auditLog || [];

        const entry = {
            id: Date.now() + Math.random(),
            eventType,
            reference,
            timestamp: Date.now()
        };

        // Keep last 200 events
        logs.unshift(entry);
        if (logs.length > 200) logs.pop();

        await chrome.storage.local.set({ auditLog: logs });
    } catch (e) {
        console.warn("Failed to log audit event:", e);
    }
}

/**
 * Retrieves all stored audit logs.
 * @returns {Promise<Array<Object>>}
 */
export async function getAuditLogs() {
    const stored = await chrome.storage.local.get('auditLog');
    return stored.auditLog || [];
}

/**
 * Clears stored audit logs.
 */
export async function clearAuditLogs() {
    await chrome.storage.local.set({ auditLog: [] });
}
