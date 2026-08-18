# Azokle Auth — Native iOS Application

<p align="center">
  <strong>100% Offline, Zero-Telemetry, Hardware-Backed 2FA/MFA Authenticator for iOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2016.0%2B-0ea5e9?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%206-f05138?style=flat-square&logo=swift" alt="Language" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20HIG-6366f1?style=flat-square" alt="UI" />
  <img src="https://img.shields.io/badge/Status-In%20Development%20(v0.1.0--dev)-f59e0b?style=flat-square" alt="Status" />
  <img src="https://img.shields.io/badge/Security-AES--256--GCM%20%2B%20scrypt-10b981?style=flat-square" alt="Security" />
  <img src="https://img.shields.io/badge/Privacy-100%25%20Offline-38bdf8?style=flat-square" alt="Privacy" />
</p>

---

## 🌟 Overview

**Azokle Auth for iOS** is a high-performance, native SwiftUI two-factor authentication manager built from the ground up for iOS 16+. It achieves 100% feature, cryptographic, and visual parity with the mature Android and Web Extension versions of Azokle Auth, while adhering strictly to **Apple Human Interface Guidelines (HIG)** and modern glassmorphic AMOLED aesthetics.

---

## 🚀 Key Features

### 🛡️ Military-Grade Cryptography & Zero Telemetry
- **100% Offline Architecture:** No network requests, telemetry, or remote servers. All cryptographic keys remain strictly on the device.
- **LUKS-Style Multi-Slot Vault:** 256-bit AES-GCM vault encryption wrapped by polymorphic slots (`PasswordSlot`, `BiometricSlot`, `RawSlot`).
- **Hardware-Backed Protection:** Seamless Face ID / Touch ID biometric authentication via Keychain Services (`kSecUseAuthenticationContext`) and iOS `.completeFileProtection`.
- **scrypt Key Derivation:** Pure Swift scrypt ($N=32768, r=8, p=1$) with flattened contiguous memory layouts for instant unlocking.

### ⚡ 5-Algorithm OTP Engine
- **TOTP (RFC 6238):** SHA-1, SHA-256, SHA-512 with configurable periods (15s, 30s, 60s) and digits (6, 7, 8).
- **HOTP (RFC 4226):** Counter-based authentication with manual refresh controls.
- **Steam Guard:** Base-26 alphanumeric 5-character token generation.
- **mOTP:** 10-second MD5-based Mobile OTP with PIN support.
- **Yandex OTP (YAOTP):** HMAC-SHA256 Base-26 formatted OTP with PIN.
- **Google Migration:** Protobuf binary wire parser & encoder (`otpauth-migration://offline?data=...`).

### 📦 Universal Multi-Format Importers (10 Formats)
Single-tap automatic format detection and ingestion:
1. **Azokle / Aegis:** Plaintext & encrypted AES-GCM backups.
2. **2FAS:** 2FAS 3.x, 4.x, and 5.x JSON files.
3. **andOTP:** Plaintext and encrypted backups (140,000 PBKDF2 iterations).
4. **Authenticator Pro:** Encrypted and plain JSON backups.
5. **Authy:** Exported token structures (including 7-digit TOTP).
6. **FreeOTP & FreeOTP+:** XML preference dumps (`tokens.xml`) and JSON schemas.
7. **WinAuth:** XML authenticator backups.
8. **Bitwarden:** JSON and CSV export files.
9. **Google Authenticator:** Migration QR codes.
10. **Raw URI Lists:** Newline-separated `otpauth://` links.

### 📲 Offline Device-to-Device Animated QR Transfer
- **Animated QR Slideshow:** Partitions large vaults into chunked `otpauth-migration://` frames (8 tokens/frame) and animates them at 1.2s intervals for zero-network device migration.
- **Continuous Multi-Frame Scanner:** Rapidly reads streamed QR frames from another device and imports all tokens in seconds.

### 🎨 Apple HIG & AMOLED Dark Design System
- **AMOLED Glassmorphism:** Pure AMOLED Black (`#000000`), Deep Slate surfaces (`#12141C`), and Cyan-Indigo gradient accents.
- **4 Discrete View Modes:** **Normal** (detailed), **Compact** (single-line), **Small** (dense list), and **Tiles Grid** (2-column cards).
- **Live Dynamic Timer Rings:** 0.5s smooth arc animation shifting from Cyan ($>10\text{s}$) $\to$ Amber ($5\text{s} < t \le 10\text{s}$) $\to$ Pulsing Red ($t \le 5\text{s}$).
- **Micro-Interactions & Haptics:** Tap-to-copy with system haptics (`UIImpactFeedbackGenerator`), floating toast confirmation HUD, and tap-to-reveal code obfuscation (`••••••`).
- **Custom Icons & 50+ Brand Matcher:** Photo Library custom image storage and automatic glyph matching for Google, GitHub, Microsoft, Apple, Discord, Steam, AWS, Twitter/X, Binance, and more.

