# ==============================================================================
# core/Scan.ps1
# SLT Smart PC Boost v1.0.0 - Real PC Installed Apps Scanner (Non-Blocking Async + Sync)
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# ==============================================================================

function Test-SLTCriticalHiddenApp([string]$DisplayName, [string]$Publisher) {
    $n = ([string]$DisplayName).ToLowerInvariant()
    $p = ([string]$Publisher).ToLowerInvariant()

    $critPatterns = @(
        'webview2', 'microsoft edge', 'windows store', 'microsoft.windowsstore',
        'vclibs', 'microsoft.vclibs', 'windows app runtime', 'windowsappruntime',
        'windows security', 'defender', 'sechealthui', 'windows terminal', 'microsoft.windowsterminal',
        'microsoft.ui.xaml', 'microsoft.net.native', 'microsoft.services.store',
        'shellexperiencehost', 'startmenuexperiencehost', 'cloudexperiencehost',
        'contentdeliverymanager', 'aad.brokerplugin', 'bioenrollment', 'cbspreview',
        'printdialog', 'lockapp', 'win32webviewhost', 'accountscontrol',
        'asynctextservice', 'creddialoghost', 'ecapp', 'oobee', 'oobenetwork',
        'parentalcontrols', 'pinningconfirmation', 'xgpuejectdialog', 'undockeddevkit',
        'microsoftwindows.client', 'ncsiuwpapp', 'desktopappinstaller',
        '.net runtime', '.net desktop runtime', '.net core', 'asp.net',
        'universal crt', 'msvc', 'visual c++', 'vcredist', 'system settings', 'windows settings',
        'application compatibility', 'windows sdk', 'windows software development kit',
        'winget.source', 'xboxgameoverlay', 'xbox bar overlay', 'xbox game bar overlay',
        'xboxidentityprovider', 'xbox identity provider', 'xboxspeechtotextoverlay',
        'xbox speech to text', 'xbox.tcui', 'xbox tcui', 'gamebarplugin'
    )
    foreach ($cp in $critPatterns) {
        if ($n.Contains($cp)) { return $true }
    }
    if (($p.Contains('microsoft') -or $p -eq '') -and ($n -match '(\.net runtime|\.net desktop runtime|\.net core|asp\.net|windows software development kit|universal crt|msvc|click-to-run|office 16 click-to-run|system settings|windows settings|application compatibility)')) {
        return $true
    }
    return $false
}

function Test-SLTWindowsBloatwareApp([string]$DisplayName, [string]$Publisher, [string]$AppxName) {
    $combined = ($DisplayName + ' ' + $AppxName).ToLowerInvariant()
    $winBloatPatterns = @(
        'clipchamp', 'xbox', 'gamingapp', 'solitaire', 'mixedreality', 'mixed reality',
        'microsoft.people', 'windowsmaps', 'windows maps', 'cortana', '549981c3f5f10',
        'gethelp', 'get help', 'microsoft.getstarted', 'microsoft tips',
        'bingweather', 'msn weather', 'bingnews', 'microsoft news',
        'microsoftofficehub', 'office hub', 'mspaint', 'paint 3d', '3dviewer', '3d viewer',
        'skypeapp', 'skype', 'zunemusic', 'zunevideo', 'zune', 'windowsfeedbackhub',
        'feedback hub', 'yourphone', 'phone link', 'microsoftstickynotes', 'sticky notes',
        'microsoft.todos', 'microsoft to do', 'soundrecorder', 'windowsalarms',
        'windowscamera', 'windowscommunicationsapps', 'bingfinance', 'bingsports',
        'powerautomatedesktop', 'onenote', 'msteams', 'microsoftteams',
        'outlookforwindows', 'windows.devhome', 'quickassist', 'microsoftfamily', 'copilot'
    )
    foreach ($wb in $winBloatPatterns) {
        if ($combined.Contains($wb)) { return $true }
    }
    return $false
}

function Format-SLTFriendlyWindowsAppName([string]$RawName) {
    $map = @{
        'clipchamp.clipchamp'                   = 'Clipchamp Video Editor'
        'microsoft.gamingapp'                   = 'Xbox App'
        'microsoft.xboxgamingoverlay'           = 'Xbox Game Bar'
        'microsoft.xboxgameoverlay'             = 'Xbox Game Bar Overlay'
        'microsoft.xboxidentityprovider'        = 'Xbox Identity Provider'
        'microsoft.xboxspeechtotextoverlay'     = 'Xbox Speech To Text Overlay'
        'microsoft.xbox.tcui'                   = 'Xbox TCUI Companion'
        'microsoft.microsoftsolitairecollection'= 'Microsoft Solitaire Collection'
        'microsoft.mixedreality.portal'         = 'Mixed Reality Portal'
        'microsoft.people'                      = 'Microsoft People'
        'microsoft.windowsmaps'                 = 'Windows Maps'
        'microsoft.549981c3f5f10'               = 'Cortana'
        'microsoft.gethelp'                     = 'Microsoft Get Help'
        'microsoft.getstarted'                  = 'Microsoft Tips (Get Started)'
        'microsoft.bingweather'                 = 'MSN Weather'
        'microsoft.bingnews'                    = 'Microsoft News'
        'microsoft.microsoftofficehub'          = 'Microsoft Office Hub'
        'microsoft.mspaint'                     = 'Paint 3D'
        'microsoft.microsoft3dviewer'           = '3D Viewer'
        'microsoft.skypeapp'                    = 'Skype'
        'microsoft.zunemusic'                   = 'Media Player / Groove Music (ZuneMusic)'
        'microsoft.zunevideo'                   = 'Movies & TV (ZuneVideo)'
        'microsoft.windowsfeedbackhub'          = 'Windows Feedback Hub'
        'microsoft.yourphone'                   = 'Phone Link (Your Phone)'
        'microsoft.microsoftstickynotes'        = 'Microsoft Sticky Notes'
        'microsoft.todos'                       = 'Microsoft To Do'
        'microsoft.windowssoundrecorder'        = 'Windows Sound Recorder'
        'microsoft.windowsalarms'               = 'Windows Alarms & Clock'
        'microsoft.windowscamera'               = 'Windows Camera'
        'microsoft.windowscommunicationsapps'   = 'Windows Mail & Calendar'
        'microsoft.powerautomatedesktop'        = 'Power Automate Desktop'
        'microsoft.office.onenote'              = 'OneNote for Windows'
    }
    $low = $RawName.Trim().ToLowerInvariant()
    if ($map.ContainsKey($low)) { return $map[$low] }
    return $RawName
}

