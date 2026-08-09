# Contributing to Azokle Auth

First off, thank you for considering contributing to **Azokle Auth**! 🎉

We welcome contributions from everyone. Following these guidelines helps ensure a smooth process for contributors and maintainers alike.

---

## 📜 Code of Conduct

This project and everyone participating in it is governed by the [Azokle Auth Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## 🛠️ How to Contribute

### 1. Reporting Bugs
- Check existing GitHub Issues to see if the bug has already been reported.
- If not, create a new Issue with a clear title, reproduction steps, expected behavior, and environment details (OS, Android version, Browser version).

### 2. Suggesting Features
- Open a GitHub Discussion or Issue describing the feature request.
- Explain the use case and why it would be beneficial to the project.

### 3. Pull Requests
1. Fork the repository and create your branch from `main`:
   ```bash
   git checkout -b feat/my-new-feature
   ```
2. Make your changes adhering to existing code formatting and architecture:
   - For Android: Android Studio, Java/Kotlin, Material 3 guidelines.
   - For Extension: Vanilla JS, CSS Custom Properties, Manifest V3.
3. Ensure no network calls or telemetry are introduced (**100% Offline Rule**).
4. Commit your changes with clear, semantic commit messages:
   ```bash
   git commit -m "feat(extension): add custom feature description"
   ```
5. Push to your fork and submit a Pull Request to `main`.

---

## 🔒 Security Principles

Azokle Auth is built on strict security guarantees:
- **Zero Telemetry / Zero Network:** No HTTP requests, external analytics, or remote logging.
- **Client-Side Encryption:** All secret keys and data are encrypted locally using AES-256-GCM and scrypt.
- **Memory Hygiene:** Zero-fill sensitive key bytes in memory upon vault lock.

---

## 📄 License

By contributing to Azokle Auth, you agree that your contributions will be licensed under the [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
