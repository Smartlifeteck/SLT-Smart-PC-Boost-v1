# Phase 1 — Safety and Security Hardening

**Input archive:** `SMART_PC_BOOST.zip`  
**Working source:** `SMART_PC_BOOST_v5.5_FINAL_CMD_OPEN`  
**Scope:** first safety pass only; this is not a complete feature rewrite or production certification.

## Changes applied

### 1. Startup files and shortcuts

- Duplicate-looking files are detected and reported only.
- The startup routine no longer copies a duplicate over an original or deletes it.
- The Public Desktop shortcut is preserved; startup no longer removes or overwrites existing `.lnk`/`.url` shortcuts.
- Package inventory no longer deletes registry keys for entries that merely appear stale; it skips and logs them.
- Scheduled-task registration now exports existing task XML before replacement/deletion, asks for confirmation, and runs the recurring Boost worker from the protected ProgramData folder.
- The startup diagnostic script records duplicate-looking files without changing them.
- Automatic removal of Mark-of-the-Web from PowerShell/EXE/DLL files was removed.

### 2. Hardware inspection and QC integrity

- Removed the embedded default staff PIN. First use now requires the operator to create a local PIN.
- The PIN is stored as a salted PBKDF2 hash, not as plaintext. The local record ACL is restricted to SYSTEM, Administrators, and the current operator.
- The ProgramData app base, logs, and state folders receive restricted ACLs for SYSTEM, Administrators, and the current operator; startup logs a warning if ACL hardening cannot be verified.
- The application now requests UAC elevation before core initialization so machine-wide state-folder protection is applied in the elevated process.
- Hardware values that cannot be read are shown as `Not reported`; sample CPU, RAM, storage, battery, serial, temperature, and activation values are not used as fallback results.
- Physical RAM slot count is not inferred from the number of detected memory modules.
- Generic disk `Healthy` status is not converted into a fabricated `100% SMART` value.
- Battery charge and backup runtime are not assumed or estimated as measured values.
- Serial numbers are masked in report views, report filenames, and preflight exports; network SSID is hidden in the detail view.
- Automatic device detection is labeled `Reported`, not `Passed`.
- QC checks default to `Pending / Not tested`; only explicit, verified pass states display as Passed.
- The bulk `Mark All Pending as Passed` action was replaced with a confirmed `Reset All QC to Pending` action.
- Keyboard Pass is unavailable until all required keys in the selected layout have been detected. Charger Pass requires a selected wattage/type and a completed charging indicator check. Body Pass requires an explicit grade selection.
- Report templates no longer include a fabricated overall score, automatic sale grade, fake health percentages, or false digital-verification claims.

### 3. Optimization safety

- Windows Prefetch and Windows Update download caches are preserved.
- User and Windows temp cleanup is limited to older, unlocked temporary files.
- Empty Recycle Bin now requires a separate confirmation.
- Registry startup entries and string settings are backed up with their registry value types so they can be restored correctly.
- Restore keeps failed backup entries instead of archiving the entire backup after a partial failure.
- Service startup, scheduled-task, pagefile, hibernation, power-plan, and Defender scan-load changes that lacked a verified rollback path are disabled for now.
- Appx removal requires an explicit confirmation that lists the requested package patterns.

### 4. Package manager safety

- Normal package queues no longer remove `Microsoft.WinGet.Source` after every run.
- Generic wildcard Appx cleanup was removed from the generic uninstaller to avoid matching unrelated packages.
- WinGet uninstall no longer adds `--force` by default.

### 5. Public-repository hygiene

- Removed the internal roadmap JSON from the public project package because it contained private Google Drive folder IDs and internal workflow state. A private working backup was kept outside the project ZIP.
- Updated the embedded offer copy to avoid the prohibited product terminology and replaced an unverified fixed price with “Contact for current price.”

### 6. Sysprep, BitLocker, and Unattend

- Sysprep preparation inventories Appx packages but does not remove them automatically.
- Pending reboot markers and Sysprep registry state are inspected, not deleted or forced.
- Windows Update/Store services and user processes are not stopped automatically by the readiness review.
- `manage-bde -off C:` was removed. The OS volume is never decrypted by this workflow.
- Immediately before Sysprep, BitLocker status is checked. If C: is encrypted and protection is On, protection may be suspended for two reboots and the encrypted volume status is verified. If status cannot be verified, Sysprep is not launched. Suspension does not decrypt the volume, but makes the volume key available in clear and temporarily reduces boot-integrity protection; keep physical access controlled and have the recovery key backed up.
- If SLT suspends BitLocker for the run, the shutdown option is required; `/quit` is blocked and protection is resumed before aborting.
- If Sysprep fails to start after SLT suspended BitLocker, the app attempts to resume protection.
- Unattend generation requires a unique temporary password of at least 12 characters. The file is marked as SLT-generated, its ACL is restricted, and the UI password box is cleared after generation.
- Existing external `Panther\\unattend.xml` files are preserved and block Sysprep until reviewed; only files carrying the SLT-generated marker may be replaced or removed by the app.
- Sysprep logs are archived instead of deleted.
- The `/shutdown` versus `/quit` choice now follows the UI option.
- Normal optimization tiers no longer silently run Sysprep preparation or modify the Default User profile.

## Important remaining limitations

- The generated Unattend XML necessarily contains a readable password value because of Windows unattended setup format. File ACLs reduce exposure but do not encrypt the XML. Use a unique temporary password and delete the answer file after deployment.
- The staff PIN is a local application access gate, not a replacement for Windows account security or BitLocker.
- Confirmed Appx removal remains destructive and may affect multiple Windows users or the provisioned image. Review the list and maintain a backup before proceeding.
- Several optimization actions are intentionally disabled until their original service/task/power/pagefile state can be captured and restored reliably.
- The Sysprep workflow depends on Windows BitLocker cmdlets being available to verify the OS volume. If the status cannot be verified, the app stops rather than guessing.
- Some operations still need end-to-end Windows testing, including WPF event handling, registry rollback, Appx removal, WinGet installation/uninstallation, BitLocker suspension/resume, and Sysprep.

## Static validation performed

- All 13 JSON files parsed successfully after edits.
- All 24 PowerShell scripts (including the new Pester test file) passed a rough delimiter/lexical-balance scan.
- Function duplicate scan found no duplicate function declarations.
- Hardcoded PIN/default password patterns and automatic `manage-bde -off`, `Unblock-File`, and automatic duplicate-removal patterns were searched and not found in the relevant source files.

**Not performed:** PowerShell AST parsing, Pester execution, live Windows execution, Windows 10/11 compatibility testing, hardware test runs, or Sysprep image capture/restore. Those are required before calling this a release-ready application.
