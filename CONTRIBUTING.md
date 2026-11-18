# Contributing to SLT Smart PC Boost

Thank you for your interest in contributing to **SLT Smart PC Boost**! Whether you are an experienced Windows PowerShell engineer, a WPF designer, an IT technician, or a student learning open-source development, your contributions are welcome.

## Ways to Contribute

- **Bug Reports:** Found an issue on Windows 10 or Windows 11? Open a structured [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml).
- **Feature Requests & Catalog Additions:** Suggest safe new diagnostic checks, verified WinGet apps for `data/applications.json`, or UI/accessibility improvements.
- **Educational Documentation & Localization:** Help expand `docs/`, write step-by-step tutorials for IT learners, or help prepare English/Urdu/Arabic localization.
- **Testing on Physical Hardware:** Run Pester tests and manual Windows 10/11 test matrices (battery/no-battery, NVMe/SATA, standard user vs. admin) and share redacted results.

## Development Setup

1. **Fork** this repository on GitHub and clone your fork locally:
   ```powershell
   git clone https://github.com/Smartlifeteck/SLT-Smart-PC-Boost-v1.git
   cd SLT-Smart-PC-Boost-v1
   ```
2. **Create a feature branch:**
   ```powershell
   git checkout -b feat/your-feature-name
   ```
3. **Install Pester 5** (required for automated safety checks):
   ```powershell
   Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force
   ```
4. **Run the full test suite before and after your changes:**
   ```powershell
   Invoke-Pester -Path .\tests\ -Output Detailed
   ```

## Mandatory Safety & Coding Standards

Every pull request MUST preserve our **Phase 1 Safety Invariants** (enforced automatically by CI):

1. **No Hardcoded Secrets or Default PINs:** Never commit API keys, passwords, default PINs, or private URLs/Drive IDs.
2. **No Silent Destructive Actions:** Never auto-delete user files, Desktop shortcuts, Prefetch, Windows Update caches, or BitLocker encryption (`manage-bde -off` is strictly prohibited).
3. **Reversible State Changes:** Any registry or system tweak must record its original state and type so it can be cleanly rolled back.
4. **Truthful Hardware Telemetry:** Unknown values must display `Not reported`; incomplete manual QC checks must remain `Pending / Not tested`.
5. **Valid PowerShell 5.1 & JSON:** All `.ps1` files must parse cleanly under Windows PowerShell 5.1 (`Set-StrictMode -Version 2.0`), and all `config/*.json` / `data/*.json` files must be valid UTF-8 JSON.

## Submitting a Pull Request

1. Ensure all tests in `tests/` pass locally.
2. Keep PRs focused on a single logical change.
3. Fill out the Pull Request template completely, including how you tested on Windows.
4. All contributions are licensed under the project's [MIT License](LICENSE).

## Maintainer Contact

Questions? Reach out via GitHub Discussions or contact **Shahzad Babar** at `smartlifeteck@gmail.com` / `info@smartlifeteck.com`.
