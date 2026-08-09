# Azokle Auth Extension - Developer Changelog (v0.1.0)

> **Release Version:** `0.1.0-dev`  
> **Target Platforms:** Chrome / Firefox / Edge (Manifest V3)  
> **Privacy Model:** 100% Offline (Zero Data Collection, Zero External Network Traffic)  

---

## 🚀 Summary of Key Innovations & Architecture

This release establishes 1-to-1 feature, algorithm, settings, vault compatibility, and a modernized glassmorphic UI system between the **Azokle Auth Browser Extension** and the **Azokle Auth Android** application.

---

## 🎨 1. Modernized Design System & Viewport Hardening

- **Viewport & Container Scaling:**
  - Standardized popup viewport dimensions (`html, body { width: 380px; height: 100%; min-height: 540px; }`) preventing window truncation across Chrome dev frames and side panels.
  - Set `.container { height: 100vh; backdrop-filter: blur(16px); }`.

- **Card Height & Flexbox Squishing Fix:**
  - Added `flex-shrink: 0; min-height: 76px;` to `.otp-card` preventing flexbox from compressing card height down to 36px when multiple entries exist.
  - Preserves full 24px cyan OTP code visibility (`123 456`), type badge pills, issuer/account labels, and progress rings.

- **View Scrolling & Fixed Background Anchor:**
  - Disabled `overflow-y` on `#view-unlock` and `#view-otp`, keeping the unlock card centered and non-scrollable.
  - Pinned header and 2-row controls bar at the top of the popup; isolated vertical scrolling strictly to `.otp-list`.
  - Added `background-attachment: fixed` to `body` anchoring radial background gradients during card list scrolling.

- **Masked Code Dot Sizing & Styling:**
  - Added `.otp-code.masked` CSS rule (`font-size: 14px; letter-spacing: 4px; color: var(--text-muted); opacity: 0.75;`) for elegant dot formatting (`••••••`) when Tap-to-Reveal is enabled.

- **OTP Expiration Warning Animation (`style.css` & `script.js`):**
  - Direct port of `EntryHolder.java` (L418-L483).
  - Triggers red color shift (`#FF5252`) and pulse blink animation (`@keyframes otp-expiring-blink`) when countdown is ≤ 7 seconds.

- **Copy Confirmation Card Overlay (`index.html`, `style.css`, `script.js`):**
  - Direct port of `EntryHolder.java` (L516-L544).
  - Displays a glassmorphic **"✓ Copied!"** slide-down overlay across the card upon copying a code.

- **Group Manager System (`index.html`, `style.css`, `script.js`):**
  - Direct port of `GroupManagerActivity.java`.
  - Group creation, deletion, and filtering modal with responsive group chip tags.

- **`otpauth://` URI Parser (`src/otp/uri-parser.js`):**
  - Direct port of `GoogleAuthInfo.java`.
  - Parses `otpauth://` URIs with label splitting (`issuer:account`), secret sanitization, period, algorithm, and digits parameters.

- **Deterministic Letter Avatars Engine (`src/ui/avatars.js`):**
  - Direct port of Android's `TextDrawableHelper.java` utilizing the 19 Material 700 palette colors (`#D32F2F` through `#455A64`).
  - Generates round letter avatar badges (e.g. **A** for Amazon, **G** for GitHub) with deterministic color hashing matching Android.

- **Embedded Brand SVG Icons Engine (`src/icons/index.js`):**
  - Direct port of Android's `IconPackManager.java`.
  - Embedded vector SVG icons for top services (Google, GitHub, Microsoft, Amazon, Twitter/X, Discord, Binance, Steam, etc.) matched dynamically by issuer/domain.

- **Password Strength & Entropy Meter (`src/ui/password-strength.js`):**
  - Direct port of Android's `PasswordStrengthHelper.java`.
  - Real-time entropy calculation and 0–4 score rating (`Too Weak`, `Weak`, `Fair`, `Strong`, `Very Strong`) with color transitions.

- **Glassmorphic Form Controls:**
  - Custom dark glassmorphic input styling (`input[type="password"]`, `input[type="text"]`) with cyan focus glow (`box-shadow: 0 0 0 3px var(--primary-glow)`).
  - Drag-and-Drop file upload zone target (`#drop-zone`) with drag-over highlight state.
  - Sliding bottom-drawer Settings panel with categorized tabs (**Display**, **Security**, **Data Tools**).
  - Floating toast notification banner ("Copied to clipboard!").

