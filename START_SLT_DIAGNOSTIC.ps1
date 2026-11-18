# SLT Smart PC Boost v1.0.0 - Resilient Startup Diagnostic & Fast Launcher
# Powered by Smart Life Teck | Developed by Shahzad Babar
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if ($null -eq $root -or [string]::IsNullOrWhiteSpace($root)) {
    if ($MyInvocation.MyCommand.Path) {
        $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
}
if ($null -eq $root -or [string]::IsNullOrWhiteSpace($root)) {
    $root = (Get-Location).Path
}
$stageFile = if ($null -ne $root -and -not [string]::IsNullOrWhiteSpace($root)) { Join-Path $root 'STARTUP_DIAGNOSTIC.txt' } else { 'STARTUP_DIAGNOSTIC.txt' }
try { Add-Content -LiteralPath $stageFile -Value ('SLT Smart PC Boost startup diagnostic - started ' + (Get-Date).ToString('s') + ' - folder: ' + $root) -ErrorAction SilentlyContinue } catch {}

# Ensure Big-Logo Launcher inside the App Folder ONLY (Never auto-create Desktop icons on launch!)
try {
    if ($null -ne $root -and -not [string]::IsNullOrWhiteSpace($root) -and (Test-Path -LiteralPath $root)) {
        # Preserve existing user/Public Desktop shortcuts; never delete them on launch.

        $srcIco = Join-Path $root 'assets\SLT_PC_CARE_PRO.ico'
        $bestIco = $srcIco
        try {
            $progIcoDir = Join-Path $env:ProgramData 'SmartLifeTeck\PCCarePro\Icons'
            New-Item -ItemType Directory -Path $progIcoDir -Force -ErrorAction SilentlyContinue | Out-Null
            $progIco = Join-Path $progIcoDir 'SLT_PC_CARE_PRO.ico'
            if (Test-Path -LiteralPath $srcIco) {
                Copy-Item -LiteralPath $srcIco -Destination $progIco -Force -ErrorAction Stop
                $bestIco = $progIco
            }
        } catch {}
        $diagPath = Join-Path $root 'START_SLT_DIAGNOSTIC.ps1'
        $folderLnk = Join-Path $root 'SMART PC BOOST.lnk'
        if (-not (Test-Path -LiteralPath $folderLnk)) {
            $wsh = New-Object -ComObject WScript.Shell
            $sc = $wsh.CreateShortcut($folderLnk)
            $sc.TargetPath = 'powershell.exe'
            $sc.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $diagPath + '"'
            $sc.WorkingDirectory = $root
            if (Test-Path -LiteralPath $bestIco) { $sc.IconLocation = ($bestIco + ',0') }
            $sc.Description = 'Run SLT Smart PC Boost - Powered by Smart Life Teck | Developed by Shahzad Babar'
            $sc.Save()
        } else {
            Add-Content -LiteralPath $stageFile -Value 'Existing app-folder launcher preserved.' -ErrorAction SilentlyContinue
        }
    }
} catch {}

try {
    if ($null -eq $root -or [string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
        $root = if ($null -ne $PSScriptRoot -and -not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }
    }
    if ($null -eq $root -or [string]::IsNullOrWhiteSpace($root)) {
        throw 'Application root folder ($root) is null before Join-Path.'
    }
    # Detect downloaded duplicate files for diagnostics only. Never overwrite or delete user files.
    try {
        $rootDups = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -match '^(.+?)\s*\((\d+)\)$' })
        if ($rootDups.Count -gt 0) {
            Add-Content -LiteralPath $stageFile -Value ('Duplicate-looking files detected (left untouched): ' + (($rootDups | ForEach-Object Name) -join ', ')) -ErrorAction SilentlyContinue
        }
    } catch {}
    $mainEntry = Join-Path $root 'SLT_PC_CARE_PRO.ps1'
    if (-not (Test-Path -LiteralPath $mainEntry)) {
        throw ('Main entrypoint not found at: ' + $mainEntry)
    }
    & $mainEntry
} catch {
    $e = $_
    if ($null -eq $root -or [string]::IsNullOrWhiteSpace($root)) {
        $root = if ($null -ne $PSScriptRoot -and -not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }
    }
    try {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; namespace SLT { public static class SLTConsoleRestore { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); } }' -ErrorAction SilentlyContinue
        $ch = [SLT.SLTConsoleRestore]::GetConsoleWindow()
        if ($ch -ne [IntPtr]::Zero) { [void][SLT.SLTConsoleRestore]::ShowWindow($ch, 9) }
    } catch {}
    try {
        if (Get-Command Close-SLTSplash -ErrorAction SilentlyContinue) { Close-SLTSplash }
    } catch {}
    $stagesTxt = if ($null -ne $stageFile -and -not [string]::IsNullOrWhiteSpace($stageFile) -and (Test-Path -LiteralPath $stageFile)) { ([IO.File]::ReadAllText($stageFile)).Trim() } else { '' }
    $errLineTxt = if ($e.InvocationInfo -and $e.InvocationInfo.Line) { ($e.InvocationInfo.Line).Trim() } else { '' }
    $report = @(
        '=== SLT Smart PC Boost STARTUP ERROR (SHARE THIS FILE ONLY) ==='
        ('When: ' + (Get-Date).ToString('s'))
        ('Message: ' + $e.Exception.Message)
        ('Type: ' + $e.Exception.GetType().FullName)
        ('Source: ' + $e.InvocationInfo.ScriptName)
        ('Line: ' + $e.InvocationInfo.ScriptLineNumber)
        ('Code: ' + $errLineTxt)
        ('Position: ' + $e.InvocationInfo.PositionMessage)
        ('Stack: ' + $e.ScriptStackTrace)
        '--- STARTUP STAGES ---'
        $stagesTxt
    ) -join [Environment]::NewLine
    try { Set-Clipboard -Value $report -ErrorAction SilentlyContinue } catch {}
    $folder = 'C:\ProgramData\SmartLifeTeck\PCCarePro\Logs'
    try {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $file = Join-Path $folder ('STARTUP_ERROR_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
        [IO.File]::WriteAllText($file, $report)
        Write-Host ('Diagnostic saved: ' + $file) -ForegroundColor Yellow
    } catch {
        if ($null -ne $root -and -not [string]::IsNullOrWhiteSpace($root)) {
            $file = Join-Path $root ('STARTUP_ERROR_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
            try { [IO.File]::WriteAllText($file, $report) } catch {}
            Write-Host ('Diagnostic fallback: ' + $file) -ForegroundColor Yellow
        }
    }
    if ($null -ne $root -and -not [string]::IsNullOrWhiteSpace($root)) {
        try { [IO.File]::WriteAllText((Join-Path $root 'STARTUP_ERROR.txt'), $report) } catch {}
    }
    if ($null -ne $stageFile -and -not [string]::IsNullOrWhiteSpace($stageFile)) {
        try { Add-Content -LiteralPath $stageFile -Value ('FAILED: ' + $e.Exception.Message) -ErrorAction SilentlyContinue } catch {}
    }
    Write-Host $report -ForegroundColor Red
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [void][System.Windows.Forms.MessageBox]::Show(($e.Exception.Message + "`n`n(Copied to Clipboard! Full details saved in STARTUP_ERROR.txt and C:\ProgramData\SmartLifeTeck\PCCarePro\Logs)"), 'SLT Smart PC Boost - Startup Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } catch {}
    exit 1
}
