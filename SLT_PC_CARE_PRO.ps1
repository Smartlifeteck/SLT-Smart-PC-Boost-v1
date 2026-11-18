# SLT Smart PC Boost v1.0.0 (Windows PowerShell 5.1 WPF)
# Developed by Shahzad Babar | Smart Life Teck (www.smartlifeteck.com)
# Copyright (c) 2026 Smart Life Teck - Developed by Shahzad Babar. MIT Licensed (see LICENSE).
[CmdletBinding()]
param([switch]$DiagnosticOnly)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$script:Root = $PSScriptRoot
if ($null -eq $script:Root -or [string]::IsNullOrWhiteSpace($script:Root)) {
    if ($MyInvocation.MyCommand.Path) {
        $script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $script:Root = (Get-Location).Path
    }
}
if (-not $DiagnosticOnly) {
    $isAdminEarly = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdminEarly) {
        $elevatedEntry = Join-Path $script:Root 'SLT_PC_CARE_PRO.ps1'
        try {
            Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -STA -ExecutionPolicy Bypass -File "' + $elevatedEntry + '"') -Verb RunAs -Wait | Out-Null
        } catch { Write-Warning ('Administrator elevation was cancelled or failed: ' + $_.Exception.Message) }
        return
    }
}
. (Join-Path $script:Root 'core\00-Initialize.ps1')
# Desktop icon is created only when user clicks 'Create Desktop Icon' (Install-SLTLogoLaunchers -CreateDesktopIcon)

if (Get-Command Invoke-SLTMinimizeConsole -ErrorAction SilentlyContinue) { Invoke-SLTMinimizeConsole }
if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'Running with admin rights; console minimised' }

# Security: do not automatically remove Mark-of-the-Web from every script/binary.
# Users should review downloaded files and unblock only trusted files explicitly.

# SLT Smart PC Boost v1.0.0 - Instant Startup Scan: fire the full installed-software
# + laptop/hardware scan off as a silent background process THE MOMENT the app
# starts, in parallel with the splash screen below. By the time the user opens
# the Install tab, the result is usually already cached and ready (see
# tools\Run-SLT-StartupScan.ps1 and Import-SLTStartupScanCache in core\Scan.ps1).
# Fire-and-forget: never allowed to slow down or block app startup.
try {
    $scanWorker = Join-Path $script:Root 'tools\Run-SLT-StartupScan.ps1'
    if (Test-Path -LiteralPath $scanWorker) {
        $swArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $scanWorker + '" -Root "' + $script:Root + '"'
        Start-Process -FilePath 'powershell.exe' -ArgumentList $swArgs -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'Startup scan worker launched in background' }
    }
} catch {}

if (-not $DiagnosticOnly) {
    if (Get-Command New-SLTSplashWindow -ErrorAction SilentlyContinue) { New-SLTSplashWindow | Out-Null }
    if (Get-Command Update-SLTSplashProgress -ErrorAction SilentlyContinue) { Update-SLTSplashProgress 12 'Initializing Smart Life Teck Core Engine' }
}

. (Join-Path $script:Root 'core\10-System.ps1')
. (Join-Path $script:Root 'core\Scan.ps1')
. (Join-Path $script:Root 'core\Install.ps1')
. (Join-Path $script:Root 'core\Uninstall.ps1')
. (Join-Path $script:Root 'core\Notification.ps1')
if (-not $DiagnosticOnly) {
    if (Get-Command Update-SLTSplashProgress -ErrorAction SilentlyContinue) { Update-SLTSplashProgress 24 'Loading System Optimization & Restore Engine' }
}
. (Join-Path $script:Root 'core\11-HardwareInspection.ps1')
if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'Core modules loaded (00/10/11)' }

if($DiagnosticOnly) {
    Get-SLTHardware | Format-List
    Get-SLTBadDrivers | Format-Table -AutoSize
    return
}

if (Get-Command Update-SLTSplashProgress -ErrorAction SilentlyContinue) { Update-SLTSplashProgress 38 'Loading Unified Theme Engine (Emerald Dark)' }
. (Join-Path $script:Root 'core\20-UI-Framework.ps1')
if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'UI framework loaded' }

$splashSteps = @{ '01-Dashboard'=50; '02-Install'=60; '03-ToolsHub'=70; '04-Boost'=80; '05-Backup'=86; '06-HardwareInspection'=93; '07-Support'=98 }
$splashStages = @{ '01-Dashboard'='Loading Dashboard & Live PC Overview'; '02-Install'='Loading Smart Install & Uninstall (203 Official Tools & 18 OS)'; '03-ToolsHub'='Loading Smart Tools Hub (104 Web & AI Tools)'; '04-Boost'='Loading Boost Your PC (Health Fix, Normal, Ultra, Extreme)'; '05-Backup'='Loading Backup & Restore Factory'; '06-HardwareInspection'='Loading Smart Hardware Inspection & A4 QC Suite'; '07-Support'='Loading Smart Life Teck Support & Contact' }
foreach($sltPageName in @(
  '01-Dashboard','02-Install','03-ToolsHub','04-Boost','05-Backup',
  '06-HardwareInspection','07-Support'
)) {
    if ($null -eq $script:Root -or [string]::IsNullOrWhiteSpace($script:Root)) {
        $script:Root = $PSScriptRoot
    }
    . (Join-Path $script:Root ('pages\'+$sltPageName+'.ps1'))
    if (Get-Command Update-SLTSplashProgress -ErrorAction SilentlyContinue) { Update-SLTSplashProgress $splashSteps[$sltPageName] $splashStages[$sltPageName] }
    if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage ('Page loaded: ' + $sltPageName) }
}
if (Get-Command Update-SLTSplashProgress -ErrorAction SilentlyContinue) { Update-SLTSplashProgress 100 'Ready! Opening SLT Smart PC Boost' }
if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'All pages loaded - opening main window' }
try { [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers() } catch {}
if ($null -eq $script:Root -or [string]::IsNullOrWhiteSpace($script:Root)) {
    $script:Root = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }
}
. (Join-Path $script:Root 'core\90-Run-Window.ps1')
