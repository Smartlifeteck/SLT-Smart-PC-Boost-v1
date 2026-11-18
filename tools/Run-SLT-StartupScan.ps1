# SLT Smart PC Boost v1.0.0 - Headless Startup Scan Worker
# Powered by Smart Life Teck | Developed by Shahzad Babar
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Root)

$ErrorActionPreference = 'Continue'
try { [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
Start-Sleep -Milliseconds 3000
$script:Root = $Root
$script:Base = Join-Path $env:ProgramData 'SmartLifeTeck\PCCarePro'
$script:LogDir = Join-Path $script:Base 'Logs'
$script:StateDir = Join-Path $script:Base 'State'
foreach ($d in @($script:Base, $script:LogDir, $script:StateDir)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
$script:LogFile = Join-Path $script:LogDir ('Care_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$script:LogBox = $null

$lockFile  = Join-Path $script:StateDir 'SLT_StartupScan.lock'
$legacyCache = Join-Path $script:StateDir 'SLT_StartupScanCache.json'
$cacheFile = Join-Path $script:StateDir 'SLT_StartupScanCache_v553.json'

try {
    if (Test-Path -LiteralPath $legacyCache) {
        Remove-Item -LiteralPath $legacyCache -Force -ErrorAction SilentlyContinue
    }
    'running' | Set-Content -LiteralPath $lockFile -Encoding UTF8 -Force

    . (Join-Path $script:Root 'core\10-System.ps1')
    . (Join-Path $script:Root 'core\Scan.ps1')

    $catalog = Get-SLTAppCatalogRecords $script:Root
    $script:AppRecords    = $catalog.AppRecords
    $script:AppIndex      = $catalog.AppIndex
    $script:WebOnlyKeys   = $catalog.WebOnlyKeys
    $script:EssentialKeys = $catalog.EssentialKeys

    $script:Window = $null
    $script:CatalogInfo = $null
    $script:UninstallCountsHeader = $null
    $script:AsyncScanProc = $null
    $script:AsyncScanTimer = $null
    $script:PrecomputedAppMatchList = $null
    $script:PrecomputedWingetMap = $null
    $script:RealScanAllApps = @()
    $script:RealScanSltApps = @()
    $script:RealScanCustomerApps = @()
    $script:RealScanWindowsApps = @()
    $script:ScannedInstalledApps = @{}
    $script:RealRegRawCount = 0
    $script:TotalPcInstalledCount = 0
    $script:ScanCompletedOnce = $false
    $script:SelectedApps = @{}
    $script:SelectedUninstallApps = @{}
    $script:UninstallSelectedMap = @{}

    Get-RealInstalledApps -QuickRegistryOnly:$false

    $laptop = Get-SLTHardware

    $scannedKeys = New-Object System.Collections.Generic.List[object]
    foreach ($k in @($script:ScannedInstalledApps.Keys)) {
        $v = $script:ScannedInstalledApps[$k]
        $scannedKeys.Add([ordered]@{
            key     = [string]$k
            version = [string]$v.Version
            source  = [string]$v.Source
        })
    }

    $payload = [ordered]@{
        timestamp    = (Get-Date -Format 's')
        laptop       = $laptop
        sltApps      = @($script:RealScanSltApps)
        customerApps = @($script:RealScanCustomerApps)
        windowsApps  = @($script:RealScanWindowsApps)
        scannedKeys  = @($scannedKeys.ToArray())
    }

    if (@($script:RealScanAllApps).Count -gt 0) {
        $tmp = $cacheFile + '.tmp'
        $payload | ConvertTo-Json -Depth 8 -Compress | Set-Content -LiteralPath $tmp -Encoding UTF8
        Copy-Item -LiteralPath $tmp -Destination $cacheFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }

    Log-SLT ("Startup scan worker finished: {0} app(s) found on {1} {2} (Serial {3})." -f @($script:RealScanAllApps).Count, $laptop.Maker, $laptop.Model, $laptop.Serial)
} catch {
    try { Log-SLT ('Startup scan worker FAILED: ' + $_.Exception.Message) } catch {}
} finally {
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
}