function Read-SLTTempTextShared([string]$FilePath) {
    if ([string]::IsNullOrWhiteSpace($FilePath) -or (-not (Test-Path -LiteralPath $FilePath))) { return '' }
    try {
        $fs = New-Object System.IO.FileStream($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
        $txt = $sr.ReadToEnd()
        $sr.Close()
        $fs.Close()
        return $txt
    } catch {
        return ''
    }
}

function Test-SLTRegistryEntryExistsOnDisk([string]$UninstallString, [string]$QuietUninstall, [string]$InstallLocation = '') {
    try {
        $instLoc = [Environment]::ExpandEnvironmentVariables(([string]$InstallLocation).Trim().Trim('"'))
        if (-not [string]::IsNullOrWhiteSpace($instLoc) -and $instLoc.Length -gt 3) {
            try { if (Test-Path -LiteralPath $instLoc -ErrorAction SilentlyContinue) { return $true } } catch {}
        }
        foreach ($cmdStr in @($QuietUninstall, $UninstallString)) {
            $raw = [Environment]::ExpandEnvironmentVariables(([string]$cmdStr).Trim())
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            if ($raw -match '(?i)(msiexec|rundll32|cmd\.exe|powershell)' -or $raw -match '\{[0-9A-Fa-f\-]{36}\}') { return $true }
            if ($raw.StartsWith('"')) {
                $qEnd = $raw.IndexOf('"', 1)
                if ($qEnd -gt 1) {
                    $exeP = $raw.Substring(1, $qEnd - 1).Trim()
                    if ($exeP -match '^[A-Za-z]:\\') {
                        try {
                            if (Test-Path -LiteralPath $exeP -ErrorAction SilentlyContinue) { return $true }
                            $parentDir = Split-Path -Parent $exeP -ErrorAction SilentlyContinue
                            if (-not [string]::IsNullOrWhiteSpace($parentDir) -and (Test-Path -LiteralPath $parentDir -ErrorAction SilentlyContinue)) { return $true }
                            return $false
                        } catch { return $true }
                    }
                }
            }
            $mExe = [regex]::Match($raw, '^([A-Za-z]:\\[^"*?<>|]+?\.exe)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($mExe.Success) {
                $exeP2 = $mExe.Groups[1].Value.Trim()
                try {
                    if (Test-Path -LiteralPath $exeP2 -ErrorAction SilentlyContinue) { return $true }
                    $parentDir2 = Split-Path -Parent $exeP2 -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($parentDir2) -and (Test-Path -LiteralPath $parentDir2 -ErrorAction SilentlyContinue)) { return $true }
                    return $false
                } catch { return $true }
            }
        }
        return $true
    } catch {
        return $true
    }
}

function Test-SLTIsGenuineInstalledApp {
    param(
        [string]$Name,
        [string]$Publisher,
        [string]$Version,
        [string]$IdOrChild,
        [string]$Source,
        [string]$UninstallString = '',
        [string]$QuietUninstall = ''
    )
    $n  = ([string]$Name).Trim()
    $p  = ([string]$Publisher).Trim()
    $v  = ([string]$Version).Trim()
    $id = ([string]$IdOrChild).Trim()

    if ([string]::IsNullOrWhiteSpace($n) -or $n.Length -lt 2) { return $false }
    if ($n.StartsWith('-') -or $n.StartsWith('--')) { return $false }
    if ($Source -eq 'WinGet' -and ($n.Contains('--') -or $n -match '(^|[\s,])-[a-zA-Z\?]')) { return $false }
    if ($n -match '^(?i)(Name|Id|Version|Available|Source|The following|Usage:|winget\b|Unrecognized|Copyright|---|-\?|--help|No installed package|Failed)') {
        return $false
    }
    if ($p -eq 'WinGet Package' -and ($v -eq 'Installed' -or [string]::IsNullOrWhiteSpace($v) -or $v -eq 'Unknown')) {
        return $false
    }
    if ($p -eq 'Unknown Publisher' -and ($v -eq 'Installed' -or [string]::IsNullOrWhiteSpace($v) -or $v -eq 'Unknown')) {
        return $false
    }

    if ($Source -eq 'WinGet') {
        if ([string]::IsNullOrWhiteSpace($id) -or $id.StartsWith('-') -or $id.Contains('--') -or $id -match '\s') {
            return $false
        }
        if ($id -match '^(?i)(ARP\\|MSIX\\)') {
            return $false
        }
        if (-not $id.Contains('.')) {
            return $false
        }
        if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+\-]*\.[A-Za-z0-9._+\-]+$') {
            return $false
        }
        if ([string]::IsNullOrWhiteSpace($v) -or $v -eq 'Installed' -or $v -eq 'Unknown' -or $v -notmatch '^\d' -or $v -match '\s{2,}') {
            return $false
        }
        if ([string]::IsNullOrWhiteSpace($p) -or $p -eq 'WinGet Package' -or $p -eq 'Unknown Publisher') {
            return $false
        }
        return $true
    }

    if ($Source -eq 'Registry') {
        if ($p -eq 'WinGet Package') { return $false }
        if ([string]::IsNullOrWhiteSpace($UninstallString) -and [string]::IsNullOrWhiteSpace($QuietUninstall)) {
            return $false
        }
        if (-not (Test-SLTRegistryEntryExistsOnDisk -UninstallString $UninstallString -QuietUninstall $QuietUninstall)) {
            return $false
        }
        return $true
    }

    return $true
}

