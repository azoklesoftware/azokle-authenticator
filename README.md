# Azokle Auth

**Azokle Auth** is a free, secure and open source 2FA authenticator app for Android, built as part of the Azokle ecosystem.

<p>
  <a href="https://azokle.com">
    <img src="https://img.shields.io/badge/Website-azokle.com-blue" alt="Website" />
  </a>
  <a href="https://github.com/azoklesoftware/azokle-authenticator/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-GPL%20v3-green" alt="License" />
  </a>
</p>

## Features

- **Free & Open Source** — GPLv3 licensed
- **Encrypted Vault** — AES-256-GCM with scrypt key derivation
- **Biometric Unlock** — Fingerprint and face unlock support
- **Multiple OTP Types** — TOTP, HOTP, Steam, MOTP, Yandex
- **Import Support** — Import from Authy, Google Authenticator, Microsoft Authenticator, FreeOTP, andOTP, Duo, Steam, and more
- **Automatic Backups** — Scheduled encrypted backups to a location of your choosing
- **Quick Settings Tiles** — Fast vault and scanner access from the notification shade
- **Panic Kit Integration** — Emergency vault deletion via Ripple/PanicKit
- **Material Design** — Light, Dark and AMOLED themes with dynamic color support

## Getting Started

### Requirements

- Android 5.0 (API 21) or higher
- Android Studio (for building from source)

### Build

```bash
git clone https://github.com/azoklesoftware/azokle-authenticator.git
cd azokle-authenticator
./gradlew assembleDebug
```

## Documentation

- [Vault format](/docs/vault.md) — Security design and file format specification
- [Icon packs](/docs/iconpacks.md) — How to create and use icon packs
- [Decrypt vault (Python)](/docs/decrypt.py) — Script to decrypt an Azokle Auth vault

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Azokle Auth is licensed under the [GNU General Public License v3.0](LICENSE).

## Links

- 🌐 Website: [azokle.com](https://azokle.com)
- 💻 GitHub: [github.com/azoklesoftware/azokle-authenticator](https://github.com/azoklesoftware/azokle-authenticator)
- 📧 Support: [support@azokle.com](mailto:support@azokle.com)