### ⚙️ Background Services & Security Subsystems
- **Password Health Reminders:** Scheduled intervals (Daily, Weekly, Bi-weekly, Monthly) to ensure master passwords are never forgotten.
- **Automatic Rolling Backups:** Encrypted `.json` snapshots created automatically in `Documents/Backups/` with rolling version limits (5, 10, 25, Unlimited).
- **Security Audit Log:** Persistent local event history tracking unlock attempts, exports, and biometric failures.
- **App Switcher Privacy Shield:** Automatic privacy mask when backgrounded to prevent credential shoulder surfing.

---

## 📁 Architecture & File Layout

```
ios/Azokle Auth/Azokle Auth/
├── Azokle_AuthApp.swift             # App Lifecycle & Privacy Shield Mask
├── ContentView.swift                # Root State Coordinator & Onboarding Router
├── Assets.xcassets/
│   ├── AppIcon.appiconset/          # Official App Icons (21 PNGs + Contents.json)
│   ├── AppLogo.imageset/            # Brand Logo Assets (1x, 2x, 3x)
│   └── AccentColor.colorset/        # Cyan Brand Accent (#06B6D4)
├── Crypto/
│   ├── CryptoUtils.swift            # AES-256-GCM Encryption
│   ├── Encoding.swift               # Base32, Hex, Base64 Codecs
│   ├── SCrypt.swift                 # Pure Swift scrypt KDF (N=32768, r=8, p=1)
│   └── Slots.swift                  # PasswordSlot, BiometricSlot, RawSlot
├── OTP/
│   ├── OTPType.swift                # OTP Enums (TOTP, HOTP, Steam, mOTP, YAOTP)
│   ├── TOTPEngine.swift             # RFC 6238 Time-Based Engine
│   ├── HOTPEngine.swift             # RFC 4226 Counter-Based Engine
│   ├── SteamEngine.swift            # Steam Guard Base-26 Engine
│   ├── MOTPEngine.swift             # mOTP MD5 Engine
│   ├── YAOTPEngine.swift            # Yandex YAOTP Engine
│   └── GoogleAuthMigrationParser.swift # Protobuf Wire Decoder & Encoder
├── Vault/
│   ├── VaultModels.swift            # VaultEntry, VaultGroup, OtpInfoModel
│   ├── VaultFile.swift              # Vault Serialization & Decryption
│   ├── VaultRepository.swift        # Atomic CRUD & Complete Protection
│   └── VaultManager.swift           # In-Memory Vault Coordinator & Biometrics
├── Importers/
│   ├── Importers.swift              # Universal Importer Cascade Engine
│   ├── ExtendedImporters.swift      # andOTP, Authy, Pro, FreeOTP, WinAuth
│   └── Exporters.swift              # Encrypted JSON, Plaintext, URI List
├── Services/
│   ├── PreferencesStore.swift       # User Defaults & Behavioral Options
│   ├── ClipboardService.swift       # Secure Isolated Clipboard
│   ├── AuditLogService.swift        # Security Event Audit Log
│   ├── AutoBackupService.swift      # Rolling Encrypted Snapshot Engine
│   ├── PassReminderService.swift    # Password Health Verification
│   └── IconManager.swift            # Custom Icons & Brand Suggestion Engine
└── Views/
    ├── Theme.swift                  # Color Tokens, Typography, Glassmorphism
    ├── Components/
    │   ├── DynamicTimerRing.swift   # Real-Time Countdown Arc & Linear Bar
    │   └── CopyToastView.swift      # Ephemeral Floating Copy HUD
    ├── EntryCardView.swift          # Normal, Compact, Small, Tiles Card Layouts
    ├── EditEntryView.swift          # Token Editor with Accordion & Icon Picker
    ├── IconPickerSheet.swift        # Custom Photo & Brand Icon Selector
    ├── ScannerView.swift            # Camera Scanner with Reticle & Flashlight
    ├── TransferView.swift           # Animated Device-to-Device QR Slideshow
    ├── PassReminderSheet.swift      # Password Health Check Modal
    ├── BackupHistoryView.swift      # Rolling Snapshot Manager & Exporter
    ├── GroupManagerView.swift       # Category CRUD & Organization
    ├── SettingsView.swift           # Comprehensive Preferences Suite
    ├── AuthView.swift               # Master Password & Biometric Face ID
    ├── IntroView.swift              # First-Launch Onboarding Carousel
    └── MainVaultView.swift          # Primary Dashboard, Search & Filter Chips
```

---

## 🛠️ Requirements & Building

- **macOS:** 13.0 (Ventura) or later
- **Xcode:** 15.0 or later (Swift 6 toolchain)
- **Target Platform:** iOS 16.0+ / iPadOS 16.0+

### Opening the Project in Xcode

1. Open `ios/Azokle Auth/Azokle Auth.xcodeproj` in Xcode:
   ```bash
   open "ios/Azokle Auth/Azokle Auth.xcodeproj"
   ```
2. Select your target simulator (e.g., iPhone 15 Pro) or a connected physical iOS device.
3. Press `Cmd + R` to build and run.

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.
See the [`LICENSE`](../LICENSE) file for more details.