function ConvertFrom-SLTWinGetListOutput([string]$RawText) {
    $results = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($RawText)) { return $results.ToArray() }

    $cleanText = [regex]::Replace($RawText, '\x1B\[[0-9;]*[A-Za-z]', '')
    $lines = @($cleanText -split "`r?`n")

    $sepIdx = -1
    $hdrLine = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match '^\s*-{10,}\s*$') {
            $sepIdx = $i
            if ($i -gt 0) { $hdrLine = $lines[$i - 1] }
            break
        }
    }

    if ($sepIdx -lt 0) { return $results.ToArray() }

    $idCol  = -1
    $verCol = -1
    if (-not [string]::IsNullOrWhiteSpace($hdrLine)) {
        $mId  = [regex]::Match($hdrLine, '(?<=\s)Id(?=\s)')
        $mVer = [regex]::Match($hdrLine, '(?<=\s)Version(?=\s|$)')
        if ($mId.Success)  { $idCol = $mId.Index }
        if ($mVer.Success) { $verCol = $mVer.Index }
    }

    for ($j = $sepIdx + 1; $j -lt $lines.Count; $j++) {
        $rawLine = $lines[$j]
        if ([string]::IsNullOrWhiteSpace($rawLine)) { continue }
        $trimmed = $rawLine.Trim()
        if ($trimmed.Length -lt 8) { continue }
        if ($trimmed.StartsWith('-') -or $trimmed.StartsWith('--') -or $trimmed.Contains('--')) { continue }

        $wName = ''
        $wId   = ''
        $wVer  = ''

        if ($idCol -gt 0 -and $verCol -gt $idCol -and $rawLine.Length -gt $verCol) {
            $wName = $rawLine.Substring(0, $idCol).Trim()
            $wId   = $rawLine.Substring($idCol, ($verCol - $idCol)).Trim()
            $afterVer = $rawLine.Substring($verCol).Trim()
            $verTokens = @($afterVer -split '\s+')
            if ($verTokens.Count -ge 1) {
                $wVer = $verTokens[0].Trim()
                if (($wVer -eq '>' -or $wVer -eq '<') -and $verTokens.Count -ge 2) {
                    $wVer = $verTokens[1].Trim()
                }
            }
        } else {
            $parts = @($trimmed -split '\s{2,}')
            if ($parts.Count -ge 3) {
                $wName = $parts[0].Trim()
                $wId   = $parts[1].Trim()
                $wVer  = ($parts[2].Trim() -split '\s+')[0]
            }
        }

        if ([string]::IsNullOrWhiteSpace($wName) -or [string]::IsNullOrWhiteSpace($wId) -or [string]::IsNullOrWhiteSpace($wVer)) {
            continue
        }

        $vendor = ($wId -split '\.')[0].Trim()
        if ($null -ne $script:AppRecords) {
            foreach ($rec in $script:AppRecords) {
                if (([string]$rec.Winget).Equals($wId, [System.StringComparison]::OrdinalIgnoreCase) -and -not [string]::IsNullOrWhiteSpace([string]$rec.Publisher)) {
                    $vendor = ([string]$rec.Publisher).Trim()
                    break
                }
            }
        }
        if ([string]::IsNullOrWhiteSpace($vendor) -or $vendor -in @('ARP','MSIX','WinGet')) { continue }

        if (Test-SLTIsGenuineInstalledApp -Name $wName -Publisher $vendor -Version $wVer -IdOrChild $wId -Source 'WinGet') {
            $results.Add([pscustomobject]@{
                Name      = $wName
                Id        = $wId
                Version   = $wVer
                Publisher = $vendor
            })
        }
    }

    return $results.ToArray()
}

function Invoke-SLTUpdateAllScanUIs {
    try { if (Get-Command Update-SLTStatusLine -ErrorAction SilentlyContinue) { Update-SLTStatusLine } } catch {}
    try { if (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue) { Render-SLTAppCatalog } } catch {}
    try { if (Get-Command Update-SLTInstallCounter -ErrorAction SilentlyContinue) { Update-SLTInstallCounter } } catch {}
    try { if (Get-Command Render-SLTUninstallModeView -ErrorAction SilentlyContinue) { Render-SLTUninstallModeView } } catch {}
    try { if (Get-Command Update-SLTUninstallCounter -ErrorAction SilentlyContinue) { Update-SLTUninstallCounter } } catch {}
}

function Start-SLTAsyncRealScan {
    # Non-blocking background scan (Registry + winget list + Get-AppxPackage) so UI NEVER hangs!
    try {
        if ($null -eq $script:Root -or $null -eq $script:StateDir) { return }
        $scanWorker = Join-Path $script:Root 'tools\Run-SLT-StartupScan.ps1'
        # Uses tools/Run-SLT-StartupScan.ps1 directly from workspace
        if (-not (Test-Path -LiteralPath $scanWorker)) { return }

        $cacheFile = Join-Path $script:StateDir 'SLT_StartupScanCache_v553.json'
        $lockFile  = Join-Path $script:StateDir 'SLT_StartupScan.lock'

        # Do not spawn duplicate worker if one is already running (<25s old)
        if ($null -ne $script:AsyncScanProc -and (-not $script:AsyncScanProc.HasExited)) {
            return
        }

        if ($null -ne $script:CatalogInfo) {
            $script:CatalogInfo.Text = 'Refreshing live installed apps in background (Registry + WinGet + Store)...'
        }
        if ($null -ne $script:UninstallCountsHeader) {
            $script:UninstallCountsHeader.Text = ("Refreshing Live PC Scan...   |   Current Total: {0}" -f @($script:RealScanAllApps).Count)
        }

        $script:AsyncScanStartStamp = (Get-Date).AddSeconds(-1)
        $swArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $scanWorker + '" -Root "' + $script:Root + '"'
        $script:AsyncScanProc = Start-Process -FilePath 'powershell.exe' -ArgumentList $swArgs -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue

        if ($null -eq $script:AsyncScanTimer) {
            $script:AsyncScanTimer = New-Object Windows.Threading.DispatcherTimer
            $script:AsyncScanTimer.Interval = [TimeSpan]::FromMilliseconds(400)
            $script:AsyncScanTimer.Add_Tick({
                try {
                    $cFile = Join-Path $script:StateDir 'SLT_StartupScanCache_v553.json'
                    $lFile = Join-Path $script:StateDir 'SLT_StartupScan.lock'
                    $procDone = ($null -eq $script:AsyncScanProc -or $script:AsyncScanProc.HasExited)
                    if ($procDone -and (-not (Test-Path -LiteralPath $lFile))) {
                        $script:AsyncScanTimer.Stop()
                        if (Test-Path -LiteralPath $cFile) {
                            [void](Import-SLTStartupScanCache)
                            Invoke-SLTUpdateAllScanUIs
                        } else {
                            Invoke-SLTUpdateAllScanUIs
                        }
                    }
                } catch {
                    try { $script:AsyncScanTimer.Stop() } catch {}
                }
            })
        }
        $script:AsyncScanTimer.Start()
    } catch {}
}

