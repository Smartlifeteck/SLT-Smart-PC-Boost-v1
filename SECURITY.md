# Security Policy

## Supported Versions

| Version | Supported | Notes |
| :--- | :---: | :--- |
| `1.0.0` (main) | Yes | Active open-source development branch with Phase 1 hardening |
| `< 5.5.0` (legacy archives) | No | Upgrade to the Phase 1 hardened branch |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue containing an exploit, credential, customer record, or private diagnostic report.

Instead, report security concerns privately via email to:
- **Primary Maintainer:** `smartlifeteck@gmail.com`
- **Official Security Contact:** `info@smartlifeteck.com`

Please include:
1. A clear description of the vulnerability and the affected file/module.
2. Steps to reproduce in a test or VM environment.
3. Potential impact and affected Windows / PowerShell versions.
4. Redacted logs or screenshots, if relevant.

We aim to acknowledge all security reports within **72 hours** and coordinate a safe fix before public disclosure.

## Privacy & Responsible Use Guidelines

- **Never commit or share** local `Logs/`, `State/`, `HardwareLock.json`, generated QC reports, `Unattend_*.xml` answer files, customer names, phone numbers, full device serial numbers, or Wi-Fi credentials.
- Review PowerShell scripts before executing them with administrator privileges.
- Test system-modifying workflows (registry tweaks, Appx removal, DISM, Sysprep) inside a VM snapshot before using on production hardware.
- Keep a verified full system backup before running Sysprep or bulk uninstall operations.