---

## 🔐 2. Cryptography & Vault Engine (Full Android Parity)

- **`scrypt` Key Derivation Engine (`crypto/scrypt.js`):**
  - Integrated `scrypt-js` matching Android's parameter specification ($N = 32768, r = 8, p = 1$).
  - Full memory-hard key derivation protecting user master passwords against rainbow table & GPU brute-force attacks.

- **Multi-Slot Password Fallback Decryption (`vault/decryptor.js`):**
  - Implemented the two-tier LUKS-like key wrapping recovery pipeline:
    1. Parse `header.slots[]` for all `PasswordSlot`s (type `0x01`).
    2. Derive wrapper key via `scrypt(password, salt, N, r, p)`.
    3. Decrypt slot's wrapped `key` via AES-256-GCM to recover the 256-bit **master key**.
    4. Decrypt `db` database payload via AES-256-GCM.
  - Supports both Primary and Backup passwords exported via Android `VaultBackupManager`.

- **Encrypted Vault Export Engine (`vault/exporter.js`):**
  - Re-encrypt updated vault entries with session master key and fresh 12-byte random AES-GCM nonces.
  - Fixed `RangeError: Maximum call stack size exceeded` in Base64 export using chunked `bytesToBase64()` helper.
  - Generates valid `.azokle` JSON backup files compatible with the native Android app.

- **Standalone HTML Exporter (`vault/html-exporter.js`):**
  - Direct port of `VaultHtmlExporter.java` generating styled standalone HTML backups containing full entry data.

---

## ⚡ 3. Complete 5-OTP Algorithm Engine (`src/otp/`)

1. **TOTP (RFC 6238):** Full support for SHA-1, SHA-256, SHA-512 algorithms, custom period, and variable digit lengths.
2. **HOTP (RFC 4226):** Counter-based code generation with persistent counter tracking.
3. **Steam Guard:** Custom 5-character base-26 alphabet generation (`23456789BCDFGHJKMNPQRTVWXY`).
4. **mOTP:** MD5-based OTP generator (`10s` period, 4-digit PIN integration).
5. **Yandex OTP:** SHA-256 HMAC algorithm with PIN support.

---

## ⚙️ 4. Preferences Engine & Customization (`src/prefs/`)

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
  - Bitmask filtering across `ISSUER` (0x01), `NAME` (0x02), `NOTE` (0x04), and `GROUPS` (0x08) with type-safe string casting.

- **Show Next Code Preview:**
  - Calculates and renders `code(t + period)` preview for TOTP tokens.

---

## 🛡️ 5. Security Audit Log System (`src/audit/`)

- **Room-Equivalent Audit Logger (`audit/index.js`):**
  - Logs security events: `VAULT_UNLOCKED`, `VAULT_EXPORTED`, `ENTRY_SHARED`, `VAULT_UNLOCK_FAILED_PASSWORD`, etc.
  - Dedicated interactive Audit Log modal view.

- **Memory Hygiene:**
  - Automatically zero-fills `masterKey` Uint8Array memory bytes upon vault lock.
  - Clears `refreshInterval` background timer on lock.

---

## 🌐 6. Multi-Format Importers Engine (`src/importers/`)

Auto-detects and converts third-party 2FA backups directly into Azokle Auth entries:
- **Bitwarden Importer (`importers/bitwarden.js`):** JSON vault items & CSV exports (`login_totp`).
- **2FAS Importer (`importers/twofas.js`):** JSON backup files (`.2fas`).
- **Azokle Auth Importer:** Native `.azokle` encrypted and plaintext JSON backups.

---

## 🎯 7. Smart Browser Features & Accessibility

- **Context-Aware Active Tab Domain Matching (`ui/domain-matcher.js`):**
  - Uses `activeTab` permission to query current window URL (e.g. `github.com`).
  - Matches active tab domain against entry issuers/names and renders a **"MATCHED FOR ACTIVE TAB"** suggested token banner at top.

- **Accessibility Hardening:**
  - Added ARIA dialog attributes (`role="dialog"`, `aria-modal="true"`) and `Escape` key modal closure.
  - Custom accessible toggle switches with `role="switch"`.

---

## 📊 Build Verification
- **Production Output:** `dist/chromium` (120.4 KB)
- **Compile Time:** 431 ms
- **Network Requests:** 0 (100% Offline)
