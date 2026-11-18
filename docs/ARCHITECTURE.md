# SLT Smart PC Boost — System Architecture

SLT Smart PC Boost is built as a zero-compile, transparent **Windows PowerShell 5.1 + WPF/XAML** modular desktop application. This guide helps contributors, educators, and students navigate the codebase.

## Directory Layout

```text
SLT-Smart-PC-Boost-v1/
├── RUN_SMART_PC_BOOST.cmd        # Single-click Windows launcher
├── START_SLT_DIAGNOSTIC.ps1      # Resilient startup wrapper & crash reporter
├── SLT_PC_CARE_PRO.ps1           # Main entrypoint (UAC check, module loader, splash)
├── core/                         # Core runtime & engines
│   ├── 00-Initialize.ps1         # ProgramData paths, NTFS ACL hardening, logging, splash
│   ├── 10-System.ps1             # System tweaks, typed registry backup/restore, BitLocker/Sysprep helpers
│   ├── 11-HardwareInspection.ps1 # Hardware telemetry, PBKDF2 PIN auth, QC gates, A4 HTML/Excel reports
│   ├── 20-UI-Framework.ps1       # WPF XAML loader, theme switcher, shared UI helpers
│   ├── 90-Run-Window.ps1         # Main window lifecycle & event loop
│   ├── Scan.ps1                  # Installed software & startup scan cache importer
│   ├── Install.ps1               # Package installation coordinator
│   ├── Uninstall.ps1             # Safe package uninstallation coordinator
│   └── Notification.ps1          # In-app toast & status notifications
├── pages/                        # 7 modular WPF desktop views
│   ├── 01-Dashboard.ps1
│   ├── 02-Install.ps1
│   ├── 03-ToolsHub.ps1
│   ├── 04-Boost.ps1
│   ├── 05-Backup.ps1
│   ├── 06-HardwareInspection.ps1
│   └── 07-Support.ps1
├── tools/                        # Isolated background worker scripts
│   ├── Run-SLT-StartupScan.ps1   # Background software/hardware scan on launch
│   ├── Run-SLT-Packages.ps1      # Asynchronous WinGet/package queue runner
│   ├── Run-SLT-Boost.ps1         # Optimization & auto-maintenance worker
│   ├── Invoke-SLT-Features.ps1   # Windows optional feature helper
│   └── Invoke-SLT-ComponentCleanup.ps1
├── config/                       # Declarative UI, branding, & policy JSON
├── data/                         # Curated catalogs (208 apps, 68 tweaks, 33 features)
├── ui/Main.xaml                  # Master WPF window layout
├── assets/                       # Brand emblems, app icon, offline HTML tools hub
├── tests/                        # Pester 5 static safety & repository integrity tests
├── docs/                         # Security hardening, architecture, and roadmap docs
└── .github/                      # GitHub Actions CI workflow & Issue/PR templates
```

## Key Design Patterns

1. **Separated Entry & Crash Resilience:** `START_SLT_DIAGNOSTIC.ps1` wraps `SLT_PC_CARE_PRO.ps1` so any startup failure restores the console, copies a structured diagnostic trace to the clipboard, and writes a timestamped log to `%ProgramData%\\SmartLifeTeck\PCCarePro\Logs`.
2. **Asynchronous Background Workers:** Heavy tasks (initial software scan, WinGet queues, optimization passes) run in isolated child PowerShell processes under `tools/` communicating via JSON manifests in `State/`, keeping the WPF STA UI responsive.
3. **Declarative JSON Catalogs:** Software lists (`data/applications.json`), optimization definitions (`data/tweaks.json`), themes (`config/themes.json`), and branding (`config/brand.json`) are decoupled from PowerShell logic so contributors can safely extend catalogs without editing core code.
4. **Defense-in-Depth State Protection:** Machine-wide logs, PIN hashes, and rollback backups live under `%ProgramData%\\SmartLifeTeck\PCCarePro` with explicit NTFS ACLs restricting write access to `SYSTEM`, `BUILTIN\Administrators`, and the invoking operator.
