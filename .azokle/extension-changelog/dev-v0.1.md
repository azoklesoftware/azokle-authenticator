# Azokle Auth Extension - Developer Changelog (v0.1.0)

> **Release Version:** `0.1.0-dev`  
> **Target Platforms:** Chrome / Firefox / Edge (Manifest V3)  
> **Privacy Model:** 100% Offline (Zero Data Collection, Zero External Network Traffic)  

---

## 🚀 Summary of Key Innovations & Architecture

This release establishes 1-to-1 feature, algorithm, settings, and vault compatibility between the **Azokle Auth Browser Extension** and the **Azokle Auth Android** application.

---

## 🔐 1. Cryptography & Vault Engine (Full Android Parity)

- **`scrypt` Key Derivation Engine (`crypto/scrypt.js`):**
  - Integrated `scrypt-js` matching Android's parameter specification ($N = 32768, r = 8, p = 1$).
  - Full memory-hard key derivation protecting user master passwords against rainbow table & GPU brute-force attacks.

- **Multi-Slot Password Fallback Decryption (`vault/decryptor.js`):**
  - Implemented the complete two-tier LUKS-like key wrapping recovery pipeline:
    1. Parse `header.slots[]` for all `PasswordSlot`s (type `0x01`).
    2. Derive wrapper key via `scrypt(password, salt, N, r, p)`.
    3. Decrypt slot's wrapped `key` via AES-256-GCM to recover the 256-bit **master key**.
    4. Decrypt `db` database payload via AES-256-GCM.
  - Supports both Primary and Backup passwords exported via Android `VaultBackupManager`.

- **Encrypted Vault Export Engine (`vault/exporter.js`):**
  - Re-encrypt updated vault entries with session master key and fresh 12-byte random AES-GCM nonces.
  - Generates valid `.azokle` JSON backup files compatible with the native Android app.

- **Standalone HTML Exporter (`vault/html-exporter.js`):**
  - Direct port of `VaultHtmlExporter.java` generating styled standalone HTML backups containing full entry data.

---

## ⚡ 2. Complete 5-OTP Algorithm Engine (`src/otp/`)

1. **TOTP (RFC 6238):** Full support for SHA-1, SHA-256, SHA-512 algorithms, custom period, and variable digit lengths.
2. **HOTP (RFC 4226):** Counter-based code generation with persistent counter tracking.
3. **Steam Guard:** Custom 5-character base-26 alphabet generation (`23456789BCDFGHJKMNPQRTVWXY`).
4. **mOTP:** MD5-based OTP generator (`10s` period, 4-digit PIN integration).
5. **Yandex OTP:** SHA-256 HMAC algorithm with PIN support.

---

## ⚙️ 3. Preferences Engine & Customization (`src/prefs/`)

- **31-Preference Settings Engine (`prefs/index.js`):**
  - Fully mapped settings system matching Android `Preferences.java`.
  - Persisted in `chrome.storage.local`.

- **5 Code Groupings (`otp/formatter.js`):**
  - `GROUPING_THREES` (`123 456`), `GROUPING_TWOS` (`12 34 56`), `GROUPING_FOURS` (`1234 5678`), `HALVES` (midpoint split), `NO_GROUPING`.

- **4 View Modes (`popup/style.css`):**
  - `NORMAL` (default rich card), `COMPACT` (narrow rows), `SMALL` (minimalist text), `TILES` (2-column responsive grid).

- **7-Way Sort Categories (`ui/sort.js`):**
  - `ISSUER` (A-Z), `ISSUER_REVERSED` (Z-A), `ACCOUNT` (A-Z), `ACCOUNT_REVERSED` (Z-A), `USAGE_COUNT`, `LAST_USED`, `CUSTOM` (drag order).
  - Favorites (⭐) always pinned to top.

- **Bitmasked Search (`ui/search.js`):**
  - Bitmask filtering across `ISSUER` (0x01), `NAME` (0x02), `NOTE` (0x04), and `GROUPS` (0x08).

- **Show Next Code Preview:**
  - Calculates and renders `code(t + period)` preview for TOTP tokens.

---

## 🛡️ 4. Security Audit Log System (`src/audit/`)

- **Room-Equivalent Audit Logger (`audit/index.js`):**
  - Logs security events: `VAULT_UNLOCKED`, `VAULT_EXPORTED`, `ENTRY_SHARED`, `VAULT_UNLOCK_FAILED_PASSWORD`, etc.
  - Dedicated interactive Audit Log modal view.

- **Memory Hygiene:**
  - Automatically zero-fills `masterKey` Uint8Array memory bytes upon vault lock.

---

## 🌐 5. Multi-Format Importers Engine (`src/importers/`)

Auto-detects and converts third-party 2FA backups directly into Azokle Auth entries:
- **Bitwarden Importer (`importers/bitwarden.js`):** JSON vault items & CSV exports (`login_totp`).
- **2FAS Importer (`importers/twofas.js`):** JSON backup files (`.2fas`).
- **Azokle Auth Importer:** Native `.azokle` encrypted and plaintext JSON backups.

---

## 🎯 6. Smart Browser Features & UI

- **Context-Aware Active Tab Domain Matching (`ui/domain-matcher.js`):**
  - Uses `activeTab` permission to query current window URL (e.g. `github.com`).
  - Matches active tab domain against entry issuers/names and renders a **"MATCHED FOR ACTIVE TAB"** suggested token banner at top.

- **Modern Glassmorphism UI:**
  - Deep slate dark mode (`#0F172A`) with blurred translucent glass surfaces.
  - Animated SVG circular progress rings (Color urgency: Sky Blue → Warning Orange → Danger Red).

---

## 📊 Build Verification
- **Production Output:** `dist/chromium` (110.9 KB)
- **Compile Time:** 558 ms
- **Network Requests:** 0 (100% Offline)
