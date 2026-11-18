# Changelog

All notable changes to **SLT Smart PC Boost** are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-11-18

### Added
- **Open-Source Repository Governance:** Standardized OSI-approved `LICENSE` (MIT), `AUTHORS.md`, `CITATION.cff`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `.editorconfig`, and `.gitattributes`.
- **Automated CI Pipeline:** Added `.github/workflows/ci.yml` running JSON/XAML validation, PowerShell AST syntax checks, PSScriptAnalyzer error checks, and Pester 5 test suites on `windows-latest`.
- **Expanded Testing & Docs:** Added `tests/Repository-Integrity.Tests.ps1`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, and structured GitHub Issue/PR templates.
- **Phase 1 Security & Safety Hardening:**
  - Local salted **PBKDF2-HMAC-SHA1** staff PIN setup with restricted NTFS ACLs (removed hardcoded default PIN).
  - Typed registry backup/restore with retention of failed rollback entries.
  - Explicit QC pass gates for keyboard, charger, and chassis/body checks.
  - Static Pester 5 safety invariant suite (`tests/Phase1-Safety.Tests.ps1`) and `docs/PHASE1_SECURITY_HARDENING.md`.

### Changed
- Changed unknown hardware telemetry to `Not reported` and incomplete QC states to `Pending / Not tested`.
- Masked device serial numbers in reports and preflight exports; hid Wi-Fi SSID in detail views.
- Hardened Sysprep/BitLocker/Unattend workflows to verify encryption status, protect external `Panther\unattend.xml` files, and archive diagnostic logs.
- Aligned `README.md` and `README_START_HERE.txt` with Phase 1 safety behavior.

### Removed / Disabled for Safety
- Removed automatic duplicate-file deletion, Public Desktop shortcut overwriting, and automatic Mark-of-the-Web (`Unblock-File`) stripping.
- Removed `manage-bde -off C:` OS volume decryption.
- Removed generic wildcard Appx cleanup and forced `--force` WinGet uninstall flags; preserved `Microsoft.WinGet.Source`, Windows Prefetch, and Windows Update caches.
- Temporarily disabled optimizations lacking a verified rollback path until Phase 2 snapshot/restore is completed.
