# SLT Smart PC Boost v1.0.0 - Verified Install (100s) & Verified Uninstall (60s) Worker
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Manifest)
$ErrorActionPreference='Stop'
$job=$null;$total=0;$completed=0;$fail=0;$installedCnt=0;$uninstalledCnt=0;$skippedCnt=0;$manualReq=0
$savedMinutes=0.0
$log=$null;$progress=$null;$current='Starting...';$currentWid='';$currentPhase='Checking';$currentPct=10
$currentSizeMb=0;$remainingEtaMin=0.0;$totalSizeMb=0;$verb='Install'
$last='Initializing Smart Package Engine...'
$results=New-Object 'System.Collections.Generic.List[object]'

function Write-Status([string]$t){
    $line=(Get-Date -Format s)+'  '+$t
    if($log){try{Add-Content -LiteralPath $log -Value $line -Encoding UTF8}catch{}}
}

function Publish-Progress([string]$State='Running'){
    if(-not $progress){return}
    $completedCount = $installedCnt + $uninstalledCnt + $skippedCnt + $fail
    $pct = if($total -gt 0){ [int][Math]::Min(100, [Math]::Round(100.0 * $completedCount / $total)) } else { 0 }
    $tmp = $progress + '.tmp'
    $payload = [ordered]@{
        state           = $State
        verb            = $verb
        total           = $total
        completed       = $completedCount
        percent         = $pct
        current         = $current
        currentWid      = $currentWid
        currentPhase    = $currentPhase
        currentPct      = $currentPct
        currentSizeMb   = $currentSizeMb
        remainingEtaMin = [Math]::Round($remainingEtaMin, 1)
        savedMinutes    = [Math]::Max(1, [int][Math]::Ceiling($savedMinutes))
        totalSizeMb     = $totalSizeMb
        last            = $last
        failures        = $fail
        installed       = $installedCnt
        uninstalled     = $uninstalledCnt
        already         = $skippedCnt
        skipped         = $skippedCnt
        manualRequired  = $manualReq
        results         = @($results.ToArray())
        updated         = (Get-Date -Format s)
    }
    try {
        $payload | ConvertTo-Json -Compress -Depth 6 | Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $progress -Force
    } catch {}
}

