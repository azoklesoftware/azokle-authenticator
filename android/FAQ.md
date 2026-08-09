# Azokle Auth — Frequently Asked Questions

## General

### What is Azokle Auth?
Azokle Auth is a free, secure and open source 2FA (Two-Factor Authentication) app for Android, built as part of the Azokle ecosystem. It stores your one-time passwords (OTPs) in an encrypted vault on your device.

### Is Azokle Auth open source?
Yes. Azokle Auth is licensed under the [GNU General Public License v3.0](LICENSE). The source code is available at [github.com/azoklesoftware/azokle-authenticator](https://github.com/azoklesoftware/azokle-authenticator).

### Is Azokle Auth free?
Yes. Azokle Auth is completely free with no ads, no tracking and no in-app purchases.

---

## Security & Encryption

### How does Azokle Auth protect my tokens?
All tokens are stored in an encrypted vault using AES-256-GCM. The vault key is derived from your password using scrypt. Without the correct password, the vault contents cannot be read.

### Can I use biometrics instead of a password?
Yes. You can enable biometric unlock (fingerprint or face) in **Settings → Security → Biometric unlock**. Biometrics are backed by the Android KeyStore and wrapped against the master key.

### What happens if I forget my password?
There is no password recovery mechanism. If you forget your password and have no backup, you will permanently lose access to your tokens. **We strongly recommend setting up automatic backups.**

### Is Azokle Auth compatible with cloud backup?
Azokle Auth supports Android's cloud backup system for encrypted vaults (device-to-device transfers are always available). You can also configure automatic encrypted backups to any location supported by Android's Storage Access Framework (e.g., Nextcloud).

---

## Importing & Exporting

### What apps can I import from?
Azokle Auth supports importing from:
- 2FAS Authenticator
- andOTP
- Authy (requires root)
- Authenticator Plus
- Authenticator Pro
- Battle.net Authenticator (requires root)
- Bitwarden
- Duo Mobile (requires root)
- Ente Auth
- FreeOTP / FreeOTP+
- Google Authenticator (v5.10 and prior, requires root)
- Microsoft Authenticator (requires root)
- Plain text (otpauth:// URIs)
- Steam (v2.x, requires root)
- TOTP Authenticator
- WinAuth

### Can I export my vault?
Yes. You can export the vault in the following formats from **Settings → Import & Export → Export**:
- **AzokleAuth (.JSON)** — Encrypted or plain text
- **Text file (.TXT)** — Plain text Google Authenticator URIs
- **Web page (.HTML)** — QR codes viewable in a browser

---

## Troubleshooting

### My codes are incorrect. What do I do?
Azokle Auth relies on the system clock. Make sure **automatic time synchronization** is enabled on your device (**Settings → Date & time → Automatic date & time**).

### The app says it can't write to the backup destination.
This usually happens after restoring Azokle Auth from a backup or if you renamed/moved the backup folder. Go to **Settings → Backups → Backup location** and re-select the destination.

### Biometric unlock stopped working.
If you recently changed your device's security settings (PIN, password, enrolled fingerprints), biometric unlock may be invalidated. Go to **Settings → Security → Biometric unlock**, disable it, and re-enable it.

---

## Contact & Support

- 🌐 Website: [azokle.com](https://azokle.com)
- 📧 Email: [support@azokle.com](mailto:support@azokle.com)
- 💻 GitHub Issues: [github.com/azoklesoftware/azokle-authenticator/issues](https://github.com/azoklesoftware/azokle-authenticator/issues)
