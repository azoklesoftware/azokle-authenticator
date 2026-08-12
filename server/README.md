# 🛡️ Azokle Auth - Sync Server

[![Status](https://img.shields.io/badge/Status-Under%20Active%20Development-yellow.svg)](#)
[![Rust](https://img.shields.io/badge/Language-Rust-orange.svg)](https://www.rust-lang.org/)
[![Security](https://img.shields.io/badge/Security-E2EE%20Zero--Knowledge-blue.svg)](#-security--privacy-architecture)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](../LICENSE)

> [!WARNING]
> **🚧 UNDER ACTIVE DEVELOPMENT 🚧**  
> The Azokle Auth Sync Server is currently under active pre-release development. Features, schemas, and API endpoints are subject to change.

The **Azokle Auth Sync Server** provides high-speed, reliable, **End-to-End Encrypted (E2EE)** synchronization across multiple devices. 

---

## 🔒 Security & Privacy Architecture

### 1. Zero-Knowledge Client-Side Encryption
All sensitive 2FA vault data, TOTP secrets, account names, and metadata are **encrypted on the client device** *before* being transmitted to the sync server.

```
┌─────────────────────────┐               ┌─────────────────────────┐
│     Device A (App)      │               │     Device B (App)      │
│  ┌───────────────────┐  │  Ciphertext   │  ┌───────────────────┐  │
│  │ Plaintext Secrets │  │  over TLS     │  │ Plaintext Secrets │  │
│  └─────────┬─────────┘  │   (Encrypted) │  └─────────▲─────────┘  │
│     Client Encryption   │       │       │    Client Decryption    │
│            ▼            │       ▼       │            │            │
│    [ Ciphertext Blob ] ──┼──► [ SERVER ] ┼────────────┘            │
└─────────────────────────┘       │       └─────────────────────────┘
                                  ▼
                         Stores ONLY Ciphertext
                          (Zero Knowledge)
```

- **Client-Side Keys**: Encryption keys are derived locally using strong key derivation functions (such as **Argon2id**) and master passphrases.
- **Server Role**: The server acts strictly as an untrusted, high-availability encrypted payload store. It **never** possesses or receives your master key, plaintext TOTP entries, or unencrypted metadata.
- **Zero Privacy Leakage**: Even in the event of a full server compromise, attackers obtain only unreadable ciphertext blobs.

---

## ⚡ Core Features

- **🔄 Multi-Device Synchronization**: Real-time conflict-free payload sync across Android and other client devices.
- **🚀 High Performance**: Built with Rust for lightweight memory footprint, low latency, and high concurrent throughput.
- **🔐 End-to-End Encryption**: Endpoints process strictly authenticated ciphertext payloads.
- **🛡️ Secure Token Authentication**: JWT or session-based device authorization for vault updates.

---

## 🛠️ Prerequisites & Setup

### Requirements
- **Rust Toolchain**: `rustc` & `cargo` 1.70+

### Local Development

1. **Navigate to the server directory:**
   ```bash
   cd server
   ```

2. **Build the binary:**
   ```bash
   cargo build --release
   ```

3. **Run the server:**
   ```bash
   cargo run
   ```

---

## 🌐 API Protocol & Endpoints

| Method | Endpoint | Description | Payload |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/register` | Register a sync account | Authenticated User Credentials |
| `POST` | `/api/v1/auth/login` | Authenticate device session | Session Token Request |
| `GET` | `/api/v1/sync/pull` | Retrieve encrypted vault payload | Encrypted Ciphertext Blob |
| `POST` | `/api/v1/sync/push` | Upload encrypted vault payload | Encrypted Ciphertext Blob |

---

## 📜 License

This project is released under the GPL-3.0 License. See the root [LICENSE](../LICENSE) file for details.
