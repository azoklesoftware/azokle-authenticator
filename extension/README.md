# Azokle Auth — Browser Extension

> [!WARNING]
> **DEVELOPMENT NOTICE:** This extension is currently **IN DEVELOPMENT** and **NOT IN PRODUCTION**. Features, APIs, and file formats may evolve. Do not use as your sole authentication backup without keeping independent secondary backups of your 2FA secret keys.

---

## 🔐 Overview

Azokle Auth Browser Extension is a 100% offline, zero-telemetry, glassmorphic 2FA authenticator designed for Chromium browsers. It brings full feature parity with the native **Azokle Auth Android application**, supporting `.azokle` encrypted vault files, HTML backup exports, TOTP/HOTP/Steam codes, bitmasked multi-field search, 7-way sorting, local audit logging, and custom group management.

---

## ✨ Features

- **🔐 Offline & Private:** 100% offline architecture with zero external network requests.
- **🛡️ Android Compatibility:** Native support for reading, decrypting, modifying, and exporting `.azokle` AES-256-GCM encrypted vaults ($N=32768, r=8, p=1$ scrypt key derivation).
- **🎨 Glassmorphic Design:** Modern slate UI with smooth glowing focus rings, micro-animations, and responsive cards.
- **⚡ OTP Algorithms:** TOTP (RFC 6238), HOTP (RFC 4226), Steam Guard, Yandex, and MOTP.
- **🎯 Smart Domain Matcher:** Detects active browser tab domain and automatically highlights matching 2FA credentials.
- **🎨 Letter Avatars & Brand Icons:** Port of Android's `TextDrawableHelper.java` Material 700 19-color palette avatar generator and dynamic SVG brand logos (Google, GitHub, Microsoft, Amazon, Binance, Steam, etc.).
- **💪 Password Strength Meter:** Real-time entropy & score evaluator (0–4 rating) matching Android `PasswordStrengthHelper.java`.
- **⏳ Expiring Code Animation:** Visual red shift (`#FF5252`) and pulse blink animation when TOTP countdown drops to ≤ 7 seconds.
- **📋 Copy Confirmation Overlay:** Glassmorphic slide-down **"✓ Copied!"** card overlay upon copying authentication codes.
- **🏷️ Group Manager:** Create, rename, delete, and filter entries by custom group chip tags.
- **📜 Local Audit Log:** Track 7 key security event types stored strictly in browser local storage.
- **📤 Self-Contained HTML Exporter:** Export unencrypted self-contained single-file HTML backups matching `VaultHtmlExporter.java`.

---

## 🛠️ Development & Build

### Prerequisites
- [Bun](https://bun.sh/) (v1.0+) or [Node.js](https://nodejs.org/) (v18+)

### Development Commands
```bash
# Install dependencies
bun install

# Start live development build session
bun run dev

# Build production bundle for Chromium
bun run build
```

The compiled extension files will be generated in `dist/chromium`.

---

## 📄 License

Distributed under the **GNU General Public License v3.0 (GPL-3.0)**. See the root [LICENSE](../LICENSE) file for details.
