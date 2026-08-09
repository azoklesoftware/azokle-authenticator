# Azokle Auth Extension - Developer Changelog (v0.1.0)

> **Release Version:** `0.1.0-dev`  
> **Target Platforms:** Chrome / Firefox / Edge (Manifest V3)  
> **Privacy Model:** 100% Offline (Zero Data Collection, Zero External Network Traffic)  

---

## 🚀 Summary of Key Innovations & Architecture

This release establishes full feature, algorithm, and vault compatibility between the **Azokle Auth Browser Extension** and the **Azokle Auth Android** application.

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

---

## ⚡ 2. Complete 5-OTP Algorithm Engine (`src/otp/`)

1. **TOTP (RFC 6238):** Full support for SHA-1, SHA-256, SHA-512 algorithms, custom period, and variable digit lengths.
2. **HOTP (RFC 4226):** Counter-based code generation with persistent counter tracking.
3. **Steam Guard:** Custom 5-character base-26 alphabet generation (`23456789BCDFGHJKMNPQRTVWXY`).
4. **mOTP:** MD5-based OTP generator (`10s` period, 4-digit PIN integration).
5. **Yandex OTP:** SHA-256 HMAC algorithm with PIN support.

---

## 🌐 3. Multi-Format Importers Engine (`src/importers/`)

Auto-detects and converts third-party 2FA backups directly into Azokle Auth entries:
- **Bitwarden Importer (`importers/bitwarden.js`):** JSON vault items & CSV exports (`login_totp`).
- **2FAS Importer (`importers/twofas.js`):** JSON backup files (`.2fas`).
- **Azokle Auth Importer:** Native `.azokle` encrypted and plaintext JSON backups.

---

## 🎯 4. Smart Browser Features

- **Context-Aware Active Tab Domain Matching (`ui/domain-matcher.js`):**
  - Uses `activeTab` permission to query current window URL (e.g. `github.com`).
  - Matches active tab domain against entry issuers/names and renders a **"MATCHED FOR ACTIVE TAB"** suggested token banner at the top of the popup.

---

## 🎨 5. Glassmorphism Design System & Accessibility

- **Modern Visual Styling (`popup/style.css`):**
  - Deep slate dark mode (`#0F172A`) with blurred translucent glass surfaces.
  - Typography powered by **Outfit** and **Fira Code** Google Fonts for maximum code legibility.
- **Dynamic SVG Progress Rings:**
  - Per-card animated circular SVG timer ring displaying remaining time (Color urgency: Sky Blue → Warning Orange → Danger Red).
- **Accessibility & Security:**
  - Full keyboard focus management (`tabindex="0"`, `Enter` key copy trigger).
  - ARIA live region annotations.
  - Disabled `autocomplete` and `spellcheck` on password inputs.
  - In-memory master key auto-purge after 5 minutes of inactivity (`background.js`).

---

## 📊 Build Verification
- **Production Output:** `dist/chromium` (98.8 KB)
- **Compile Time:** 324 ms
- **Network Requests:** 0 (100% Offline)