function Read-SLTSharedFileText([string]$PathToRead) {
    if ([string]::IsNullOrWhiteSpace($PathToRead) -or (-not (Test-Path -LiteralPath $PathToRead))) { return '' }
    try {
        $fs = New-Object System.IO.FileStream($PathToRead, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
        $content = $sr.ReadToEnd()
        $sr.Close()
        $fs.Close()
        return $content
    } catch {
        return ''
    }
}

function Stop-SLTProcessTree([int]$ProcessId) {
    if ($ProcessId -le 0) { return }
    try {
        $tk = Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/F','/T','/PID',[string]$ProcessId) -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
        if ($null -ne $tk) { [void]$tk.WaitForExit(3000) }
    } catch {}
    try { Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue } catch {}
}

function Invoke-QuietCapture([string]$Exe,[string[]]$Argv,[int]$TimeoutSec=100){
    $tmp=[IO.Path]::GetTempFileName();$err=[IO.Path]::GetTempFileName()
    try {
        $p=Start-Process -FilePath $Exe -ArgumentList $Argv -PassThru -WindowStyle Hidden -RedirectStandardOutput $tmp -RedirectStandardError $err -ErrorAction Stop
        $finished = $p.WaitForExit($TimeoutSec * 1000)
        if(-not $finished){
            Stop-SLTProcessTree -ProcessId $p.Id
            try { $p.Kill() } catch {}
            Write-Status ("TIMEOUT after " + $TimeoutSec + "s: killed hung process " + $Exe)
            return [pscustomobject]@{ExitCode=-999;TimedOut=$true;Output='TIMEOUT'}
        }
        # CRITICAL PowerShell 5.1 fix: call parameterless WaitForExit() so ExitCode is populated, and default to -1 (never 0!)
        try { $p.WaitForExit() } catch {}
        $codeVal = -1
        try {
            if ($null -ne $p.ExitCode) { $codeVal = [int]$p.ExitCode }
        } catch { $codeVal = -1 }
        $output = Read-SLTSharedFileText $tmp
        $errOut = Read-SLTSharedFileText $err
        return [pscustomobject]@{ExitCode=$codeVal;TimedOut=$false;Output=($output+"`n"+$errOut)}
    } catch {
        return [pscustomobject]@{ExitCode=-1;TimedOut=$false;Output=$_.Exception.Message}
    } finally {
        try { Remove-Item -LiteralPath $tmp,$err -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Resolve-SLTCatalogWingetId([string]$RawId, [string]$AppName='') {
    $id = ([string]$RawId).Trim()
    $map = @{
        'Bytedance.CapCut'                 = 'ByteDance.CapCut'
        'Cisco.WebexTeams'                 = 'Cisco.Webex'
        'Microsoft.Xbox'                   = '9MV0B5HZVK9Z'
        'AOMEI.PartitionAssistant.Standard'= 'AOMEI.PartitionAssistant'
        'ApacheFriends.Xampp'              = 'ApacheFriends.Xampp.8.2'
        'Files-Community.Files'            = 'FilesCommunity.Files'
        'GIMP.GIMP'                        = 'GIMP.GIMP.3'
        'Google.Drive'                     = 'Google.GoogleDrive'
    }
    if ($map.ContainsKey($id)) { return $map[$id] }
    $nmL = ([string]$AppName).Trim().ToLowerInvariant()
    if ($nmL -eq 'google chrome' -and ($id -eq '' -or $id -eq 'na')) { return 'Google.Chrome' }
    if ($nmL -eq 'google drive' -and ($id -eq '' -or $id -eq 'na'))  { return 'Google.GoogleDrive' }
    if ($nmL -eq 'ccleaner' -and ($id -eq '' -or $id -eq 'na'))      { return 'Piriform.CCleaner' }
    if ($nmL -like 'anydesk*' -and ($id -eq '' -or $id -eq 'na'))    { return 'AnyDeskSoftwareGmbH.AnyDesk' }
    if ($nmL -like 'rufus*' -and ($id -eq '' -or $id -eq 'na'))      { return 'Rufus.Rufus' }
    return $id
}

function Test-SLTKnownBinaryInstalled([string]$Wid, [string]$AppName='') {
    $idL = ([string]$Wid).Trim().ToLowerInvariant()
    $nmL = ([string]$AppName).Trim().ToLowerInvariant()
    $pathsToCheck = @()
    if ($idL -eq 'google.chrome' -or $idL -eq 'google.chrome.exe' -or $nmL -eq 'google chrome') {
        $pathsToCheck = @(
            'C:\Program Files\Google\Chrome\Application\chrome.exe',
            'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
            (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
        )
    } elseif ($idL -eq 'google.googledrive' -or $idL -eq 'google.drive' -or $nmL -eq 'google drive') {
        foreach ($gdDir in @('C:\Program Files\Google\Drive File Stream', 'C:\Program Files (x86)\Google\Drive File Stream')) {
            if (Test-Path -LiteralPath $gdDir) {
                $gdExes = @(Get-ChildItem -LiteralPath $gdDir -Filter 'GoogleDriveFS.exe' -Recurse -ErrorAction SilentlyContinue)
                foreach ($gx in $gdExes) { $pathsToCheck += $gx.FullName }
                $pathsToCheck += (Join-Path $gdDir 'launch.bat')
            }
        }
        foreach ($gdReg in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{6BBAE539-2232-434A-A4E5-9A33560C6283}',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{6BBAE539-2232-434A-A4E5-9A33560C6283}'
        )) {
            if (Test-Path -LiteralPath $gdReg) { return $true }
        }
    } elseif ($idL -like 'piriform.ccleaner*' -or $nmL -eq 'ccleaner') {
        $pathsToCheck = @(
            'C:\Program Files\CCleaner\CCleaner64.exe',
            'C:\Program Files\CCleaner\CCleaner.exe',
            'C:\Program Files\Piriform\CCleaner\CCleaner64.exe',
            'C:\Program Files\Piriform\CCleaner 7\CCleaner.exe',
            'C:\Program Files (x86)\CCleaner\CCleaner.exe'
        )
    } elseif ($idL -eq 'anydesksoftwaregmbh.anydesk' -or $nmL -like 'anydesk*') {
        $pathsToCheck = @(
            'C:\Program Files (x86)\AnyDesk\AnyDesk.exe',
            'C:\Program Files\AnyDesk\AnyDesk.exe'
        )
    } elseif ($idL -eq 'rufus.rufus' -or $nmL -like 'rufus*') {
        $pathsToCheck = @(
            (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\rufus.exe')
        )
        $wgPkgs = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        if (Test-Path -LiteralPath $wgPkgs) {
            $rfDirs = @(Get-ChildItem -LiteralPath $wgPkgs -Directory -Filter 'Rufus.Rufus*' -ErrorAction SilentlyContinue)
            foreach ($rd in $rfDirs) {
                $rfExes = @(Get-ChildItem -LiteralPath $rd.FullName -Filter 'rufus*.exe' -Recurse -ErrorAction SilentlyContinue)
                foreach ($rx in $rfExes) { $pathsToCheck += $rx.FullName }
            }
        }
    } elseif ($idL -eq '7zip.7zip' -or $nmL -eq '7-zip') {
        $pathsToCheck = @(
            'C:\Program Files\7-Zip\7zFM.exe',
            'C:\Program Files (x86)\7-Zip\7zFM.exe'
        )
    } elseif ($idL -eq 'videolan.vlc' -or $nmL -like 'vlc*') {
        $pathsToCheck = @(
            'C:\Program Files\VideoLAN\VLC\vlc.exe',
            'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe'
        )
    } elseif ($idL -eq 'rarlab.winrar' -or $nmL -eq 'winrar') {
        $pathsToCheck = @(
            'C:\Program Files\WinRAR\WinRAR.exe',
            'C:\Program Files (x86)\WinRAR\WinRAR.exe'
        )
    } elseif ($idL -eq 'brave.brave' -or $nmL -like 'brave*') {
        $pathsToCheck = @(
            'C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe',
            'C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe',
            (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\Application\brave.exe')
        )
    } elseif ($idL -eq 'mozilla.firefox' -or $nmL -like '*firefox*') {
        $pathsToCheck = @(
            'C:\Program Files\Mozilla Firefox\firefox.exe',
            'C:\Program Files (x86)\Mozilla Firefox\firefox.exe'
        )
    }
    foreach ($pt in $pathsToCheck) {
        if (-not [string]::IsNullOrWhiteSpace($pt) -and (Test-Path -LiteralPath $pt)) { return $true }
    }
    return $false
}

function Invoke-DirectOfficialSilentFallback([string]$Wid, [string]$AppName, [int]$RemainSec=120) {
    $fallbackSpecs = @{
        'Google.Chrome' = @(
            @{ Url='https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'; Ext='.msi'; Args='/qn /norestart'; MinBytes=40000000; DlTimeout=180; InstTimeout=90 },
            @{ Url='https://dl.google.com/chrome/install/latest/chrome_installer.exe'; Ext='.exe'; Args='/silent /install'; MinBytes=500000; DlTimeout=120; InstTimeout=90 }
        )
        'Google.GoogleDrive' = @(
            @{ Url='https://dl.google.com/drive-file-stream/GoogleDriveFSSetup.exe'; Ext='.exe'; Args='--silent --desktop_shortcut --skip_launch_new'; AltArgs='--silent'; MinBytes=100000000; DlTimeout=300; InstTimeout=150 }
        )
        'Piriform.CCleaner' = @(
            @{ Url='https://bits.avcdn.net/productfamily_CCLEANER/insttype_FREE/platform_WIN_PIR/installertype_ONLINE/build_RELEASE'; Ext='.exe'; Args='/S'; MinBytes=500000; DlTimeout=90; InstTimeout=75 },
            @{ Url='https://download.ccleaner.com/ccsetup.exe'; Ext='.exe'; Args='/S'; MinBytes=500000; DlTimeout=90; InstTimeout=75 },
            @{ Url='https://download.ccleaner.com/slim/ccsetup_slim.exe'; Ext='.exe'; Args='/S'; MinBytes=500000; DlTimeout=90; InstTimeout=75 }
        )
        'AnyDeskSoftwareGmbH.AnyDesk' = @(
            @{ Url='https://download.anydesk.com/AnyDesk.exe'; Ext='.exe'; Args='--install "C:\Program Files (x86)\AnyDesk" --start-with-win --silent'; MinBytes=1000000; DlTimeout=90; InstTimeout=60 }
        )
    }
    if (-not $fallbackSpecs.ContainsKey($Wid)) { return $false }
    $specList = @($fallbackSpecs[$Wid])

    if ($Wid -eq 'Google.GoogleDrive') {
        try {
            Get-Process -Name 'GoogleDriveFSSetup*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    foreach ($spec in $specList) {
        $minBytes    = if ($spec.ContainsKey('MinBytes'))    { [long]$spec.MinBytes }    else { 102400 }
        $dlTimeout   = if ($spec.ContainsKey('DlTimeout'))   { [int]$spec.DlTimeout }    else { 120 }
        $instTimeout = if ($spec.ContainsKey('InstTimeout')) { [int]$spec.InstTimeout }  else { 90 }
        $tmpInstaller = Join-Path $env:TEMP ('SLT_Direct_' + ($Wid -replace '[^a-zA-Z0-9]','_') + $spec.Ext)
        try {
            Write-Status ("Downloading official silent installer for " + $AppName + " (" + $spec.Url + ")...")
            $script:last = ("Downloading Official " + $AppName + " Installer...")
            $script:currentPct = 45
            Publish-Progress

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $dlOk = $false

            if ((Test-Path -LiteralPath $tmpInstaller) -and ((Get-Item -LiteralPath $tmpInstaller).Length -ge $minBytes)) {
                $dlOk = $true
            }

            if (-not $dlOk) {
                try { Remove-Item -LiteralPath $tmpInstaller -Force -ErrorAction SilentlyContinue } catch {}
                try {
                    $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
                    if ($null -ne $curlCmd) {
                        $curlArgs = @('-L','-s','-S','--retry','2','--connect-timeout','15','--max-time',[string]$dlTimeout,'-A','Mozilla/5.0 (Windows NT 10.0; Win64; x64)','-o',$tmpInstaller,$spec.Url)
                        $pCurl = Start-Process -FilePath $curlCmd.Source -ArgumentList $curlArgs -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                        if ($null -ne $pCurl) {
                            [void]$pCurl.WaitForExit(($dlTimeout + 10) * 1000)
                            if (-not $pCurl.HasExited) { Stop-SLTProcessTree $pCurl.Id }
                        }
                        if ((Test-Path -LiteralPath $tmpInstaller) -and ((Get-Item -LiteralPath $tmpInstaller).Length -ge $minBytes)) {
                            $dlOk = $true
                        }
                    }
                } catch {}
            }
            if (-not $dlOk) {
                try { Remove-Item -LiteralPath $tmpInstaller -Force -ErrorAction SilentlyContinue } catch {}
                try {
                    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                        Start-BitsTransfer -Source $spec.Url -Destination $tmpInstaller -Priority Foreground -ErrorAction Stop
                        if ((Test-Path -LiteralPath $tmpInstaller) -and ((Get-Item -LiteralPath $tmpInstaller).Length -ge $minBytes)) {
                            $dlOk = $true
                        }
                    }
                } catch {}
            }
            if (-not $dlOk) {
                try { Remove-Item -LiteralPath $tmpInstaller -Force -ErrorAction SilentlyContinue } catch {}
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
                $wc.DownloadFile($spec.Url, $tmpInstaller)
                if ((Test-Path -LiteralPath $tmpInstaller) -and ((Get-Item -LiteralPath $tmpInstaller).Length -ge $minBytes)) {
                    $dlOk = $true
                }
            }
            if ($dlOk -and (Test-Path -LiteralPath $tmpInstaller)) {
                $script:last = ("Installing " + $AppName + " (Official Silent Setup)...")
                $script:currentPct = 80
                Publish-Progress

                $argAttempts = @($spec.Args)
                if ($spec.ContainsKey('AltArgs') -and -not [string]::IsNullOrWhiteSpace([string]$spec.AltArgs)) {
                    $argAttempts += [string]$spec.AltArgs
                }

                foreach ($curArgs in $argAttempts) {
                    if ($spec.Ext -eq '.msi') {
                        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList ('/i "' + $tmpInstaller + '" ' + $curArgs) -PassThru -WindowStyle Hidden
                    } else {
                        $p = Start-Process -FilePath $tmpInstaller -ArgumentList $curArgs -PassThru -WindowStyle Hidden
                    }
                    $okWait = $p.WaitForExit($instTimeout * 1000)
                    if (-not $okWait) {
                        Stop-SLTProcessTree -ProcessId $p.Id
                        try { $p.Kill() } catch {}
                    } else {
                        try { $p.WaitForExit() } catch {}
                    }
                    for ($poll = 0; $poll -lt 6; $poll++) {
                        Start-Sleep -Milliseconds 900
                        Initialize-SLTInstalledSnapshot
                        $verAfterDl = Test-AlreadyInstalledBeforeInstall -Exe '' -Id $Wid -AppName $AppName -Keywords @()
                        if ($verAfterDl.Installed -or (Test-SLTKnownBinaryInstalled -Wid $Wid -AppName $AppName)) {
                            try { Remove-Item -LiteralPath $tmpInstaller -Force -ErrorAction SilentlyContinue } catch {}
                            return $true
                        }
                    }
                }
            }
        } catch {
            Write-Status ("Direct fallback warning for " + $AppName + ": " + $_.Exception.Message)
        } finally {
            try { Remove-Item -LiteralPath $tmpInstaller -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
    return $false
}

function Stop-SLTAppProcessesBeforeUninstall([string]$AppName, [string]$Wid='', [string]$UninstallString='') {
    $targets = New-Object System.Collections.Generic.List[string]
    $nmL = ([string]$AppName).ToLowerInvariant()
    $idL = ([string]$Wid).ToLowerInvariant()

    if ($nmL -match 'anydesk' -or $idL -match 'anydesk') {
        try { Stop-Service -Name 'AnyDesk' -Force -ErrorAction SilentlyContinue } catch {}
        try { & sc.exe stop AnyDesk 2>$null | Out-Null } catch {}
        $targets.Add('AnyDesk')
    }
    if ($nmL -match 'google drive' -or $idL -match 'googledrive') {
        $targets.Add('GoogleDriveFS')
    }
    if ($nmL -match 'rufus' -or $idL -match 'rufus') {
        $targets.Add('rufus')
    }
    if ($nmL -match 'ccleaner' -or $idL -match 'ccleaner') {
        try { Stop-Service -Name 'CCleanerPerformanceOptimizerService' -Force -ErrorAction SilentlyContinue } catch {}
        $targets.Add('CCleaner'); $targets.Add('CCleaner64'); $targets.Add('CCleanerAgent'); $targets.Add('CCleanerBugReport')
    }
    if ($nmL -match 'chrome' -or $idL -match 'chrome')     { $targets.Add('chrome') }
    if ($nmL -match 'brave' -or $idL -match 'brave')       { $targets.Add('brave') }
    if ($nmL -match 'firefox' -or $idL -match 'firefox')   { $targets.Add('firefox') }
    if ($nmL -match 'vlc' -or $idL -match 'vlc')           { $targets.Add('vlc') }
    if ($nmL -match 'telegram' -or $idL -match 'telegram') { $targets.Add('Telegram') }
    if ($nmL -match 'whatsapp' -or $idL -match 'whatsapp') { $targets.Add('WhatsApp') }
    if ($nmL -match 'discord' -or $idL -match 'discord')   { $targets.Add('Discord') }
    if ($nmL -match 'zoom' -or $idL -match 'zoom')         { $targets.Add('Zoom') }
    if ($nmL -match 'winrar' -or $idL -match 'winrar')     { $targets.Add('WinRAR') }
    if ($nmL -match '7-zip' -or $idL -match '7zip')        { $targets.Add('7zFM'); $targets.Add('7zG') }
    if ($nmL -match 'teamviewer' -or $idL -match 'teamviewer') { $targets.Add('TeamViewer') }
    if ($nmL -match 'filezilla' -or $idL -match 'filezilla')   { $targets.Add('filezilla'); $targets.Add('fzsftp'); $targets.Add('fzputtygen') }
    if ($nmL -match 'teams' -or $idL -match 'teams')           { $targets.Add('ms-teams'); $targets.Add('Teams'); $targets.Add('msteams') }
    if ($nmL -match 'xbox' -or $idL -match 'xbox|9mv0b5hzvk9z'){ $targets.Add('XboxPcApp'); $targets.Add('XboxAppServices'); $targets.Add('GameBar'); $targets.Add('GameBarPresenceWriter') }
    if ($nmL -match 'clipchamp' -or $idL -match 'clipchamp')   { $targets.Add('Clipchamp') }

    $firstWord = (($AppName -replace '\s*\(.*?\)\s*','').Trim() -split '[\s\-]+')[0]
    if (-not [string]::IsNullOrWhiteSpace($firstWord) -and $firstWord.Length -ge 4 -and $firstWord -notin @('Microsoft','Windows','System','Google','Smart')) {
        $targets.Add($firstWord)
    }

    if (-not [string]::IsNullOrWhiteSpace($UninstallString)) {
        $mExe = [regex]::Match($UninstallString, '([^\\\/"]+)\.exe\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($mExe.Success) {
            $exeStem = $mExe.Groups[1].Value.Trim()
            if ($exeStem -notmatch '^(?i)(msiexec|unins\d*|uninst.*|setup|install|uninstall|cmd|powershell|rundll32)$') {
                $targets.Add($exeStem)
            }
        }
    }

    foreach ($tProc in $targets) {
        try {
            Get-Process -Name ($tProc + '*') -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    Start-Sleep -Milliseconds 350
}

function Test-SLTRegistryEntryStillValidOnDisk([string]$UninstallString, [string]$QuietUninstall, [string]$InstallLocation = '') {
    $instLoc = [Environment]::ExpandEnvironmentVariables(([string]$InstallLocation).Trim().Trim('"'))
    if (-not [string]::IsNullOrWhiteSpace($instLoc) -and $instLoc.Length -gt 3) {
        if (Test-Path -LiteralPath $instLoc) { return $true }
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
                    return (Test-Path -LiteralPath $exeP)
                }
            }
        }
        $mExe = [regex]::Match($raw, '^([A-Za-z]:\\.+?\.exe)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($mExe.Success) {
            return (Test-Path -LiteralPath $mExe.Groups[1].Value.Trim())
        }
    }
    return $true
}

$script:AllRegSnapshot = New-Object System.Collections.Generic.List[object]
function Initialize-SLTInstalledSnapshot {
    $script:AllRegSnapshot.Clear()
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach($rp in $regPaths){
        try {
            $rawItems = @(Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue)
            foreach($it in $rawItems){
                if($null -eq $it){ continue }
                $dnProp = $it.PSObject.Properties['DisplayName']
                if($null -eq $dnProp -or $null -eq $dnProp.Value){ continue }
                $dnStr = ([string]$dnProp.Value).Trim()
                if([string]::IsNullOrWhiteSpace($dnStr)){ continue }

                $pubProp = $it.PSObject.Properties['Publisher']
                $chProp  = $it.PSObject.Properties['PSChildName']
                $qProp   = $it.PSObject.Properties['QuietUninstallString']
                $uProp   = $it.PSObject.Properties['UninstallString']
                $locProp = $it.PSObject.Properties['InstallLocation']
                $psPathProp = $it.PSObject.Properties['PSPath']

                $qVal   = if($null -ne $qProp -and $qProp.Value){([string]$qProp.Value).Trim()}else{''}
                $uVal   = if($null -ne $uProp -and $uProp.Value){([string]$uProp.Value).Trim()}else{''}
                $locVal = if($null -ne $locProp -and $locProp.Value){([string]$locProp.Value).Trim()}else{''}
                $psPathVal = if($null -ne $psPathProp -and $psPathProp.Value){[string]$psPathProp.Value}else{''}

                if (-not (Test-SLTRegistryEntryStillValidOnDisk -UninstallString $uVal -QuietUninstall $qVal -InstallLocation $locVal)) {
                    # Stale-looking uninstall entries are skipped from the UI but never deleted during inventory scanning.
                    Log-SLT ("Potentially stale uninstall registry entry preserved: $dnStr")
                    continue
                }

                $script:AllRegSnapshot.Add([pscustomobject]@{
                    DisplayName     = $dnStr
                    NameL           = $dnStr.ToLowerInvariant()
                    PublisherL      = if($null -ne $pubProp -and $pubProp.Value){([string]$pubProp.Value).Trim().ToLowerInvariant()}else{''}
                    ChildName       = if($null -ne $chProp -and $chProp.Value){([string]$chProp.Value).Trim()}else{''}
                    ChildL          = if($null -ne $chProp -and $chProp.Value){([string]$chProp.Value).Trim().ToLowerInvariant()}else{''}
                    QuietUninstall  = $qVal
                    UninstallString = $uVal
                    PSPath          = $psPathVal
                    AppxName        = ''
                })
            }
        } catch {}
    }
    try {
        $appxList = @(Get-AppxPackage -ErrorAction SilentlyContinue)
        foreach($ax in $appxList){
            if($null -eq $ax -or (-not $ax.PSObject.Properties['Name']) -or [string]::IsNullOrWhiteSpace([string]$ax.Name)){ continue }
            if($ax.PSObject.Properties['IsFramework'] -and [bool]$ax.IsFramework){ continue }
            if($ax.PSObject.Properties['NonRemovable'] -and [bool]$ax.NonRemovable){ continue }
            if($ax.PSObject.Properties['SignatureKind'] -and [string]$ax.SignatureKind -eq 'System'){ continue }
            $axNm = ([string]$ax.Name).Trim()
            $axLow = $axNm.ToLowerInvariant()
            if($axLow -match '(microsoftwindows\.client|xboxgameoverlay|xboxidentityprovider|xboxspeechtotextoverlay|xbox\.tcui|winget\.source|vclibs|ui\.xaml|windowsappruntime|desktopappinstaller)'){ continue }
            $script:AllRegSnapshot.Add([pscustomobject]@{
                DisplayName     = $axNm
                NameL           = $axLow
                PublisherL      = 'microsoft'
                ChildName       = [string]$ax.PackageFullName
                ChildL          = $axLow
                QuietUninstall  = ''
                UninstallString = ''
                PSPath          = ''
                AppxName        = $axNm
            })
        }
    } catch {}
}

function Test-AlreadyInstalledBeforeInstall([string]$Exe,[string]$Id,[string]$AppName,[string[]]$Keywords=@()){
    if (Test-SLTKnownBinaryInstalled -Wid $Id -AppName $AppName) {
        foreach ($re in $script:AllRegSnapshot) {
            if ($re.NameL.Contains(($AppName -replace '\s*\(.*?\)\s*','').Trim().ToLowerInvariant())) {
                return [pscustomobject]@{Installed=$true;RegEntry=$re}
            }
        }
        return [pscustomobject]@{Installed=$true;RegEntry=$null}
    }
    $genericIgnore = @('client','free','standard','community','files','studio','player','browser','viewer','manager','tweaker','pro','plus','code','app','xbox','teams','office','draw','warp','setup','installer','desktop','server','lite','mini')
    $cleanName = ($AppName -replace '\s*\(.*?\)\s*','').Trim().ToLowerInvariant()
    $widL = $Id.ToLowerInvariant()
    $widTail = if($widL.Contains('.')){ ($widL.Split('.')[-1]) } else { $widL }

    foreach($re in $script:AllRegSnapshot){
        if($widL.Length -gt 3 -and $widL -notin @('na','n/a') -and ($re.ChildL -eq $widL -or ($widL.Contains('.') -and $re.ChildL.Contains($widL)))){
            return [pscustomobject]@{Installed=$true;RegEntry=$re}
        }
        if($cleanName.Length -ge 4 -and ($cleanName -notin $genericIgnore) -and ($re.NameL -eq $cleanName -or $re.NameL.StartsWith($cleanName + ' ') -or ($cleanName.Length -ge 6 -and $re.NameL.Contains($cleanName)))){
            return [pscustomobject]@{Installed=$true;RegEntry=$re}
        }
        if($widTail.Length -ge 5 -and ($widTail -notin $genericIgnore) -and $widL -notin @('na','n/a') -and ($re.NameL -eq $widTail -or $re.NameL.StartsWith($widTail + ' '))){
            return [pscustomobject]@{Installed=$true;RegEntry=$re}
        }
        foreach($kw in $Keywords){
            $kwL = ([string]$kw).Trim().ToLowerInvariant()
            if($kwL -in $genericIgnore){ continue }
            if($kwL.Length -ge 4 -and ($re.NameL -eq $kwL -or $re.NameL.StartsWith($kwL + ' ') -or ($kwL.Length -ge 6 -and $re.NameL.Contains($kwL)))){
                return [pscustomobject]@{Installed=$true;RegEntry=$re}
            }
        }
    }

    if(-not [string]::IsNullOrWhiteSpace($Exe) -and (Test-Path -LiteralPath $Exe) -and $widL -notin @('na','n/a','')){
        try {
            $a=@('list','--id',$Id,'--exact','--accept-source-agreements','--disable-interactivity')
            $r=Invoke-QuietCapture -Exe $Exe -Argv $a -TimeoutSec 15
            if($r.ExitCode -eq 0 -and $r.Output -notmatch '(?i)(No installed package found|No package found|No installed packages|Unrecognized)' -and $r.Output -match [regex]::Escape($Id)){
                return [pscustomobject]@{Installed=$true;RegEntry=$null}
            }
        } catch {}
    }
    return [pscustomobject]@{Installed=$false;RegEntry=$null}
}

function Add-Result([string]$Name,[string]$Wid,[string]$Url,[string]$Status,[string]$Note='',[double]$EtaSub=0.5,[string]$Key=''){
    if($Status -eq 'Installed Successfully'){
        $script:installedCnt++
        $script:currentPhase='Done'
    } elseif($Status -eq 'Uninstalled Successfully'){
        $script:uninstalledCnt++
        $script:currentPhase='Uninstalled'
    } elseif($Status -eq 'Already Installed Skipped' -or $Status -eq 'Skipped'){
        $script:skippedCnt++
        $script:savedMinutes += $EtaSub
        $script:currentPhase='Already Installed'
    } elseif($Status -eq 'Manual Required'){
        $script:manualReq++
        $script:currentPhase='Manual Required'
    } else {
        $script:fail++
        $script:currentPhase='Failed'
    }
    $script:remainingEtaMin = [Math]::Max(0.0, ($script:remainingEtaMin - $EtaSub))
    $script:currentPct=100
    $script:completed = $script:installedCnt + $script:uninstalledCnt + $script:skippedCnt + $script:fail
    $script:last=$Name+' - '+$Status+$(if($Note){' - '+$Note}else{''})
    $script:results.Add([ordered]@{key=$Key;name=$Name;winget=$Wid;url=$Url;status=$Status;note=$Note})
    Write-Status $script:last
    Publish-Progress
}

function Split-SLTCommandString([string]$CmdLine) {
    $raw = [Environment]::ExpandEnvironmentVariables(([string]$CmdLine).Trim())
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    if ($raw.StartsWith('"')) {
        $endQuote = $raw.IndexOf('"', 1)
        if ($endQuote -gt 1) {
            $exePath = $raw.Substring(1, $endQuote - 1).Trim()
            $restArgs = $raw.Substring($endQuote + 1).Trim()
            return [pscustomobject]@{ Exe = $exePath; Args = $restArgs }
        }
    }
    # Match full drive path even with spaces (e.g. C:\Program Files\FileZilla FTP Client\uninstall.exe)
    $driveExeMatch = [regex]::Match($raw, '^([A-Za-z]:\\.+?\.exe)\b(.*)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($driveExeMatch.Success) {
        return [pscustomobject]@{ Exe = $driveExeMatch.Groups[1].Value.Trim(); Args = $driveExeMatch.Groups[2].Value.Trim() }
    }
    $exeMatch = [regex]::Match($raw, '^([^\s]+\.exe)\b(.*)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($exeMatch.Success) {
        return [pscustomobject]@{ Exe = $exeMatch.Groups[1].Value.Trim(); Args = $exeMatch.Groups[2].Value.Trim() }
    }
    return [pscustomobject]@{ Exe = 'cmd.exe'; Args = ('/c "' + $raw + '"') }
}

function Invoke-SLTUninstallSingleItem([object]$Item, [string]$WingetExe) {
    $nm        = [string]$Item.Name
    $wid       = ([string]$Item.Wid).Trim()
    $uninstStr = if ($null -ne $Item.Reg -and $Item.Reg.UninstallString) { ([string]$Item.Reg.UninstallString).Trim() } else { '' }
    $quietStr  = if ($null -ne $Item.Reg -and $Item.Reg.QuietUninstall)  { ([string]$Item.Reg.QuietUninstall).Trim() }  else { '' }
    $childGuid = if ($null -ne $Item.Reg -and $Item.Reg.ChildName)       { ([string]$Item.Reg.ChildName).Trim() }       else { '' }
    $kws       = if ($Item.PSObject.Properties['Keywords'] -and $Item.Keywords) { @($Item.Keywords) } else { @() }

    $appUninstallStart = Get-Date
    $maxUninstallSec   = 60

    Stop-SLTAppProcessesBeforeUninstall -AppName $nm -Wid $wid -UninstallString $uninstStr

    $nmLow  = $nm.ToLowerInvariant()
    $widLow = $wid.ToLowerInvariant()

    if ($nmLow -match 'anydesk' -or $widLow -match 'anydesk') {
        Write-Status "Running dedicated AnyDesk silent removal (--silent --remove)..."
        try { Stop-Service -Name 'AnyDesk' -Force -ErrorAction SilentlyContinue } catch {}
        try { & sc.exe stop AnyDesk 2>$null | Out-Null } catch {}
        try { & sc.exe delete AnyDesk 2>$null | Out-Null } catch {}
        foreach ($adExe in @('C:\Program Files (x86)\AnyDesk\AnyDesk.exe', 'C:\Program Files\AnyDesk\AnyDesk.exe')) {
            if (Test-Path -LiteralPath $adExe) {
                try {
                    $pAd = Start-Process -FilePath $adExe -ArgumentList '--silent --remove' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                    if ($null -ne $pAd) {
                        if (-not $pAd.WaitForExit(30000)) { Stop-SLTProcessTree $pAd.Id }
                    }
                } catch {}
            }
        }
        Stop-SLTAppProcessesBeforeUninstall -AppName 'AnyDesk' -Wid $wid
        foreach ($adDir in @('C:\Program Files (x86)\AnyDesk', 'C:\Program Files\AnyDesk')) {
            if (Test-Path -LiteralPath $adDir) {
                try { Remove-Item -LiteralPath $adDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
        foreach ($rp in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AnyDesk*'
        )) {
            try { Get-Item -Path $rp -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    if ($nmLow -match 'rufus' -or $widLow -match 'rufus') {
        Write-Status ("Running WinGet + Portable cleanup for " + $nm + "...")
        if (-not [string]::IsNullOrWhiteSpace($WingetExe) -and (Test-Path -LiteralPath $WingetExe)) {
            $remW = [Math]::Max(15, ($maxUninstallSec - [int]((Get-Date) - $appUninstallStart).TotalSeconds))
            if ($wid -notin @('na','N/A','') -and $wid.Contains('.')) {
                [void](Invoke-QuietCapture -Exe $WingetExe -Argv @('uninstall','--id',$wid,'-e','--silent','--accept-source-agreements','--disable-interactivity') -TimeoutSec $remW)
            } else {
                [void](Invoke-QuietCapture -Exe $WingetExe -Argv @('uninstall','--name',$nm,'--silent','--accept-source-agreements','--disable-interactivity') -TimeoutSec $remW)
            }
        }
        Stop-SLTAppProcessesBeforeUninstall -AppName $nm -Wid $wid
        $wgPkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        $wgLnkRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
        if ($nmLow -match 'rufus' -or $widLow -match 'rufus') {
            if (Test-Path -LiteralPath $wgPkgRoot) {
                Get-ChildItem -LiteralPath $wgPkgRoot -Directory -Filter 'Rufus*' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path -LiteralPath $wgLnkRoot) {
                Get-ChildItem -LiteralPath $wgLnkRoot -Filter 'rufus*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            foreach ($rp in @(
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Rufus*',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Rufus*',
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Rufus*'
            )) {
                try { Get-Item -Path $rp -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # Dedicated FileZilla silent removal (NSIS uninstaller in Program Files + Registry cleanup)
    if ($nmLow -match 'filezilla' -or $widLow -match 'filezilla') {
        Write-Status "Running dedicated FileZilla silent removal..."
        foreach ($fzUninst in @(
            'C:\Program Files\FileZilla FTP Client\uninstall.exe',
            'C:\Program Files (x86)\FileZilla FTP Client\uninstall.exe'
        )) {
            if (Test-Path -LiteralPath $fzUninst) {
                try {
                    $pFz = Start-Process -FilePath $fzUninst -ArgumentList '/S' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                    if ($null -ne $pFz) { [void]$pFz.WaitForExit(25000) }
                } catch {}
            }
        }
        Start-Sleep -Milliseconds 1500
        Stop-SLTAppProcessesBeforeUninstall -AppName 'FileZilla' -Wid $wid
        foreach ($fzDir in @('C:\Program Files\FileZilla FTP Client', 'C:\Program Files (x86)\FileZilla FTP Client')) {
            if (Test-Path -LiteralPath $fzDir) {
                try { Remove-Item -LiteralPath $fzDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
        foreach ($rp in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FileZilla*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FileZilla*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FileZilla*'
        )) {
            try { Get-Item -Path $rp -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    # Dedicated Microsoft Teams removal (Appx MSTeams + Squirrel Update.exe + Machine-Wide MSI)
    if ($nmLow -match 'teams' -or $widLow -match 'teams') {
        Write-Status "Running dedicated Microsoft Teams removal (Appx + Squirrel + MSI)..."
        foreach ($tmPat in @('*MSTeams*','*MicrosoftTeams*','*Teams*')) {
            try {
                Get-AppxPackage -Name $tmPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework } | ForEach-Object {
                    try { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue } catch {}
                }
                Get-AppxPackage -AllUsers -Name $tmPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework } | ForEach-Object {
                    try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue } catch {}
                }
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $tmPat } | ForEach-Object {
                    try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
            } catch {}
        }
        $sqTeams = Join-Path $env:LOCALAPPDATA 'Microsoft\Teams\Update.exe'
        if (Test-Path -LiteralPath $sqTeams) {
            try {
                $pSq = Start-Process -FilePath $sqTeams -ArgumentList '--uninstall -s' -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
                if ($null -ne $pSq) { [void]$pSq.WaitForExit(25000) }
            } catch {}
        }
        foreach ($tmReg in @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Teams*',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Teams*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Teams*'
        )) {
            try { Get-Item -Path $tmReg -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    # Dedicated Xbox App & Xbox Game Bar removal
    if ($nmLow -match 'xbox' -or $widLow -match '9mv0b5hzvk9z|xbox') {
        Write-Status "Running dedicated Xbox App & Game Bar Appx removal..."
        foreach ($xbPat in @('*Microsoft.GamingApp*','*Microsoft.XboxGamingOverlay*','*XboxApp*')) {
            try {
                Get-AppxPackage -Name $xbPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework } | ForEach-Object {
                    try { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue } catch {}
                }
                Get-AppxPackage -AllUsers -Name $xbPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework } | ForEach-Object {
                    try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue } catch {}
                }
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $xbPat } | ForEach-Object {
                    try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
            } catch {}
        }
    }

    $elapsed = [int]((Get-Date) - $appUninstallStart).TotalSeconds
    if ($elapsed -lt $maxUninstallSec -and ($uninstStr -match '(?i)msiexec' -or $childGuid -match '^\{[0-9A-Fa-f\-]{36}\}$')) {
        $guidMatch = [regex]::Match(($uninstStr + ' ' + $childGuid), '\{[0-9A-Fa-f\-]{36}\}')
        if ($guidMatch.Success) {
            $remSec = [Math]::Max(10, ($maxUninstallSec - $elapsed))
            Write-Status ("Uninstalling MSI " + $nm + ": MsiExec.exe /X" + $guidMatch.Value + " /qn /norestart")
            [void](Invoke-QuietCapture -Exe 'MsiExec.exe' -Argv @('/X' + $guidMatch.Value, '/qn', '/norestart') -TimeoutSec $remSec)
        }
    }

    $elapsed = [int]((Get-Date) - $appUninstallStart).TotalSeconds
    if ($elapsed -lt $maxUninstallSec -and (-not [string]::IsNullOrWhiteSpace($quietStr))) {
        $parsedQ = Split-SLTCommandString $quietStr
        if ($null -ne $parsedQ -and -not [string]::IsNullOrWhiteSpace($parsedQ.Exe) -and (Test-Path -LiteralPath $parsedQ.Exe -ErrorAction SilentlyContinue)) {
            $remSec = [Math]::Max(10, ($maxUninstallSec - $elapsed))
            Write-Status ("Uninstalling via QuietUninstallString: " + $parsedQ.Exe + " " + $parsedQ.Args)
            try {
                $pQ = if ([string]::IsNullOrWhiteSpace($parsedQ.Args)) {
                    Start-Process -FilePath $parsedQ.Exe -WindowStyle Hidden -PassThru -ErrorAction Stop
                } else {
                    Start-Process -FilePath $parsedQ.Exe -ArgumentList $parsedQ.Args -WindowStyle Hidden -PassThru -ErrorAction Stop
                }
                if (-not $pQ.WaitForExit($remSec * 1000)) {
                    Stop-SLTProcessTree $pQ.Id
                }
            } catch {}
        }
    }

    $elapsed = [int]((Get-Date) - $appUninstallStart).TotalSeconds
    if ($elapsed -lt $maxUninstallSec -and (-not [string]::IsNullOrWhiteSpace($uninstStr))) {
        $parsedU = Split-SLTCommandString $uninstStr
        if ($null -ne $parsedU -and -not [string]::IsNullOrWhiteSpace($parsedU.Exe)) {
            $exeExists = ($parsedU.Exe -eq 'cmd.exe' -or $parsedU.Exe -match '(?i)^msiexec' -or (Test-Path -LiteralPath $parsedU.Exe -ErrorAction SilentlyContinue))
            if ($exeExists) {
                $remSec = [Math]::Max(10, ($maxUninstallSec - $elapsed))
                $exeLow = $parsedU.Exe.ToLowerInvariant()
                $extraSilent = '/S'
                if ($exeLow -like '*anydesk*') {
                    $extraSilent = '--silent --remove'
                } elseif ($exeLow -like '*googledrivefs*') {
                    $extraSilent = '--silent --force_stop'
                } elseif ($exeLow -like '*chrome*setup.exe*' -or $uninstStr -match '(?i)--uninstall') {
                    $extraSilent = '--force-uninstall'
                } elseif ($exeLow -like '*unins0*.exe*') {
                    $extraSilent = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
                } elseif ($exeLow -like '*msiexec*') {
                    $extraSilent = '/qn /norestart'
                } elseif ($exeLow -like '*\update.exe') {
                    $extraSilent = '--uninstall -s'
                }
                $combinedArgs = if ($exeLow -like '*anydesk*') { '--silent --remove' } elseif ([string]::IsNullOrWhiteSpace($parsedU.Args)) { $extraSilent } else { ($parsedU.Args + ' ' + $extraSilent) }
                Write-Status ("Uninstalling via UninstallString: " + $parsedU.Exe + " " + $combinedArgs)
                try {
                    $pU = Start-Process -FilePath $parsedU.Exe -ArgumentList $combinedArgs -WindowStyle Hidden -PassThru -ErrorAction Stop
                    if (-not $pU.WaitForExit($remSec * 1000)) {
                        Stop-SLTProcessTree $pU.Id
                    }
                } catch {}
            }
        }
    }

    $elapsed = [int]((Get-Date) - $appUninstallStart).TotalSeconds
    if ($elapsed -lt $maxUninstallSec -and (-not [string]::IsNullOrWhiteSpace($WingetExe)) -and (Test-Path -LiteralPath $WingetExe)) {
        Initialize-SLTInstalledSnapshot
        $midChk = Test-AlreadyInstalledBeforeInstall -Exe '' -Id $wid -AppName $nm -Keywords $kws
        if ($midChk.Installed) {
            $remSec = [Math]::Max(12, ($maxUninstallSec - $elapsed))
            if ($wid -notin @('na','N/A','') -and $wid -notlike 'CUST_*' -and $wid -notlike 'WIN_*' -and ($wid.Contains('.') -or $wid -match '^[0-9A-Z]{12}$')) {
                Write-Status ("Uninstalling via winget ID: " + $wid)
                [void](Invoke-QuietCapture -Exe $WingetExe -Argv @('uninstall','--id',$wid,'-e','--silent','--accept-source-agreements','--disable-interactivity') -TimeoutSec $remSec)
            } else {
                Write-Status ("Uninstalling via winget --name: " + $nm)
                [void](Invoke-QuietCapture -Exe $WingetExe -Argv @('uninstall','--name',$nm,'--silent','--accept-source-agreements','--disable-interactivity') -TimeoutSec $remSec)
            }
        }
    }

    # Generic wildcard Appx removal is intentionally disabled: it could match unrelated packages.
    # Dedicated Appx entries must be uninstalled by their exact package identity.

    Stop-SLTAppProcessesBeforeUninstall -AppName $nm -Wid $wid

    # Poll up to 6 times (up to ~5s) so forked NSIS uninstallers (like FileZilla uninstall.exe /S) finish deleting Registry keys & files
    $stillThere = $true
    for ($vPoll = 0; $vPoll -lt 6; $vPoll++) {
        Start-Sleep -Milliseconds 850
        Initialize-SLTInstalledSnapshot
        $postChk = Test-AlreadyInstalledBeforeInstall -Exe '' -Id $wid -AppName $nm -Keywords $kws
        if (-not $postChk.Installed) {
            $stillThere = $false
            break
        }
    }
    if ($stillThere) {
        Write-Status ("VERIFICATION FAILED: " + $nm + " is still installed after uninstall attempt.")
        return $false
    }

    Write-Status ("VERIFIED UNINSTALLED: " + $nm + " is completely removed from Registry, WinGet & PC.")
    return $true
}

function BulkUninstall([object[]]$Pkgs,[string]$Exe){
    $idxCounter = 0
    foreach($p in $Pkgs){
        $idxCounter++
        $pkgKey   = if($p.PSObject.Properties['key'] -and $p.key){[string]$p.key}else{''}
        $nm       = [string]$p.name
        $wid      = if($p.PSObject.Properties['winget'] -and $p.winget){([string]$p.winget).Trim()}else{'na'}
        $url      = if($p.PSObject.Properties['url'] -and $p.url){[string]$p.url}else{''}
        $sltAct   = if($p.PSObject.Properties['slt_action'] -and $p.slt_action){[string]$p.slt_action}else{''}
        $eta      = if($p.PSObject.Properties['eta_min'] -and $p.eta_min){[double]$p.eta_min}else{0.5}
        $kws      = if($p.PSObject.Properties['match_keywords'] -and $p.match_keywords){@($p.match_keywords)}else{@()}
        $appCat   = if($p.PSObject.Properties['app_category'] -and $p.app_category){[string]$p.app_category}else{'SLT'}
        $directU  = if($p.PSObject.Properties['uninstall_string'] -and $p.uninstall_string){[string]$p.uninstall_string}else{''}
        $directQ  = if($p.PSObject.Properties['quiet_uninstall'] -and $p.quiet_uninstall){[string]$p.quiet_uninstall}else{''}
        $appxNm   = if($p.PSObject.Properties['appx_name'] -and $p.appx_name){[string]$p.appx_name}else{''}
        $childKey = if($p.PSObject.Properties['child_name'] -and $p.child_name){[string]$p.child_name}else{''}
        if($wid.StartsWith('msstore:')){$wid=$wid.Substring(8)}
        $wid = Resolve-SLTCatalogWingetId -RawId $wid -AppName $nm

        $script:current = ("[$idxCounter/$total] " + $nm)
        $script:currentWid = $wid
        $script:currentPhase = 'Uninstalling'
        $script:currentPct = 60
        $script:last = ("Uninstalling ($idxCounter of $total): " + $nm + " (Max 60s)...")
        Publish-Progress

        if($sltAct -eq 'SLT_TOOLS_HUB_SHORTCUT' -or $wid -eq 'SLT.SmartToolsHub'){
            $d1 = [Environment]::GetFolderPath('DesktopDirectory')
            $d2 = [Environment]::GetFolderPath('CommonDesktopDirectory')
            $u1 = Join-Path $d1 'SLT Smart Tools Hub.url'
            $u2 = Join-Path $d2 'SLT Smart Tools Hub.url'
            if((Test-Path -LiteralPath $u1) -or (Test-Path -LiteralPath $u2)){
                foreach($uf in @($u1,$u2)){ if(Test-Path -LiteralPath $uf){ Remove-Item -LiteralPath $uf -Force -ErrorAction SilentlyContinue } }
                if ((-not (Test-Path -LiteralPath $u1)) -and (-not (Test-Path -LiteralPath $u2))) {
                    Add-Result $nm $wid $url 'Uninstalled Successfully' 'Verified removed from Desktop' $eta $pkgKey
                } else {
                    Add-Result $nm $wid $url 'Failed' 'Failed - Still Installed - Try Again' $eta $pkgKey
                }
            } else {
                Add-Result $nm $wid $url 'Skipped' 'Not Installed - Package is not currently installed on this PC' $eta $pkgKey
            }
            continue
        }

        if($appCat -eq 'WINDOWS' -or -not [string]::IsNullOrWhiteSpace($appxNm)){
            Stop-SLTAppProcessesBeforeUninstall -AppName $nm -Wid $wid
            $patsToRemove = New-Object System.Collections.Generic.List[string]
            if(-not [string]::IsNullOrWhiteSpace($appxNm)){
                $patsToRemove.Add(('*' + $appxNm + '*'))
            }
            $nmLowWin = $nm.ToLowerInvariant()
            if($nmLowWin -match 'xbox'){
                $patsToRemove.Add('*Microsoft.GamingApp*')
                $patsToRemove.Add('*Microsoft.XboxGamingOverlay*')
            } elseif($nmLowWin -match 'teams'){
                $patsToRemove.Add('*MSTeams*')
                $patsToRemove.Add('*MicrosoftTeams*')
            } elseif($patsToRemove.Count -eq 0){
                $patsToRemove.Add(('*' + (($nm -replace '\s*\(.*?\)\s*','').Trim() -replace '\s+','*') + '*'))
            }

            foreach($tPat in $patsToRemove){
                try {
                    $curFound = @(Get-AppxPackage -Name $tPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework })
                    foreach($pf in $curFound){
                        try { Remove-AppxPackage -Package $pf.PackageFullName -ErrorAction SilentlyContinue } catch {}
                    }
                    $allFound = @(Get-AppxPackage -AllUsers -Name $tPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework })
                    foreach($af in $allFound){
                        try { Remove-AppxPackage -Package $af.PackageFullName -AllUsers -ErrorAction SilentlyContinue } catch {}
                    }
                    $provFound = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $tPat })
                    foreach($prf in $provFound){
                        try { Remove-AppxProvisionedPackage -Online -PackageName $prf.PackageName -ErrorAction SilentlyContinue | Out-Null } catch {}
                    }
                } catch {}
            }
            if(-not [string]::IsNullOrWhiteSpace($Exe) -and $wid -notin @('na','N/A','')){
                try {
                    [void](Invoke-QuietCapture -Exe $Exe -Argv @('uninstall','--id',$wid,'--silent','--accept-source-agreements','--disable-interactivity') -TimeoutSec 45)
                } catch {}
            }
            Start-Sleep -Milliseconds 600
            $checkPat = $patsToRemove[0]
            $stillAppx = @(Get-AppxPackage -Name $checkPat -ErrorAction SilentlyContinue | Where-Object { -not $_.NonRemovable -and -not $_.IsFramework -and [string]$_.SignatureKind -ne 'System' })
            if($stillAppx.Count -eq 0){
                Add-Result $nm $wid $url 'Uninstalled Successfully' 'Verified removed Windows System/Store App' $eta $pkgKey
            } else {
                Add-Result $nm $wid $url 'Failed' 'Failed - Still Installed - Try Again' $eta $pkgKey
            }
            continue
        }

        Initialize-SLTInstalledSnapshot
        $chkBefore = Test-AlreadyInstalledBeforeInstall -Exe $Exe -Id $wid -AppName $nm -Keywords $kws
        $regObj = $chkBefore.RegEntry
        if ($null -eq $regObj -and (-not [string]::IsNullOrWhiteSpace($directU) -or -not [string]::IsNullOrWhiteSpace($directQ) -or -not [string]::IsNullOrWhiteSpace($childKey))) {
            $regObj = [pscustomobject]@{
                DisplayName     = $nm
                ChildName       = $childKey
                QuietUninstall  = $directQ
                UninstallString = $directU
            }
        } elseif ((-not $chkBefore.Installed) -and [string]::IsNullOrWhiteSpace($directU) -and [string]::IsNullOrWhiteSpace($directQ)) {
            Add-Result $nm $wid $url 'Skipped' 'Not Installed - Package is not currently installed on this PC' $eta $pkgKey
            continue
        }

        $itemObj = [pscustomobject]@{
            Pkg = $p; Key = $pkgKey; Name = $nm; Wid = $wid; Url = $url; Eta = $eta; Reg = $regObj; Keywords = $kws
        }

        $uninstOk = Invoke-SLTUninstallSingleItem -Item $itemObj -WingetExe $Exe
        if ($uninstOk) {
            Add-Result $nm $wid $url 'Uninstalled Successfully' 'Verified removed from PC' $eta $pkgKey
        } else {
            Add-Result $nm $wid $url 'Failed' 'Failed - Still Installed - Try Again' $eta $pkgKey
        }
    }
}

try {
    $rootDir = Split-Path -Parent $PSScriptRoot
    $job=Get-Content -LiteralPath $Manifest -Raw|ConvertFrom-Json
    $packages=@($job.packages);$total=$packages.Count
    if($total -eq 0 -or $total -gt 250){throw 'Manifest has no packages or exceeds maximum batch size (250).'}
    $verb = [string]$job.verb
    if($verb -notin @('Install','Uninstall')){throw "Unsupported package action: $verb"}
    $progress=[string]$job.progress;$log=[string]$job.log
    $useOfflineCache = if($job.PSObject.Properties['offlineCache']){[bool]$job.offlineCache}else{$false}
    $cacheRoot       = if($job.PSObject.Properties['cacheDir'] -and $job.cacheDir){[string]$job.cacheDir}else{(Join-Path $rootDir 'SLT_Offline_Cache')}

    if(-not $log -or -not $progress){throw 'Missing progress or queue log path.'}
    New-Item -ItemType Directory -Path (Split-Path -Parent $log) -Force|Out-Null

    $totalSizeMb = 0
    $remainingEtaMin = 0.0
    foreach($pk in $packages){
        $sMb = if($pk.PSObject.Properties['size_mb'] -and $pk.size_mb){[int]$pk.size_mb}else{60}
        $eMn = if($pk.PSObject.Properties['eta_min'] -and $pk.eta_min){[double]$pk.eta_min}else{0.6}
        $totalSizeMb += $sMb
        $remainingEtaMin += $eMn
    }

    $wg=Get-Command winget.exe -ErrorAction SilentlyContinue
    if($null -eq $wg){
        $wgCandidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
        if(Test-Path -LiteralPath $wgCandidate){
            $wg = [pscustomobject]@{ Source = $wgCandidate }
        }
    }
    $exe = if($null -ne $wg){[string]$wg.Source}else{''}

    if (-not [string]::IsNullOrWhiteSpace($exe) -and (Test-Path -LiteralPath $exe)) {
        try {
            $pSet = Start-Process -FilePath $exe -ArgumentList @('settings','--enable','InstallerHashOverride') -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            if ($null -ne $pSet) { [void]$pSet.WaitForExit(3000) }
        } catch {}
    }

    Write-Status ('Taking fast snapshot of installed apps before ' + $verb + '...')
    $current = 'Pre-Checking Installed Apps on This PC...'
    $currentPhase = 'Checking'
    $currentPct = 20
    $last = 'Scanning Registry & WinGet to verify package states...'
    Publish-Progress

    Initialize-SLTInstalledSnapshot

    if($verb -eq 'Uninstall'){
        BulkUninstall -Pkgs $packages -Exe $exe
    } else {
        $missingQueue = New-Object System.Collections.Generic.List[object]

        foreach($p in $packages){
            $pkgKey = if($p.PSObject.Properties['key']){[string]$p.key}else{''}
            $nm     = [string]$p.name
            $wid    = Resolve-SLTCatalogWingetId -RawId ([string]$p.winget) -AppName $nm
            $url    = if($p.PSObject.Properties['url']){[string]$p.url}else{''}
            $sltAct = if($p.PSObject.Properties['slt_action']){[string]$p.slt_action}else{''}
            $eta    = if($p.PSObject.Properties['eta_min'] -and $p.eta_min){[double]$p.eta_min}else{0.6}
            $kws    = if($p.PSObject.Properties['match_keywords'] -and $p.match_keywords){@($p.match_keywords)}else{@()}
            if($wid.StartsWith('msstore:')){$wid=$wid.Substring(8)}

            if($sltAct -eq 'SLT_TOOLS_HUB_SHORTCUT' -or $wid -eq 'SLT.SmartToolsHub'){
                $u1 = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'SLT Smart Tools Hub.url'
                $u2 = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'SLT Smart Tools Hub.url'
                if((Test-Path -LiteralPath $u1) -or (Test-Path -LiteralPath $u2)){
                    Add-Result $nm $wid $url 'Already Installed Skipped' 'Already Installed - Package already exists on this PC - No download needed' $eta $pkgKey
                } else {
                    $missingQueue.Add($p)
                }
                continue
            }
            if($sltAct -eq 'SLT_ARABIC_PACK' -or $wid -eq 'SLT.ArabicLanguagePack'){
                $hasAr = $false
                try {
                    $ll = Get-WinUserLanguageList -ErrorAction SilentlyContinue
                    if($ll -and @($ll | Where-Object { $_.LanguageTag -like 'ar*' }).Count -gt 0){ $hasAr = $true }
                } catch {}
                if($hasAr){
                    Add-Result $nm $wid $url 'Already Installed Skipped' 'Already Installed - Package already exists on this PC - No download needed' $eta $pkgKey
                } else {
                    $missingQueue.Add($p)
                }
                continue
            }

            $chk = Test-AlreadyInstalledBeforeInstall -Exe $exe -Id $wid -AppName $nm -Keywords $kws
            if($chk.Installed){
                Add-Result $nm $wid $url 'Already Installed Skipped' 'Already Installed - Package already exists on this PC - No download needed' $eta $pkgKey
            } else {
                $missingQueue.Add($p)
            }
        }

        foreach($p in $missingQueue){
            $pkgKey = if($p.PSObject.Properties['key']){[string]$p.key}else{''}
            $current=[string]$p.name
            $wid = Resolve-SLTCatalogWingetId -RawId ([string]$p.winget) -AppName $current
            $url=if($p.PSObject.Properties['url']){[string]$p.url}else{''}
            $sltAction=if($p.PSObject.Properties['slt_action']){[string]$p.slt_action}else{''}
            $currentSizeMb=if($p.PSObject.Properties['size_mb'] -and $p.size_mb){[int]$p.size_mb}else{60}
            $pkgEta=if($p.PSObject.Properties['eta_min'] -and $p.eta_min){[double]$p.eta_min}else{0.6}
            if($wid.StartsWith('msstore:')){$wid=$wid.Substring(8)}
            $currentWid=$wid

            if($sltAction -eq 'SLT_TOOLS_HUB_SHORTCUT' -or $wid -eq 'SLT.SmartToolsHub'){
                $currentPhase='Installing'
                $currentPct=75
                $last=('Installing '+$current+' (.url Desktop Shortcut)...')
                Publish-Progress
                try {
                    $srcIco = Join-Path $rootDir 'assets\SLT_PC_CARE_PRO.ico'
                    $iconDir = Join-Path $env:ProgramData 'SmartLifeTeck\PCCarePro\Icons'
                    New-Item -ItemType Directory -Path $iconDir -Force -ErrorAction SilentlyContinue | Out-Null
                    $destIco = Join-Path $iconDir 'SLT_PC_CARE_PRO.ico'
                    if(Test-Path -LiteralPath $srcIco){ Copy-Item -LiteralPath $srcIco -Destination $destIco -Force -ErrorAction SilentlyContinue }
                    $urlText = @(
                        '[InternetShortcut]',
                        'URL=https://smartlifeteck.com/tools',
                        ('IconFile=' + $destIco),
                        'IconIndex=0',
                        'HotKey=0',
                        'IDList='
                    ) -join "`r`n"
                    # Existing public/user desktop shortcuts are user data; never remove or overwrite them.
                    foreach($d in @([Environment]::GetFolderPath('DesktopDirectory'))){
                        if(-not [string]::IsNullOrWhiteSpace($d) -and (Test-Path -LiteralPath $d)){
                            $uf = Join-Path $d 'SLT Smart Tools Hub.url'
                            if (-not (Test-Path -LiteralPath $uf) -and -not (Test-Path -LiteralPath (Join-Path $d 'SLT Smart Tools Hub.lnk'))) {
                                [IO.File]::WriteAllText($uf, ($urlText + "`r`n"), [Text.Encoding]::ASCII)
                            } else { Log-SLT ("Existing Tools Hub shortcut preserved in $d") }
                        }
                    }
                    Add-Result $current $wid $url 'Installed Successfully' 'Created SLT Smart Tools Hub.url on Desktop' $pkgEta $pkgKey
                } catch {
                    Add-Result $current $wid $url 'Failed' 'Failed - Server Busy - Try Again Later' $pkgEta $pkgKey
                }
                continue
            }

            if($sltAction -eq 'SLT_ARABIC_PACK' -or $wid -eq 'SLT.ArabicLanguagePack'){
                $currentPhase='Installing'
                $currentPct=75
                $last=('Installing '+$current+'...')
                Publish-Progress
                try {
                    $ll = Get-WinUserLanguageList -ErrorAction Stop
                    $ll.Add('ar-SA')
                    Set-WinUserLanguageList -LanguageList $ll -Force -ErrorAction Stop
                    Add-Result $current $wid $url 'Installed Successfully' 'Added Arabic (ar-SA) keyboard & font support' $pkgEta $pkgKey
                } catch {
                    Add-Result $current $wid $url 'Failed' 'Failed - Server Busy - Try Again Later' $pkgEta $pkgKey
                }
                continue
            }

            $currentPhase='Installing'
            $currentPct=75
            $last=('Installing '+$current+' ('+$currentSizeMb+' MB | Max 100s Timeout)...')
            Publish-Progress

            $appStartTime = Get-Date
            $maxAppTimeoutSec = if ($wid -eq 'Google.GoogleDrive' -or $currentSizeMb -ge 200) { 300 } else { 100 }
            Write-Status ('Installing '+$current+' ('+$wid+') [Max '+$maxAppTimeoutSec+'s timeout]')

            try {
                $installedOk = $false
                $alreadyOk   = $false
                $timedOut    = $false
                $kws = if($p.PSObject.Properties['match_keywords'] -and $p.match_keywords){@($p.match_keywords)}else{@()}

                # For Google.GoogleDrive (~280 MB evergreen installer where WinGet Admin hash-check frequently fails),
                # run the verified Official Google Direct Silent Installer FIRST!
                if ($wid -eq 'Google.GoogleDrive') {
                    if (Invoke-DirectOfficialSilentFallback -Wid $wid -AppName $current -RemainSec 240) {
                        $installedOk = $true
                    }
                }

                if ((-not $installedOk) -and (-not [string]::IsNullOrWhiteSpace($exe)) -and (Test-Path -LiteralPath $exe) -and $wid -notin @('na','N/A','')) {
                    $isStorePkg = ($wid -match '^[0-9A-Z]{12}$')
                    $arguments = if ($isStorePkg) {
                        @('install','-e','--id',$wid,'--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                    } else {
                        @('install','-e','--id',$wid,'--source','winget','--silent','--force','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                    }
                    if ($wid -eq 'Blizzard.BattleNet') {
                        $arguments += @('--locale','en-US')
                    }

                    $r = Invoke-QuietCapture -Exe $exe -Argv $arguments -TimeoutSec $maxAppTimeoutSec
                    if ($r.TimedOut) {
                        $timedOut = $true
                        Stop-SLTAppProcessesBeforeUninstall -AppName $current -Wid $wid
                    } else {
                        $u = if ($r.ExitCode -ne -1) { [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$r.ExitCode),0) } else { 0 }
                        if ($r.Output -match '(?i)(already installed|existing package already installed|package is already installed|No available upgrade|No newer package versions)') {
                            $alreadyOk = $true
                        } elseif ($u -in @(0x8A150061, 0x8A15002B)) {
                            $alreadyOk = $true
                        }
                    }

                    # Verify if Step 1 actually installed the app on disk/Registry!
                    if (-not $alreadyOk) {
                        Initialize-SLTInstalledSnapshot
                        $ver1 = Test-AlreadyInstalledBeforeInstall -Exe $exe -Id $wid -AppName $current -Keywords $kws
                        if ($ver1.Installed) {
                            $installedOk = $true
                        }
                    }

                    # Step 2: If not yet installed on disk/Registry and within 100s budget, retry with --ignore-security-hash
                    $elapsed1 = [int]((Get-Date) - $appStartTime).TotalSeconds
                    if ((-not $installedOk) -and (-not $alreadyOk) -and (-not $timedOut) -and ($elapsed1 -lt 75)) {
                        $rem1 = [Math]::Max(20, ($maxAppTimeoutSec - $elapsed1))
                        $retryArgs = @('install','-e','--id',$wid,'--silent','--force','--ignore-security-hash','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
                        $r2 = Invoke-QuietCapture -Exe $exe -Argv $retryArgs -TimeoutSec $rem1
                        if ($r2.TimedOut) {
                            $timedOut = $true
                            Stop-SLTAppProcessesBeforeUninstall -AppName $current -Wid $wid
                        } else {
                            Initialize-SLTInstalledSnapshot
                            $ver2 = Test-AlreadyInstalledBeforeInstall -Exe $exe -Id $wid -AppName $current -Keywords $kws
                            if ($ver2.Installed) {
                                $installedOk = $true
                            }
                        }
                    }
                }

                # Step 3: Direct official silent installer fallback (Google Drive, Chrome, CCleaner, AnyDesk) + verification
                if ((-not $installedOk) -and (-not $alreadyOk) -and $wid -ne 'Google.GoogleDrive') {
                    if (Invoke-DirectOfficialSilentFallback -Wid $wid -AppName $current -RemainSec 120) {
                        $installedOk = $true
                    }
                }

                # Final mandatory verification before claiming Installed Successfully!
                if ($installedOk -and (-not $alreadyOk)) {
                    Initialize-SLTInstalledSnapshot
                    $finalVerify = Test-AlreadyInstalledBeforeInstall -Exe $exe -Id $wid -AppName $current -Keywords $kws
                    if (-not $finalVerify.Installed) {
                        $installedOk = $false
                    }
                }

                if ($installedOk) {
                    Add-Result $current $wid $url 'Installed Successfully' 'Verified installed on this PC' $pkgEta $pkgKey
                } elseif ($alreadyOk) {
                    Add-Result $current $wid $url 'Already Installed Skipped' 'Already Installed - Package already exists on this PC - No download needed' $pkgEta $pkgKey
                } else {
                    Add-Result $current $wid $url 'Failed' 'Failed - Server Busy - Try Again Later' $pkgEta $pkgKey
                }
            } catch {
                Add-Result $current $wid $url 'Failed' 'Failed - Server Busy - Try Again Later' $pkgEta $pkgKey
            }
        }
    }

    $current='All Tasks Complete'
    $currentPhase='Done'
    $currentPct=100
    $remainingEtaMin=0.0
    if($verb -eq 'Uninstall'){
        $last=('Uninstalled: '+$uninstalledCnt+'  |  Skipped: '+$skippedCnt+'  |  Failed: '+$fail)
    } else {
        $last=('Installed: '+$installedCnt+'  |  Already: '+$skippedCnt+'  |  Failed: '+$fail)
    }
    # Preserve Microsoft.WinGet.Source. Removing this package after every queue can break
    # future WinGet source operations; Sysprep-specific cleanup is a separate explicit workflow.
    Write-Status ('SUMMARY: '+$last)
    Publish-Progress 'Finished'
} catch {
    $current='Failed'
    $currentPhase='Failed'
    $last=$_.Exception.Message
    try{Write-Status ('FATAL '+$last);Publish-Progress 'Fatal'}catch{}
    exit 1
}