function Get-RealInstalledApps([switch]$OpenModal, [switch]$QuickRegistryOnly, [switch]$AsyncBackground) {
    $oldScanEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        try {
            if ($null -ne $script:StateDir) {
                $oldCache = Join-Path $script:StateDir 'SLT_StartupScanCache.json'
                if (Test-Path -LiteralPath $oldCache -ErrorAction SilentlyContinue) {
                    Remove-Item -LiteralPath $oldCache -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {}

        $isInteractiveUi = ($null -ne (Get-Variable -Scope Script -Name 'Window' -ErrorAction SilentlyContinue) -and $null -ne $script:Window -and $script:Window.IsVisible)
        $doFastOnlyOnUiThread = ($QuickRegistryOnly -or $AsyncBackground -or $isInteractiveUi)

        $script:ScannedInstalledApps = @{}
        $dedupByNameVer = @{}
        $dedupByNameOnly = @{}
        $dedupByWingetId = @{}
        $rawDiscovered = New-Object System.Collections.Generic.List[object]
        $regRawCounter = 0

        # 1. Read all 3 Registry Uninstall paths safely (takes ~40-60ms)
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        foreach ($rp in $regPaths) {
            try {
                $regItems = @(Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue)
                foreach ($it in $regItems) {
                    if ($null -eq $it) { continue }
                    $dnProp = $it.PSObject.Properties['DisplayName']
                    if ($null -eq $dnProp -or $null -eq $dnProp.Value) { continue }
                    $dn = ([string]$dnProp.Value).Trim()
                    if ([string]::IsNullOrWhiteSpace($dn)) { continue }

                    $sysCompProp = $it.PSObject.Properties['SystemComponent']
                    if ($null -ne $sysCompProp -and $null -ne $sysCompProp.Value -and [int]$sysCompProp.Value -eq 1) { continue }

                    $parentProp = $it.PSObject.Properties['ParentKeyName']
                    if ($null -ne $parentProp -and -not [string]::IsNullOrWhiteSpace([string]$parentProp.Value)) { continue }

                    $relTypeProp = $it.PSObject.Properties['ReleaseType']
                    if ($null -ne $relTypeProp -and ([string]$relTypeProp.Value) -match '(?i)(Security Update|Update Rollup|Hotfix)') { continue }

                    $verProp   = $it.PSObject.Properties['DisplayVersion']
                    $pubProp   = $it.PSObject.Properties['Publisher']
                    $childProp = $it.PSObject.Properties['PSChildName']
                    $unProp    = $it.PSObject.Properties['UninstallString']
                    $qunProp   = $it.PSObject.Properties['QuietUninstallString']
                    $locProp   = $it.PSObject.Properties['InstallLocation']

                    $verStr   = if ($null -ne $verProp -and -not [string]::IsNullOrWhiteSpace([string]$verProp.Value)) { ([string]$verProp.Value).Trim() } else { '1.0' }
                    $pubStr   = if ($null -ne $pubProp -and -not [string]::IsNullOrWhiteSpace([string]$pubProp.Value)) { ([string]$pubProp.Value).Trim() } else { 'Third-Party Application' }
                    $childStr = if ($null -ne $childProp -and $childProp.Value) { ([string]$childProp.Value).Trim() } else { '' }
                    $unStr    = if ($null -ne $unProp -and $unProp.Value) { ([string]$unProp.Value).Trim() } else { '' }
                    $qunStr   = if ($null -ne $qunProp -and $qunProp.Value) { ([string]$qunProp.Value).Trim() } else { '' }
                    $locStr   = if ($null -ne $locProp -and $locProp.Value) { ([string]$locProp.Value).Trim() } else { '' }

                    if (-not (Test-SLTRegistryEntryExistsOnDisk -UninstallString $unStr -QuietUninstall $qunStr -InstallLocation $locStr)) {
                        continue
                    }

                    if (-not (Test-SLTIsGenuineInstalledApp -Name $dn -Publisher $pubStr -Version $verStr -IdOrChild $childStr -Source 'Registry' -UninstallString $unStr -QuietUninstall $qunStr)) {
                        continue
                    }

                    $regRawCounter++
                    $dnL = $dn.ToLowerInvariant()
                    $dedupKey = ($dnL + '|' + $verStr.ToLowerInvariant())

                    if ((-not $dedupByNameVer.ContainsKey($dedupKey)) -and (-not $dedupByNameOnly.ContainsKey($dnL))) {
                        $dedupByNameVer[$dedupKey] = $true
                        $dedupByNameOnly[$dnL] = $true
                        if ($childStr.Contains('.')) { $dedupByWingetId[$childStr.ToLowerInvariant()] = $true }

                        $rawDiscovered.Add([pscustomobject]@{
                            Name            = $dn
                            NameL           = $dnL
                            Publisher       = $pubStr
                            PublisherL      = $pubStr.ToLowerInvariant()
                            Version         = $verStr
                            ChildName       = $childStr
                            ChildL          = $childStr.ToLowerInvariant()
                            UninstallString = $unStr
                            QuietUninstall  = $qunStr
                            AppxName        = ''
                            Source          = 'Registry'
                        })
                    }
                }
            } catch {}
        }

        # 2. Read winget list & Get-AppxPackage ONLY when running in background worker ($null -eq $script:Window)
        if (-not $doFastOnlyOnUiThread) {
            try {
                $wg = Get-Command winget.exe -ErrorAction SilentlyContinue
                if ($null -eq $wg) {
                    $wgCand = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
                    if (Test-Path -LiteralPath $wgCand) { $wg = [pscustomobject]@{ Source = $wgCand } }
                }
                if ($null -ne $wg) {
                    $tmpOut = [IO.Path]::GetTempFileName()
                    $tmpErr = [IO.Path]::GetTempFileName()
                    try {
                        $pWg = Start-Process -FilePath $wg.Source -ArgumentList @('list','--accept-source-agreements','--disable-interactivity') -PassThru -WindowStyle Hidden -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr -ErrorAction SilentlyContinue
                        if ($null -ne $pWg) {
                            [void]$pWg.WaitForExit(10000)
                        }
                        $rawWg = Read-SLTTempTextShared $tmpOut
                        $parsedWg = @(ConvertFrom-SLTWinGetListOutput $rawWg)
                        foreach ($wRow in $parsedWg) {
                            $wName  = [string]$wRow.Name
                            $wId    = [string]$wRow.Id
                            $wVer   = [string]$wRow.Version
                            $wPub   = [string]$wRow.Publisher
                            $wNameL = $wName.ToLowerInvariant()
                            $wIdL   = $wId.ToLowerInvariant()
                            $wKey   = ($wNameL + '|' + $wVer.ToLowerInvariant())

                            if ((-not $dedupByNameVer.ContainsKey($wKey)) -and (-not $dedupByNameOnly.ContainsKey($wNameL)) -and (-not $dedupByWingetId.ContainsKey($wIdL))) {
                                $dedupByNameVer[$wKey] = $true
                                $dedupByNameOnly[$wNameL] = $true
                                $dedupByWingetId[$wIdL] = $true
                                $rawDiscovered.Add([pscustomobject]@{
                                    Name            = $wName
                                    NameL           = $wNameL
                                    Publisher       = $wPub
                                    PublisherL      = $wPub.ToLowerInvariant()
                                    Version         = $wVer
                                    ChildName       = $wId
                                    ChildL          = $wIdL
                                    UninstallString = ''
                                    QuietUninstall  = ''
                                    AppxName        = ''
                                    Source          = 'WinGet'
                                })
                            }
                        }
                    } finally {
                        Remove-Item -LiteralPath $tmpOut,$tmpErr -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {}

        }
        $needAppxNow = ((-not $doFastOnlyOnUiThread) -or $null -eq $script:RealScanWindowsApps -or @($script:RealScanWindowsApps).Count -eq 0)
        if ($needAppxNow) {
            try {
                $appxItems = @(Get-AppxPackage -ErrorAction SilentlyContinue)
                foreach ($ax in $appxItems) {
                    if ($null -eq $ax) { continue }
                    $isFwProp = $ax.PSObject.Properties['IsFramework']
                    if ($null -ne $isFwProp -and [bool]$isFwProp.Value) { continue }
                    $nonRemProp = $ax.PSObject.Properties['NonRemovable']
                    if ($null -ne $nonRemProp -and [bool]$nonRemProp.Value) { continue }
                    $sigProp = $ax.PSObject.Properties['SignatureKind']
                    if ($null -ne $sigProp -and [string]$sigProp.Value -eq 'System') { continue }
                    $nmProp = $ax.PSObject.Properties['Name']
                    if ($null -eq $nmProp -or [string]::IsNullOrWhiteSpace([string]$nmProp.Value)) { continue }
                    $rawAxName = ([string]$nmProp.Value).Trim()
                    if ($rawAxName.StartsWith('-') -or $rawAxName.Contains('--')) { continue }
                    $friendlyAx = Format-SLTFriendlyWindowsAppName $rawAxName
                    $axL = $friendlyAx.ToLowerInvariant()
                    $verAxProp = $ax.PSObject.Properties['Version']
                    $axVer = if ($null -ne $verAxProp -and $verAxProp.Value) { [string]$verAxProp.Value } else { '' }
                    if ([string]::IsNullOrWhiteSpace($axVer)) { continue }
                    $axKey = ($axL + '|' + $axVer.ToLowerInvariant())

                    if ((-not $dedupByNameVer.ContainsKey($axKey)) -and (-not $dedupByNameOnly.ContainsKey($axL))) {
                        $dedupByNameVer[$axKey] = $true
                        $dedupByNameOnly[$axL] = $true
                        $rawDiscovered.Add([pscustomobject]@{
                            Name            = $friendlyAx
                            NameL           = $axL
                            Publisher       = 'Microsoft Store'
                            PublisherL      = 'microsoft'
                            Version         = $axVer
                            ChildName       = $rawAxName
                            ChildL          = $rawAxName.ToLowerInvariant()
                            UninstallString = ''
                            QuietUninstall  = ''
                            AppxName        = $rawAxName
                            Source          = 'Appx'
                        })
                    }
                }
            } catch {}
        }

        $script:RealRegRawCount = $regRawCounter

        # 3. Classify into 3 Sections: System Apps (Safe), Third-Party Apps, SLT Apps
        $sltList      = New-Object System.Collections.Generic.List[object]
        $customerList = New-Object System.Collections.Generic.List[object]
        $windowsList  = New-Object System.Collections.Generic.List[object]

        # If Appx scan was skipped on this pass because WindowsApps was already populated, preserve existing WindowsApps
        if ((-not $needAppxNow) -and $null -ne $script:RealScanWindowsApps -and @($script:RealScanWindowsApps).Count -gt 0) {
            foreach ($oldWin in @($script:RealScanWindowsApps)) {
                if ($null -ne $oldWin) { $windowsList.Add($oldWin) }
            }
        }

        foreach ($rec in $script:AppRecords) {
            if ($rec.Group -eq 'OS') { continue }
            if ($rec.SltAction -eq 'SLT_TOOLS_HUB_SHORTCUT') {
                $u1 = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'SLT Smart Tools Hub.url'
                $u2 = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'SLT Smart Tools Hub.url'
                if ((Test-Path -LiteralPath $u1) -or (Test-Path -LiteralPath $u2)) {
                    $script:ScannedInstalledApps[$rec.Key] = @{ Item=$rec; Version='1.0'; Source='Desktop' }
                    $sltList.Add([pscustomobject]@{
                        RowId           = ('SLT_' + $rec.Key)
                        AppCategory     = 'SLT'
                        BadgeText       = 'SLT App'
                        Name            = [string]$rec.Name
                        Publisher       = 'Smart Life Teck'
                        Version         = '1.0'
                        CategoryName    = [string]$rec.Category
                        WingetId        = [string]$rec.Winget
                        SltKey          = [string]$rec.Key
                        SltAction       = [string]$rec.SltAction
                        UninstallString = ''
                        QuietUninstall  = ''
                        AppxName        = ''
                        ChildName       = ''
                        SizeMb          = [int]$rec.SizeMb
                        EtaMin          = [double]$rec.EtaMin
                        MatchKeywords   = @($rec.MatchKeywords)
                    })
                }
                continue
            }
            if ($rec.SltAction -eq 'SLT_ARABIC_PACK') {
                try {
                    $ll = Get-WinUserLanguageList -ErrorAction SilentlyContinue
                    if ($ll -and @($ll | Where-Object { $_.LanguageTag -like 'ar*' }).Count -gt 0) {
                        $script:ScannedInstalledApps[$rec.Key] = @{ Item=$rec; Version='ar-SA'; Source='Windows' }
                        $sltList.Add([pscustomobject]@{
                            RowId           = ('SLT_' + $rec.Key)
                            AppCategory     = 'SLT'
                            BadgeText       = 'SLT App'
                            Name            = [string]$rec.Name
                            Publisher       = 'Microsoft'
                            Version         = 'ar-SA'
                            CategoryName    = [string]$rec.Category
                            WingetId        = [string]$rec.Winget
                            SltKey          = [string]$rec.Key
                            SltAction       = [string]$rec.SltAction
                            UninstallString = ''
                            QuietUninstall  = ''
                            AppxName        = ''
                            ChildName       = ''
                            SizeMb          = [int]$rec.SizeMb
                            EtaMin          = [double]$rec.EtaMin
                            MatchKeywords   = @($rec.MatchKeywords)
                        })
                    }
                } catch {}
                continue
            }
        }

        $genericTailIgnore = @('client','free','standard','community','files','studio','player','browser','viewer','manager','tweaker','pro','plus','code','app','xbox','teams','office','draw','warp','setup','installer','desktop','server','lite','mini')
        if ($null -eq $script:PrecomputedAppMatchList -or $null -eq $script:PrecomputedWingetMap -or @($script:PrecomputedAppMatchList).Count -eq 0) {
            $prepList = New-Object System.Collections.Generic.List[object]
            $wgMap = @{}
            foreach ($rec in $script:AppRecords) {
                if ($rec.Group -eq 'OS' -or $rec.SltAction -ne '') { continue }
                $wid = ([string]$rec.Winget).Trim()
                $widL = $wid.ToLowerInvariant()
                $widTail = if ($widL.Contains('.')) { ($widL.Split('.')[-1]) } else { $widL }
                $cleanAppName = ($rec.Name -replace '\s*\(.*?\)\s*','').Trim().ToLowerInvariant()
                $pubL = ([string]$rec.Publisher).Trim().ToLowerInvariant()
                $kwList = New-Object System.Collections.Generic.List[string]
                foreach ($kw in @($rec.MatchKeywords)) {
                    $kwL = ([string]$kw).Trim().ToLowerInvariant()
                    if ($kwL.Length -ge 4 -and ($kwL -notin $genericTailIgnore)) { $kwList.Add($kwL) }
                }
                if ($widL.Length -gt 3 -and $widL -notin @('na','n/a')) {
                    $wgMap[$widL] = $rec
                }
                $prepList.Add([pscustomobject]@{
                    Rec          = $rec
                    Key          = [string]$rec.Key
                    WidL         = $widL
                    WidHasDot    = $widL.Contains('.')
                    WidTail      = $widTail
                    WidTailValid = ($widTail.Length -ge 5 -and ($widTail -notin $genericTailIgnore))
                    CleanName    = $cleanAppName
                    CleanValid   = ($cleanAppName.Length -ge 4 -and ($cleanAppName -notin $genericTailIgnore))
                    PubL         = $pubL
                    PubValid     = ($pubL.Length -ge 4)
                    Keywords     = $kwList.ToArray()
                })
            }
            $script:PrecomputedAppMatchList = $prepList.ToArray()
            $script:PrecomputedWingetMap    = $wgMap
        }

        for ($idx = 0; $idx -lt $rawDiscovered.Count; $idx++) {
            $re = $rawDiscovered[$idx]

            if (-not (Test-SLTIsGenuineInstalledApp -Name $re.Name -Publisher $re.Publisher -Version $re.Version -IdOrChild $re.ChildName -Source $re.Source -UninstallString $re.UninstallString -QuietUninstall $re.QuietUninstall)) {
                continue
            }

            if (Test-SLTCriticalHiddenApp -DisplayName $re.Name -Publisher $re.Publisher) {
                continue
            }

            $matchedRec = $null
            if ($re.ChildL.Length -gt 3 -and $script:PrecomputedWingetMap.ContainsKey($re.ChildL)) {
                $cand = $script:PrecomputedWingetMap[$re.ChildL]
                if (-not $script:ScannedInstalledApps.ContainsKey([string]$cand.Key)) {
                    $matchedRec = $cand
                }
            }
            if ($null -eq $matchedRec) {
                foreach ($pm in $script:PrecomputedAppMatchList) {
                    if ($script:ScannedInstalledApps.ContainsKey($pm.Key)) { continue }
                    $isMatch = $false
                    if ($pm.WidHasDot -and $pm.WidL.Length -gt 3 -and $re.ChildL.Contains($pm.WidL)) {
                        $isMatch = $true
                    } elseif ($pm.CleanValid -and ($re.NameL -eq $pm.CleanName -or $re.NameL.StartsWith($pm.CleanName + ' ') -or ($pm.CleanName.Length -ge 6 -and $re.NameL.Contains($pm.CleanName)))) {
                        $isMatch = $true
                    } else {
                        foreach ($kwL in $pm.Keywords) {
                            if ($re.NameL -eq $kwL -or $re.NameL.StartsWith($kwL + ' ') -or ($kwL.Length -ge 6 -and $re.NameL.Contains($kwL))) {
                                $isMatch = $true; break
                            }
                        }
                    }
                    if ((-not $isMatch) -and $pm.PubValid -and $pm.WidTailValid -and $re.PublisherL.Contains($pm.PubL) -and $re.NameL.Contains($pm.WidTail)) {
                        $isMatch = $true
                    }
                    if ($isMatch) {
                        $matchedRec = $pm.Rec
                        break
                    }
                }
            }

            $isWinBloat = (Test-SLTWindowsBloatwareApp -DisplayName $re.Name -Publisher $re.Publisher -AppxName $re.AppxName)

            if ($null -ne $matchedRec) {
                $script:ScannedInstalledApps[$matchedRec.Key] = @{ Item=$matchedRec; Version=$re.Version; Source=$re.Source }
            }

            if ($isWinBloat -and ($re.Source -eq 'Appx' -or ($null -ne $matchedRec -and $matchedRec.Key -in @('a_microsoft_xbox','a_microsoft_teams','a_microsoft_onedrive','a_microsoft_skype')))) {
                $windowsList.Add([pscustomobject]@{
                    RowId           = ('WIN_' + $idx)
                    AppCategory     = 'WINDOWS'
                    BadgeText       = 'Safe'
                    Name            = $re.Name
                    Publisher       = 'Microsoft Corporation'
                    Version         = $re.Version
                    CategoryName    = 'System Apps (Safe)'
                    WingetId        = if($null -ne $matchedRec -and $matchedRec.Winget -notin @('na','')){[string]$matchedRec.Winget}elseif($re.Source -eq 'WinGet'){$re.ChildName}else{'na'}
                    SltKey          = if($null -ne $matchedRec){[string]$matchedRec.Key}else{''}
                    SltAction       = ''
                    UninstallString = $re.UninstallString
                    QuietUninstall  = $re.QuietUninstall
                    AppxName        = if($re.AppxName){$re.AppxName}else{$re.ChildName}
                    ChildName       = $re.ChildName
                    SizeMb          = 45
                    EtaMin          = 0.3
                    MatchKeywords   = if($null -ne $matchedRec){@($matchedRec.MatchKeywords)}else{@()}
                })
            } elseif ($null -ne $matchedRec) {
                $sltList.Add([pscustomobject]@{
                    RowId           = ('SLT_' + $matchedRec.Key)
                    AppCategory     = 'SLT'
                    BadgeText       = 'SLT App'
                    Name            = [string]$matchedRec.Name
                    Publisher       = if($re.Publisher -and $re.Publisher -notin @('Unknown Publisher','WinGet Package')){$re.Publisher}else{[string]$matchedRec.Publisher}
                    Version         = $re.Version
                    CategoryName    = [string]$matchedRec.Category
                    WingetId        = [string]$matchedRec.Winget
                    SltKey          = [string]$matchedRec.Key
                    SltAction       = [string]$matchedRec.SltAction
                    UninstallString = $re.UninstallString
                    QuietUninstall  = $re.QuietUninstall
                    AppxName        = $re.AppxName
                    ChildName       = $re.ChildName
                    SizeMb          = [int]$matchedRec.SizeMb
                    EtaMin          = [double]$matchedRec.EtaMin
                    MatchKeywords   = @($matchedRec.MatchKeywords)
                })
            } elseif ($isWinBloat) {
                $windowsList.Add([pscustomobject]@{
                    RowId           = ('WIN_' + $idx)
                    AppCategory     = 'WINDOWS'
                    BadgeText       = 'Safe'
                    Name            = $re.Name
                    Publisher       = 'Microsoft Corporation'
                    Version         = $re.Version
                    CategoryName    = 'System Apps (Safe)'
                    WingetId        = if($re.Source -eq 'WinGet'){$re.ChildName}else{'na'}
                    SltKey          = ''
                    SltAction       = ''
                    UninstallString = $re.UninstallString
                    QuietUninstall  = $re.QuietUninstall
                    AppxName        = if($re.AppxName){$re.AppxName}else{$re.ChildName}
                    ChildName       = $re.ChildName
                    SizeMb          = 45
                    EtaMin          = 0.3
                    MatchKeywords   = @()
                })
            } elseif ($re.Source -in @('Registry','WinGet') -or ($re.Source -eq 'Appx' -and $re.PublisherL -notmatch 'microsoft|windows')) {
                $customerList.Add([pscustomobject]@{
                    RowId           = ('CUST_' + $idx)
                    AppCategory     = 'CUSTOMER'
                    BadgeText       = 'Third-Party'
                    Name            = $re.Name
                    Publisher       = $re.Publisher
                    Version         = $re.Version
                    CategoryName    = 'Third-Party Apps'
                    WingetId        = if($re.Source -eq 'WinGet'){$re.ChildName}else{'na'}
                    SltKey          = ''
                    SltAction       = ''
                    UninstallString = $re.UninstallString
                    QuietUninstall  = $re.QuietUninstall
                    AppxName        = $re.AppxName
                    ChildName       = $re.ChildName
                    SizeMb          = 60
                    EtaMin          = 0.5
                    MatchKeywords   = @()
                })
            }
        }

        $script:RealScanSltApps      = @($sltList | Sort-Object Name)
        $script:RealScanCustomerApps = @($customerList | Sort-Object Name)
        $script:RealScanWindowsApps  = @($windowsList | Sort-Object Name)
        $script:RealScanAllApps      = @($script:RealScanWindowsApps + $script:RealScanCustomerApps + $script:RealScanSltApps)

        $script:TotalPcInstalledCount = $script:RealScanAllApps.Count
        if ($script:TotalPcInstalledCount -le 0) {
            Remove-Item -LiteralPath $cacheFile -Force -ErrorAction SilentlyContinue
            return $false
        }
        $script:ScanCompletedOnce = $true
        $global:installedApps = $script:ScannedInstalledApps

        foreach ($instKey in @($script:ScannedInstalledApps.Keys)) {
            if ($script:SelectedApps.ContainsKey([string]$instKey)) {
                $null = $script:SelectedApps.Remove([string]$instKey)
            }
        }

        $validRowIds = @{}
        foreach ($rItem in $script:RealScanAllApps) {
            if ($null -ne $rItem) { $validRowIds[[string]$rItem.RowId] = $true }
        }
        if ($null -ne $script:UninstallSelectedMap) {
            foreach ($uk in @($script:UninstallSelectedMap.Keys)) {
                if (-not $validRowIds.ContainsKey([string]$uk)) {
                    $null = $script:UninstallSelectedMap.Remove([string]$uk)
                }
            }
        }

        Invoke-SLTUpdateAllScanUIs

        # When called from interactive UI and not QuickRegistryOnly, kick off non-blocking background full scan!
        if ($isInteractiveUi -and (-not $QuickRegistryOnly)) {
            Start-SLTAsyncRealScan
        }

        if ($OpenModal) {
            if (Get-Command Show-SLTScanInstalledWindow -ErrorAction SilentlyContinue) { Show-SLTScanInstalledWindow }
        }
    } catch {
        Log-SLT ('Get-RealInstalledApps error: ' + $_.Exception.Message)
    } finally {
        $ErrorActionPreference = $oldScanEap
    }
}

function Get-AllInstalledAppsPerfect([switch]$OpenModal) {
    Get-RealInstalledApps -OpenModal:$OpenModal
}

function ScanInstalledApps {
    Get-RealInstalledApps -OpenModal:$false
}

function Refresh-Grid {
    # Non-blocking real rescan: instant (<60ms) Registry rescan + async background WinGet & Appx rescan
    try {
        Get-RealInstalledApps -QuickRegistryOnly:$false
        $global:installedApps = $script:ScannedInstalledApps
    } catch {
        Log-SLT ('Refresh-Grid warning: ' + $_.Exception.Message)
    }
}

function Import-SLTStartupScanCache {
    try {
        if ($null -eq $script:StateDir) { return $false }
        $legacyCache = Join-Path $script:StateDir 'SLT_StartupScanCache.json'
        if (Test-Path -LiteralPath $legacyCache) {
            Remove-Item -LiteralPath $legacyCache -Force -ErrorAction SilentlyContinue
        }
        $lockFile  = Join-Path $script:StateDir 'SLT_StartupScan.lock'
        $cacheFile = Join-Path $script:StateDir 'SLT_StartupScanCache_v553.json'
        if (Test-Path -LiteralPath $lockFile) { return $false }
        if (-not (Test-Path -LiteralPath $cacheFile)) { return $false }

        $age = (Get-Date) - (Get-Item -LiteralPath $cacheFile).LastWriteTime
        if ($age.TotalMinutes -gt 30) { return $false }

        $cache = Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json
        if ($null -eq $cache -or $null -eq $cache.scannedKeys) { return $false }

        $script:ScannedInstalledApps = @{}
        foreach ($row in @($cache.scannedKeys)) {
            $k = [string]$row.key
            if ($script:AppIndex.ContainsKey($k)) {
                $script:ScannedInstalledApps[$k] = @{ Item = $script:AppIndex[$k]; Version = [string]$row.version; Source = [string]$row.source }
            }
        }

        $cleanCust = New-Object System.Collections.Generic.List[object]
        foreach ($cApp in @($cache.customerApps)) {
            if ($null -eq $cApp) { continue }
            $cn = [string]$cApp.Name
            $cp = [string]$cApp.Publisher
            $cv = [string]$cApp.Version
            if ($cn.StartsWith('-') -or $cn.StartsWith('--') -or $cn.Contains('--')) { continue }
            if ($cp -eq 'WinGet Package' -and $cv -eq 'Installed') { continue }
            if ($cp -eq 'Unknown Publisher' -and $cv -eq 'Installed') { continue }
            $cleanCust.Add($cApp)
        }

        $script:RealScanSltApps      = @(@($cache.sltApps)     | ForEach-Object { $_ })
        $script:RealScanCustomerApps = @($cleanCust.ToArray())
        $script:RealScanWindowsApps  = @(@($cache.windowsApps) | ForEach-Object { $_ })
        $script:RealScanAllApps      = @($script:RealScanWindowsApps + $script:RealScanCustomerApps + $script:RealScanSltApps)
        $script:TotalPcInstalledCount = $script:RealScanAllApps.Count
        $script:ScanCompletedOnce = $true
        $global:installedApps = $script:ScannedInstalledApps

        if ($null -ne $cache.laptop) { $global:SLTLaptopInfo = $cache.laptop }

        foreach ($instKey in @($script:ScannedInstalledApps.Keys)) {
            if ($script:SelectedApps.ContainsKey([string]$instKey)) { $null = $script:SelectedApps.Remove([string]$instKey) }
        }

        Log-SLT ("Loaded verified scan cache: {0} app(s), cache age {1:N1} min." -f $script:TotalPcInstalledCount, $age.TotalMinutes)
        return $true
    } catch {
        Log-SLT ('Import-SLTStartupScanCache error: ' + $_.Exception.Message)
        return $false
    }
}

Set-Item -Path Function:\global:Read-SLTTempTextShared -Value ${function:Read-SLTTempTextShared}
Set-Item -Path Function:\global:Test-SLTRegistryEntryExistsOnDisk -Value ${function:Test-SLTRegistryEntryExistsOnDisk}
Set-Item -Path Function:\global:Test-SLTIsGenuineInstalledApp -Value ${function:Test-SLTIsGenuineInstalledApp}
Set-Item -Path Function:\global:ConvertFrom-SLTWinGetListOutput -Value ${function:ConvertFrom-SLTWinGetListOutput}
Set-Item -Path Function:\global:Invoke-SLTUpdateAllScanUIs -Value ${function:Invoke-SLTUpdateAllScanUIs}
Set-Item -Path Function:\global:Start-SLTAsyncRealScan -Value ${function:Start-SLTAsyncRealScan}
Set-Item -Path Function:\global:Import-SLTStartupScanCache -Value ${function:Import-SLTStartupScanCache}
Set-Item -Path Function:\global:Test-SLTCriticalHiddenApp -Value ${function:Test-SLTCriticalHiddenApp}
Set-Item -Path Function:\global:Test-SLTWindowsBloatwareApp -Value ${function:Test-SLTWindowsBloatwareApp}
Set-Item -Path Function:\global:Format-SLTFriendlyWindowsAppName -Value ${function:Format-SLTFriendlyWindowsAppName}
Set-Item -Path Function:\global:Get-RealInstalledApps -Value ${function:Get-RealInstalledApps}
Set-Item -Path Function:\global:Get-AllInstalledAppsPerfect -Value ${function:Get-AllInstalledAppsPerfect}
Set-Item -Path Function:\global:ScanInstalledApps -Value ${function:ScanInstalledApps}
Set-Item -Path Function:\global:Refresh-Grid -Value ${function:Refresh-Grid}
