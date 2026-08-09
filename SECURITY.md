# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| dev-v0.1 | :white_check_mark: |
| < 0.1   | :x:                |

---

## 🔒 Reporting a Vulnerability

We take the security of **Azokle Auth** extremely seriously. Because Azokle Auth manages sensitive 2FA credentials and encryption master keys, maintaining security integrity is our highest priority.

### How to Report
- **Do NOT create a public GitHub Issue** for security vulnerabilities.
- Please email security reports to **security@azokle.com** or send a private encrypted report to the maintainers.

### What to Include
- Detailed description of the vulnerability.
- Proof of concept or exact steps to reproduce.
- Potential impact on stored vault credentials or master key security.

### Response Expectations
- **Acknowledgement:** Within 48 hours.
- **Assessment & Fix:** Security patches will be prioritized and released as quickly as possible.

---

## 🛡️ Core Security Architecture

Azokle Auth enforces strict zero-trust security guarantees:
- **AES-256-GCM Encryption:** Authenticated encryption for all stored `.azokle` vault database files.
- **Key Derivation:** `scrypt` ($N=32768, r=8, p=1$) key derivation for password slots.
- **100% Offline Guarantee:** Zero network calls, zero external CDN scripts, zero telemetry.
- **Memory Wipe:** Master keys are byte-cleared upon vault lock.
