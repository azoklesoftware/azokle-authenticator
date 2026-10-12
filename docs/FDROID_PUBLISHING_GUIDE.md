# F-Droid Publishing & Release Guide

This document explains why the application does not automatically appear on the official F-Droid catalog despite a passing GitHub Actions workflow, and provides the step-by-step instructions to get **Azokle Auth** officially published on F-Droid.

---

## 1. Why Doesn't the App Show on F-Droid Automatically?

A common misconception is that running a GitHub Actions workflow named `f-droid.yml` publishes the app to F-Droid. **It does not.**

### How F-Droid Actually Works:
1. **F-Droid is an independent open-source package manager**, not an app store API endpoint like Google Play Console.
2. **F-Droid does not pull APKs from external CI/CD workflows.** For security and trust, the official F-Droid store builds all applications **from source on its own isolated build servers** running in clean Debian VMs.
3. **F-Droid signs APKs with F-Droid's private master key** (or verifies reproducible builds against developer tags).
4. For an app to enter the official catalog (`f-droid.org`), a **Metadata Recipe (`com.azokle.authenticator.yml`)** must be submitted via a Merge Request (MR) to the official [fdroiddata repository](https://gitlab.com/fdroid/fdroiddata).

---

## 2. Prerequisites Completed in This Repository

We have already configured and prepared the repository for seamless F-Droid inclusion:

| Requirement | Status | Details |
|---|---|---|
| **Open Source License** |  Compliant | GPL-3.0-or-later (`LICENSE` file) |
| **No Non-Free Blobs** |  Compliant | 100% offline, zero proprietary Google Play services, ZXing + CameraX for QR scanning |
| **Reproducible Build Ready** |  Compliant | Gradle wrapper, `aboutLibraries` tasks reproducible, resilient Git hash resolution in `build.gradle` |
| **F-Droid Recipe** |  Created | [`fdroid/com.azokle.authenticator.yml`](../fdroid/com.azokle.authenticator.yml) and [`.fdroid.yml`](../.fdroid.yml) |
| **Fastlane Store Metadata** |  Configured | [`fastlane/metadata/android/en-US/`](../fastlane/metadata/android/en-US/) with icon (512x512), screenshots, title, descriptions, and changelogs |

---

## 3. Step-by-Step: Submitting to Official F-Droid (`fdroiddata`)

To get Azokle Auth listed in the official F-Droid app store, follow these steps:

### Step 1: Create a GitLab Account
F-Droid's repository is hosted on GitLab. If you don't already have an account, register at [gitlab.com](https://gitlab.com).

### Step 2: Fork `fdroiddata`
1. Navigate to: **[https://gitlab.com/fdroid/fdroiddata](https://gitlab.com/fdroid/fdroiddata)**
2. Click **Fork** (top right) to create a copy under your GitLab account.

### Step 3: Add the Recipe File
In your fork of `fdroiddata`:
1. Create a new branch: `git checkout -b add-azokle-auth`
2. Add a new file at: `metadata/com.azokle.authenticator.yml`
3. Copy the exact contents of [`fdroid/com.azokle.authenticator.yml`](../fdroid/com.azokle.authenticator.yml):

```yaml
Categories:
  - Security
  - System
License: GPL-3.0-or-later
AuthorName: Azokle
AuthorWebSite: https://azokle.com
WebSite: https://azokle.com
SourceCode: https://github.com/azoklesoftware/azokle-authenticator
IssueTracker: https://github.com/azoklesoftware/azokle-authenticator/issues
Changelog: https://github.com/azoklesoftware/azokle-authenticator/releases

AutoName: Azokle Auth
Summary: Free, secure and open source 2FA app to manage tokens for your online services
Description: |-
  Azokle Auth is a free, secure and open source app to manage your 2-step verification tokens for your online services.

  <b>Compatibility</b>
  Azokle Auth supports the HOTP and TOTP algorithms. These two algorithms are industry-standard and widely supported, making Azokle Auth compatible with thousands of services. Any web service that supports Google Authenticator will also work with Azokle Auth.

  <b>Encryption and biometric unlock</b>
  All of your one-time passwords are stored in a vault. If you choose to set a password (highly recommended), the vault will be encrypted using strong cryptography. If someone with malicious intent gets a hold of the vault file, it's impossible for them to retrieve the contents without knowing the password. Entering your password each time you need access to a one-time password can be cumbersome. Fortunately, you can also enable biometric unlock if your device has a biometrics sensor (i.e. fingerprint or face unlock).

  <b>Organization</b>
  Over time, you'll likely accumulate tens of entries in your vault. Azokle Auth has lots of organization options to make finding the one you need at a particular moment easier. Set a custom icon for an entry to make it easier to find. Search by account name or service name. Have a lot of one-time passwords? Add them to custom groups for easier access. Personal, Work and Social can each get their own group.

  <b>Backups</b>
  To make sure you will never lose access to your online accounts, Azokle Auth can create automatic backups of the vault to a location of your choosing. If your cloud provider supports the Storage Access Framework of Android (like Nextcloud does), it can even create automatic backups to the cloud. Creating manual exports of the vault is also supported.

  <b>Making the switch</b>
  To make the switch easier, Azokle Auth can import the entries of lots of other authenticators, including: 2FAS Authenticator, Authenticator Plus, Authy, andOTP, FreeOTP, FreeOTP+, Google Authenticator, Microsoft Authenticator, Steam, TOTP Authenticator and WinAuth (root access is required for the apps that don't have an option to export).

RepoType: git
Repo: https://github.com/azoklesoftware/azokle-authenticator.git

Builds:
  - versionName: '3.2'
    versionCode: 5
    commit: v3.2
    subdir: android
    gradle:
      - yes

AutoUpdateMode: Version
UpdateCheckMode: Tags
CurrentVersion: '3.2'
CurrentVersionCode: 5
```

### Step 4: Open a Merge Request (MR)
1. Push your branch to GitLab and open a **Merge Request** targeting `fdroid/fdroiddata:master`.
2. Title: `New app: com.azokle.authenticator (Azokle Auth)`
3. Description checklist:
   - [x] I am the developer or have permission to submit this app.
   - [x] The app is licensed under an OSI-approved / Free Software license (GPL-3.0-or-later).
   - [x] The app does not include proprietary tracking, ads, or non-free libraries.
   - [x] The source code repository is publicly accessible.

### Step 5: What Happens Next?
1. **F-Droid CI Runner (`checkupdates` & `fdroid lint`)**: Automated bots run linter and verify metadata.
2. **F-Droid Reviewers**: Community maintainers review the recipe and test-build the app.
3. **Merge & First Build**: Once merged, the F-Droid build server pulls the git tag (`v3.2`), compiles the release APK, signs it, and pushes it to the repository index.
4. **App Appears in F-Droid Client**: Within 24-72 hours of merge, the app appears in the official F-Droid app search.

---

## 4. Alternative: Hosting Your Own F-Droid Repository (Instant Distribution)

If you wish to provide an F-Droid repository immediately without waiting for official F-Droid review:
You can host a repository using **GitHub Pages** with the `guardianproject/fdroid-repo-action` or `mvdan/fdroid-repo-action`.
Users can then add `https://azoklesoftware.github.io/azokle-authenticator/fdroid/repo` directly in their F-Droid app settings under **Repositories -> Add Repository**.

---

## 5. Releasing New Versions

Whenever you release a new version:
1. Update `versionCode` and `versionName` in `android/app/build.gradle`.
2. Add a new changelog file in `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
3. Tag the commit with `v<versionName>` (e.g. `git tag -a v3.2 -m "Release v3.2"`).
4. Push the tag: `git push origin v3.2`.
5. Because `AutoUpdateMode: Version` and `UpdateCheckMode: Tags` are set, the F-Droid build bot automatically detects the new tag and compiles the new release without manual intervention!
