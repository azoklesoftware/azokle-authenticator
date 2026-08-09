# Azokle Auth — Secure 2FA Authenticator Suite

<p align="center">
  <strong>100% Offline, Privacy-First 2FA Authenticator for Android & Cross-Browser Extensions</strong>
</p>

<p align="center">
  <a href="https://azokle.com"><img src="https://img.shields.io/badge/Website-azokle.com-0ea5e9?style=flat-square" alt="Website" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL%20v3-10b981?style=flat-square" alt="License" /></a>
  <img src="https://img.shields.io/badge/Privacy-100%25%20Offline-38bdf8?style=flat-square" alt="Privacy" />
</p>

---

## 🌟 Overview

**Azokle Auth** is a free, open-source, zero-telemetry two-factor authentication (2FA) suite designed for maximum privacy, strong cryptography, and seamless cross-device vault interoperability.

This monorepo houses both the **Native Android Application** and the **Manifest V3 Cross-Browser Extension** (Chrome, Firefox, Edge, Brave).

---

## ✨ Features

- 🔐 **Zero Data Collection & 100% Offline:** No tracking, no analytics, no external network requests.
- 🛡️ **AES-256-GCM + `scrypt` Key Derivation:** LUKS-style slot-based double-layer vault encryption ($N=32768, r=8, p=1$).
- ⚡ **Complete 5-OTP Algorithm Support:**
  - **TOTP (RFC 6238):** SHA-1, SHA-256, SHA-512 with custom periods and digit lengths.
  - **HOTP (RFC 4226):** Counter-based code generation.
  - **Steam Guard:** Custom Base-26 alphabet (`23456789BCDFGHJKMNPQRTVWXY`).
  - **mOTP:** MD5-based 10-second OTP generation with PIN support.
  - **Yandex OTP:** SHA-256 HMAC code generation with PIN.
- 🌐 **Context-Aware Active Tab Matching:** Extension automatically detects active website domain (e.g. `github.com`) and highlights matching tokens.
- 📦 **Universal 2FA Importers:** Import backups directly from **2FAS**, **Bitwarden** (JSON & CSV), **Aegis / andOTP**, and standard `otpauth://` / `otpauth-migration://` URIs.
- 🎨 **Modern Glassmorphic UI:** 4 View Modes (Normal, Compact, Small, Tiles Grid), 5 Code Grouping modes, 7-way sorting, and animated circular progress rings.
- 📊 **Security Audit Logging:** Room-equivalent local audit event logger (`VAULT_UNLOCKED`, `VAULT_EXPORTED`, `ENTRY_SHARED`, etc.).

---

## 📁 Repository Structure

```
azokle-authenticator/
├── android/               # Native Android App (Java / MVVM / Room / Hilt)
│   ├── app/
│   ├── docs/
│   └── build.gradle
├── extension/             # Cross-Browser Extension (JS / Web Crypto / Manifest V3)
│   ├── src/
│   │   ├── crypto/       # scrypt + AES-256-GCM engines
│   │   ├── otp/          # 5 OTP algorithm generators
│   │   ├── vault/        # Slot parser & exporter
│   │   ├── importers/    # 2FAS, Bitwarden, URI parsers
│   │   ├── ui/           # Reactive store, domain matcher, sorting & search
│   │   ├── prefs/        # 31-preference settings engine
│   │   ├── audit/        # Security event audit log
│   │   └── popup/        # HTML layout & Glassmorphic CSS
│   ├── package.json
│   └── extension.config.js
├── backend/               # Rust Helper Service
├── azokle-auth-assets/    # High-resolution logos, brand icons, and screenshots
└── .azokle/               # Developer documentation and changelogs
```

---

## 🛠️ Building & Installation

### 1. Browser Extension (Chrome / Firefox / Edge)

**Requirements:** [Bun](https://bun.sh) (or Node.js >= 18)

```bash
# Navigate to extension directory
cd extension

# Install dependencies
bun install

# Development mode with hot reload
bun dev

# Production build
bun run build
```

Production build files will be placed in `extension/dist/chromium`. Load as an unpacked extension in Chrome via `chrome://extensions`.

### 2. Android Application

**Requirements:** Android Studio (API 21+)

```bash
# Navigate to android directory
cd android

# Build debug APK
./gradlew assembleDebug
```

---

## 🔒 Security Architecture

Azokle Auth uses a **slot-based key wrapping system** (similar to LUKS):

1. **Master Key:** A random 256-bit AES key encrypts the vault contents (`db`) via **AES-256-GCM**.
2. **Wrapper Key:** User password passes through **`scrypt`** ($N=32768, r=8, p=1$) with a random 128-bit salt to produce a wrapper key.
3. **Slot Encryption:** The Master Key is encrypted using the Wrapper Key via AES-256-GCM and stored inside a `PasswordSlot` (`header.slots[]`).
4. **Decryption:** Either Primary or Secondary/Backup passwords unlock the wrapper key, which reveals the master key to decrypt the database.

---

## 📄 License

Azokle Auth is open-source software licensed under the **GNU General Public License v3.0**.  
See the [LICENSE](LICENSE) file for full details.

---

<p align="center">
  Made with ❤️ by <a href="https://azokle.com">Azokle Software</a>
</p>
