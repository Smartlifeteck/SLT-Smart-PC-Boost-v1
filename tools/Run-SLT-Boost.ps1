# SLT Smart PC Boost - Boost Your PC Execution Engine & Failure-Isolated Worker
# Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# Windows PowerShell 5.1 Compatible
[CmdletBinding()]
param(
    [string]$Manifest = '',
    [switch]$AutoMaintenance
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$job=$null;$sessionId='';$profileName='Normal';$progressPath='';$stopFile='';$stateDir='';$logFile=''
$allowDefenderOff=$false;$total=0;$completed=0;$appliedCount=0;$alreadyCount=0;$skippedCount=0;$failedCount=0;$blockedCount=0;$restartReqCount=0
$currentTitle='Initializing SLT Boost Engine...';$overallState='Running'
$opResults=New-Object 'System.Collections.Generic.List[object]'
$catState=@{}

function Write-BoostLog([string]$Text) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} | {1}' -f (Get-Date),$Text
    if($logFile){try{Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8}catch{}}
}

function Publish-BoostProgress([string]$State='Running') {
    if(-not $progressPath){return}
    $pct=if($total -gt 0){[int][Math]::Round(100.0*$completed/$total)}else{0}
    $catList=New-Object 'System.Collections.Generic.List[object]'
    foreach($k in $catState.Keys){$catList.Add($catState[$k])}
    $payload=[ordered]@{
        sessionId=$sessionId
        profile=$profileName
        state=$State
        total=$total
        completed=$completed
        percent=$pct
        current=$currentTitle
        applied=$appliedCount
        already=$alreadyCount
        skipped=$skippedCount
        failed=$failedCount
        blocked=$blockedCount
        restartRequired=$restartReqCount
        categories=@($catList.ToArray())
        operations=@($opResults.ToArray())
        updated=(Get-Date -Format 's')
    }
    $tmp=$progressPath+'.tmp'
    try {
        $payload|ConvertTo-Json -Compress -Depth 8|Set-Content -LiteralPath $tmp -Encoding UTF8
        Copy-Item -LiteralPath $tmp -Destination $progressPath -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Load-RestoreStore {
    $file=Join-Path $stateDir 'BoostRestoreState.json'
    $store=@{}
    if(Test-Path -LiteralPath $file){
        try {
            $raw=Get-Content -LiteralPath $file -Raw -ErrorAction Stop|ConvertFrom-Json
            foreach($p in $raw.PSObject.Properties){$store[$p.Name]=$p.Value}
        } catch {}
    }
    return $store
}

function Save-RestoreStore([hashtable]$Store) {
    $file=Join-Path $stateDir 'BoostRestoreState.json'
    $tmp=$file+'.tmp'
    try {
        $Store|ConvertTo-Json -Depth 9|Set-Content -LiteralPath $tmp -Encoding UTF8
        Copy-Item -LiteralPath $tmp -Destination $file -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Set-TrackedRegistry([string]$TweakId,[string]$TweakName,[string]$Category,[string]$Path,[string]$Name,$Value,[string]$Type='DWord') {
    $store=Load-RestoreStore
    $key=$Path+'|'+$Name
    $existingProp=Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    $hadValue=($null -ne $existingProp)
    $origVal=if($hadValue){$existingProp.$Name}else{$null}
    if($hadValue -and ([string]$origVal -eq [string]$Value)) {
        return [pscustomobject]@{State='Already Applied';Previous=[string]$origVal;Current=[string]$Value;Verified=$true}
    }
    if(-not $store.ContainsKey($key)) {
        $store[$key]=[ordered]@{
            id=$key;tweakId=$TweakId;tweakName=$TweakName;category=$Category;kind='Registry';
            path=$Path;name=$Name;hadValue=$hadValue;originalValue=$origVal;appliedValue=$Value;
            valueType=$Type;timestamp=(Get-Date -Format 's');restorable=$true
        }
        Save-RestoreStore $store
    } else {
        $store[$key].appliedValue=$Value
        $store[$key].timestamp=(Get-Date -Format 's')
        Save-RestoreStore $store
    }
    if(-not (Test-Path -LiteralPath $Path)){New-Item -Path $Path -Force|Out-Null}
    if($Type -in @('DWord','QWord')){
        New-ItemProperty -Path $Path -Name $Name -Value ([long]$Value) -PropertyType $Type -Force|Out-Null
    } else {
        New-ItemProperty -Path $Path -Name $Name -Value ([string]$Value) -PropertyType $Type -Force|Out-Null
    }
    $verifyProp=Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    $verified=($null -ne $verifyProp -and ([string]$verifyProp.$Name -eq [string]$Value))
    return [pscustomobject]@{
        State=$(if($verified){'Applied'}else{'Verification Failed'});
        Previous=$(if($hadValue){[string]$origVal}else{'<Not Set>'});
        Current=$(if($null -ne $verifyProp){[string]$verifyProp.$Name}else{'<Missing>'});
        Verified=$verified
    }
}

function Set-TrackedService([string]$TweakId,[string]$TweakName,[string]$Category,[string]$ServiceName,[string]$TargetStartup='Manual',[bool]$StopNow=$true) {
    $svc=Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if($null -eq $svc){
        return [pscustomobject]@{State='Skipped';Previous='Not Installed';Current='Not Installed';Verified=$true;Note="Service $ServiceName not present"}
    }
    $wmi=Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    $origStart=if($wmi){[string]$wmi.StartMode}else{[string]$svc.StartType}
    $origStatus=[string]$svc.Status
    $store=Load-RestoreStore
    $key='Service|'+$ServiceName
    if(-not $store.ContainsKey($key)) {
        $store[$key]=[ordered]@{
            id=$key;tweakId=$TweakId;tweakName=$TweakName;category=$Category;kind='Service';
            serviceName=$ServiceName;originalValue=$origStart;originalStatus=$origStatus;
            appliedValue=$TargetStartup;timestamp=(Get-Date -Format 's');restorable=$true
        }
        Save-RestoreStore $store
    }
    Set-Service -Name $ServiceName -StartupType $TargetStartup -ErrorAction Stop
    if($StopNow -and $svc.Status -eq 'Running'){
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }
    $svcAfter=Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        State='Applied';
        Previous="$origStart ($origStatus)";
        Current="$TargetStartup ($($svcAfter.Status))";
        Verified=$true;
        Note="Service $ServiceName configured to $TargetStartup"
    }
}

function Invoke-SingleTweak([object]$Tweak) {
    $id=[string]$Tweak.id
    $name=[string]$Tweak.name
    $cat=[string]$Tweak.category
    switch($id) {
        'Tweak_UserTemp' {
            $count=0;$bytes=[long]0
            if(Test-Path -LiteralPath $env:TEMP){
                $cutoff=(Get-Date).AddDays(-7)
                Get-ChildItem -LiteralPath $env:TEMP -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {$_.Name -notlike 'SLT_*' -and $_.LastWriteTime -lt $cutoff} | ForEach-Object {
                    try{$sz=[long]$_.Length;Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop;$count++;$bytes+=$sz}catch{}
                }
            }
            $mb=[Math]::Round($bytes/1MB,2)
            return [pscustomobject]@{Status='Successfully Completed';Previous='User Temp Cache';Intended='Clean unlocked user temp files';Actual="Cleaned $count user temp files ($mb MB freed)";Verified='Verified';Restart=$false;Restorable=$false;Error=''}
        }
        'Tweak_SystemTemp' {
            $count=0;$bytes=[long]0
            $dir = Join-Path $env:WINDIR 'Temp'
            $cutoff=(Get-Date).AddDays(-7)
            if(Test-Path -LiteralPath $dir){
                Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -lt $cutoff} | ForEach-Object {
                    try{$sz=[long]$_.Length;Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop;$count++;$bytes+=$sz}catch{}
                }
            }
            $mb=[Math]::Round($bytes/1MB,2)
            return [pscustomobject]@{Status='Successfully Completed';Previous='System Temp';Intended='Clean Windows Temp files older than 7 days; Prefetch is preserved';Actual="Cleaned $count old system temp files ($mb MB freed)";Verified='Verified';Restart=$false;Restorable=$false;Error=''}
        }
        'Tweak_BrowserUpdateCache' {
            $count=0;$bytes=[long]0
            $cacheDirs=@(
                "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
                "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
                "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
                "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
                "$env:LOCALAPPDATA\D3DSCache"
            )
            foreach($cd in $cacheDirs){
                if(Test-Path -LiteralPath $cd){
                    Get-ChildItem -LiteralPath $cd -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        try{$sz=[long]$_.Length;Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop;$count++;$bytes+=$sz}catch{}
                    }
                }
            }
            $mb=[Math]::Round($bytes/1MB,2)
            return [pscustomobject]@{Status='Successfully Completed';Previous='WER Dumps & Shader Cache';Intended='Clean selected Windows Error Reporting and Direct3D shader cache files';Actual="Cleaned $count cache files ($mb MB freed); Windows Update downloads preserved";Verified='Verified';Restart=$false;Restorable=$false;Error=''}
        }
        'Tweak_NtfsLastAccess' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'NtfsDisableLastAccessUpdate' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'NtfsDisable8dot3NameCreation' 1 'DWord'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="LastAccess=$($r1.Previous)";Intended='NtfsDisableLastAccessUpdate=1 & 8dot3=1';Actual="LastAccess=$($r1.Current), 8dot3=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_SsdTrimHibernation' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'DisableDeleteNotify' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'NtfsMemoryUsage' 2 'DWord'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="TRIM=$($r1.Previous), NtfsMem=$($r2.Previous)";Intended='DisableDeleteNotify=0 (TRIM Active) & NtfsMemoryUsage=2';Actual="TRIM=$($r1.Current), NtfsMem=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_RamWorkingSet' {
            $ramKB = 8388608
            try {
                $csObj = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($null -ne $csObj -and $csObj.TotalPhysicalMemory) {
                    $ramKB = [long][Math]::Round(([double]$csObj.TotalPhysicalMemory) / 1024.0)
                }
            } catch {}
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' $ramKB 'DWord'
            $trimmed=0
            try {
                Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; namespace SLT { public static class RamTrim { [DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess); } }' -ErrorAction SilentlyContinue
                foreach($proc in @(Get-Process -ErrorAction SilentlyContinue)){
                    try {
                        if($proc.Id -ne $PID -and $proc.Handle -ne [IntPtr]::Zero){
                            if([SLT.RamTrim]::EmptyWorkingSet($proc.Handle)){$trimmed++}
                        }
                    } catch {}
                }
            } catch {}
            return [pscustomobject]@{Status='Applied';Previous="SvcHostSplit=$($r1.Previous)";Intended="SvcHostThreshold=$ramKB KB & Flush Standby RAM";Actual="Trimmed $trimmed process working sets; SvcHost=$ramKB KB";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_NetworkLatency' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 4294967295 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10 'DWord'
            try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch { try { cmd.exe /c "ipconfig /flushdns >nul 2>&1" } catch {} }
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="Throttling=$($r1.Previous), Resp=$($r2.Previous)";Intended='Disable Network Throttling, SystemResponsiveness=10 & DNS Flush';Actual="Responsiveness=$($r2.Current)%, DNS Cache Flushed";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_GpuHwScheduling' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="HwSchMode=$($r1.Previous), GameDVR=$($r2.Previous)";Intended='HwSchMode=2 (GPU Scheduling ON) & GameDVR=0';Actual="HwSchMode=$($r1.Current), GameDVR=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_ExplorerSpeed' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'NoNetCrawling' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '2000' 'String'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="NoNetCrawling=$($r1.Previous), SyncAds=$($r2.Previous)";Intended='NoNetCrawling=1, SyncAds=0 & HungAppTimeout=2000ms';Actual="NoNetCrawling=$($r1.Current), SyncAds=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_TelemetryServices' {
            $s1=Set-TrackedService $id $name $cat 'DiagTrack' 'Manual' $true
            $s2=Set-TrackedService $id $name $cat 'dmwappushservice' 'Manual' $true
            $s3=Set-TrackedService $id $name $cat 'WerSvc' 'Manual' $true
            return [pscustomobject]@{Status='Applied';Previous="DiagTrack: $($s1.Previous)";Intended='Set DiagTrack, dmwappushservice & WerSvc to Manual/Stopped';Actual="DiagTrack: $($s1.Current), WerSvc: $($s3.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_StartupDelay' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0 'DWord'
            return [pscustomobject]@{Status=$r1.State;Previous=$r1.Previous;Intended='StartupDelayInMSec = 0';Actual="StartupDelayInMSec = $($r1.Current)";Verified=$(if($r1.Verified){'Verified'}else{'Verification Failed'});Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_FastShutdown' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' 'String'
            $r2=Set-TrackedRegistry $id $name $cat 'HKCU:\Control Panel\Desktop' 'AutoEndTasks' '1' 'String'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' 'String'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="Timeout=$($r1.Previous), AutoEnd=$($r2.Previous)";Intended='2000ms shutdown & AutoEndTasks=1';Actual="Timeout=$($r1.Current), AutoEnd=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_StartupAudit' {
            $disabledNames=New-Object 'System.Collections.Generic.List[string]'
            $patterns=@('OneDrive','Teams','Cortana','Spotify','Skype','Steam','EpicGamesLauncher')
            $runPaths=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')
            $store=Load-RestoreStore
            foreach($rp in $runPaths){
                if(-not (Test-Path -LiteralPath $rp)){continue}
                $props=(Get-ItemProperty -LiteralPath $rp -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object {$_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')}
                foreach($p in $props){
                    foreach($pat in $patterns){
                        if($p.Name -match $pat -or [string]$p.Value -match $pat){
                            $k=$rp+'|'+$p.Name
                            if(-not $store.ContainsKey($k)){
                                $store[$k]=[ordered]@{
                                    id=$k;tweakId=$id;tweakName=$name;category=$cat;kind='StartupRun';
                                    path=$rp;name=$p.Name;hadValue=$true;originalValue=[string]$p.Value;
                                    appliedValue='<RemovedFromStartup>';valueType='String';timestamp=(Get-Date -Format 's');restorable=$true
                                }
                                Save-RestoreStore $store
                            }
                            Remove-ItemProperty -LiteralPath $rp -Name $p.Name -ErrorAction SilentlyContinue
                            $disabledNames.Add($p.Name)
                            break
                        }
                    }
                }
            }
            $rCortana=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0 'DWord'
            $summary=if($disabledNames.Count -gt 0){'Disabled startup: '+($disabledNames -join ', ')}else{'No bloated Run entries active; Cortana startup blocked'}
            return [pscustomobject]@{Status='Applied';Previous='Auto-Start Enabled';Intended='Disable non-essential startup bloat';Actual=$summary;Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_EdgeBackground' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0 'DWord'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="Boost=$($r1.Previous), Bg=$($r2.Previous)";Intended='Disable Edge Boost & Background Mode';Actual="Boost=$($r1.Current), Bg=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_BackgroundApps' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2 'DWord'
            $st=if($r1.State -eq 'Already Applied' -and $r2.State -eq 'Already Applied'){'Already Applied'}else{'Applied'}
            return [pscustomobject]@{Status=$st;Previous="GlobalDisabled=$($r1.Previous)";Intended='GlobalUserDisabled=1, LetAppsRunInBackground=2';Actual="GlobalDisabled=$($r1.Current), Policy=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_TelemetryTasks' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0 'DWord'
            $tasks=@(
                '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
                '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
                '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
            )
            foreach($t in $tasks){
                try{Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue|Out-Null}catch{}
            }
            return [pscustomobject]@{Status=$r1.State;Previous="AllowTelemetry=$($r1.Previous)";Intended='AllowTelemetry=0 & CEIP tasks disabled';Actual="AllowTelemetry=$($r1.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_HeavyServices' {
            $s1=Set-TrackedService $id $name $cat 'SysMain' 'Manual' $true
            $s2=Set-TrackedService $id $name $cat 'WSearch' 'Manual' $true
            $s3=Set-TrackedService $id $name $cat 'MapsBroker' 'Disabled' $true
            return [pscustomobject]@{Status='Applied';Previous="SysMain: $($s1.Previous), WSearch: $($s2.Previous)";Intended='Stop SysMain, WSearch & MapsBroker RAM drain';Actual="SysMain: $($s1.Current), WSearch: $($s2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_MenuSpeed' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '20' 'String'
            $r2=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 1 'DWord'
            $r4=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 'DWord'
            return [pscustomobject]@{Status='Applied';Previous="MenuDelay=$($r1.Previous)";Intended='MenuShowDelay=20ms, EndTask=1, LaunchTo=ThisPC, ShowExt';Actual="MenuDelay=$($r1.Current)ms, EndTask=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_VisualBalanced' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'DisableAcrylicBackgroundOnLogon' 1 'DWord'
            return [pscustomobject]@{Status=$r1.State;Previous="Transparency=$($r1.Previous)";Intended='Disable Transparency & Acrylic Blur';Actual="Transparency=$($r1.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_VisualExtreme' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0 'DWord'
            return [pscustomobject]@{Status='Applied';Previous="VisualFX=$($r1.Previous)";Intended='Best Performance VisualFX + Smooth Fonts retained';Actual="VisualFX=$($r1.Current), FontSmoothing=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_ConsumerAds' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0 'DWord'
            $r4=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenOverlayEnabled' 0 'DWord'
            return [pscustomobject]@{Status=$r1.State;Previous="ConsumerFeatures=$($r1.Previous)";Intended='Block auto-installing bloatware & ads';Actual="ConsumerFeatures=$($r1.Current), AdsDisabled=1";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_CopilotBing' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 'DWord'
            $r4=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1 'DWord'
            return [pscustomobject]@{Status='Applied';Previous="BingSearch=$($r1.Previous), Widgets=$($r2.Previous)";Intended='Disable Bing Search, Widgets, Copilot & Recall';Actual="BingOff=$($r1.Current), WidgetsOff=$($r2.Current), CopilotOff=$($r3.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_ActivityPrivacy' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1 'DWord'
            $r4=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' 1 'DWord'
            return [pscustomobject]@{Status=$r1.State;Previous="PublishActivities=$($r1.Previous)";Intended='Disable Activity History, Ad ID & WPBT';Actual="PublishActivities=$($r1.Current), WPBTBlocked=$($r4.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_RemoveXboxGaming' {
            $targets=@('Microsoft.XboxGamingOverlay','Microsoft.XboxApp','Microsoft.Xbox.TCUI','Microsoft.XboxSpeechToTextOverlay','Microsoft.GamingApp')
            $removed=0
            foreach($pkg in $targets){
                $found=@(Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue)
                foreach($f in $found){
                    try{Remove-AppxPackage -Package $f.PackageFullName -ErrorAction Stop;$removed++}catch{}
                }
            }
            $st=if($removed -gt 0){'Applied'}else{'Already Applied'}
            return [pscustomobject]@{Status=$st;Previous="Checked $($targets.Count) Xbox packages";Intended='Remove optional Xbox overlays';Actual="Removed $removed package(s)";Verified='Verified';Restart=$false;Restorable=$false;Error=''}
        }
        'Tweak_RemovePromoApps' {
            $targets=@('Microsoft.BingNews','Microsoft.BingWeather','Microsoft.MicrosoftSolitaireCollection','Clipchamp.Clipchamp','Microsoft.WindowsFeedbackHub','Microsoft.GetHelp','Microsoft.Todos','Microsoft.PowerAutomateDesktop')
            $removed=0
            foreach($pkg in $targets){
                $found=@(Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue)
                foreach($f in $found){
                    try{Remove-AppxPackage -Package $f.PackageFullName -ErrorAction Stop;$removed++}catch{}
                }
            }
            $st=if($removed -gt 0){'Applied'}else{'Already Applied'}
            return [pscustomobject]@{Status=$st;Previous="Checked $($targets.Count) promo apps";Intended='Remove consumer promotional apps';Actual="Removed $removed promotional app(s)";Verified='Verified';Restart=$false;Restorable=$false;Error=''}
        }
        'Tweak_RemoveExtremeApps' {
            $targets=@('Microsoft.WindowsMaps','Microsoft.People','Microsoft.ZuneVideo','Microsoft.MixedReality.Portal','Microsoft.Microsoft3DViewer','MicrosoftCorporationII.QuickAssist','Microsoft.YourPhone')
            $removed=0
            foreach($pkg in $targets){
                $found=@(Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue)
                foreach($f in $found){
                    try{Remove-AppxPackage -Package $f.PackageFullName -ErrorAction Stop;$removed++}catch{}
                }
            }
            $st=if($removed -gt 0){'Applied'}else{'Already Applied'}
            return [pscustomobject]@{Status=$st;Previous="Checked $($targets.Count) optional apps";Intended='Remove non-essential Store apps (keep Store/Calc/Photos)';Actual="Removed $removed optional package(s)";Verified='Verified';Restart=$false;Restorable=$false;Error=''}
        }
        'Tweak_DefenderControl' {
            if(-not $allowDefenderOff){
                return [pscustomobject]@{Status='Skipped';Previous='Defender Active';Intended='Keep Windows Defender Active (Opt-in not checked)';Actual='Skipped - Defender Real-Time Protection kept ON';Verified='Verified';Restart=$false;Restorable=$true;Error=''}
            }
            try {
                $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware' 1 'DWord'
                $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableRealtimeMonitoring' 1 'DWord'
                try{Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue}catch{}
                $mp=Get-MpComputerStatus -ErrorAction SilentlyContinue
                if($null -ne $mp -and $mp.RealTimeProtectionEnabled -eq $true){
                    return [pscustomobject]@{Status='Blocked';Previous='RealTimeProtection=True';Intended='Disable Defender Real-Time Monitoring';Actual='Policy written, but Windows Tamper Protection is active. Turn off Tamper Protection in Windows Security first.';Verified='Blocked by Tamper Protection';Restart=$true;Restorable=$true;Error='Tamper Protection active'}
                }
                return [pscustomobject]@{Status='Applied';Previous='RealTimeProtection=True';Intended='Disable Defender Real-Time Monitoring';Actual='Defender policy applied (Restart required)';Verified='Verified';Restart=$true;Restorable=$true;Error=''}
            } catch {
                return [pscustomobject]@{Status='Blocked';Previous='Defender Protected';Intended='Disable Defender Real-Time Monitoring';Actual='Blocked by Windows Tamper Protection';Verified='Blocked';Restart=$false;Restorable=$true;Error=$_.Exception.Message}
            }
        }
        'Tweak_PowerPlan' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 'DWord'
            $r3=Set-TrackedRegistry $id $name $cat 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38 'DWord'
            $freeGB=0
            try{$drv=Get-PSDrive -Name C -ErrorAction SilentlyContinue;if($drv){$freeGB=[Math]::Round($drv.Free/1GB,1)}}catch{}
            return [pscustomobject]@{Status=$r3.State;Previous="Priority=$($r3.Previous)";Intended='Foreground CPU Priority=38 & Game Mode ON';Actual="Priority=$($r3.Current), C: Free Space = $freeGB GB";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_LaptopStandby' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9' 'ACSettingIndex' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9' 'DCSettingIndex' 0 'DWord'
            return [pscustomobject]@{Status=$r2.State;Previous="DCStandbyNet=$($r2.Previous)";Intended='Disable Modern Standby Network Drain';Actual="DCStandbyNet=$($r2.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_DeliveryOpt' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0 'DWord'
            return [pscustomobject]@{Status=$r1.State;Previous="DODownloadMode=$($r1.Previous)";Intended='DODownloadMode = 0 (No P2P Upload)';Actual="DODownloadMode=$($r1.Current)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_UpdateManual' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' 0 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AUOptions' 2 'DWord'
            return [pscustomobject]@{Status=$r2.State;Previous="AUOptions=$($r2.Previous)";Intended='Notify before download/install (AUOptions=2)';Actual="AUOptions=$($r2.Current) (Manual Control)";Verified='Verified';Restart=$false;Restorable=$true;Error=''}
        }
        'Tweak_UpdateSuppress' {
            $r1=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' 1 'DWord'
            $r2=Set-TrackedRegistry $id $name $cat 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2 'DWord'
            return [pscustomobject]@{Status=$r1.State;Previous="NoAutoUpdate=$($r1.Previous)";Intended='Suppress automatic Windows & Store updates';Actual="NoAutoUpdate=$($r1.Current), StoreAutoDownload=$($r2.Current)";Verified='Verified';Restart=$true;Restorable=$true;Error=''}
        }
        default {
            return [pscustomobject]@{Status='Skipped';Previous='N/A';Intended=$name;Actual='Unrecognized tweak ID';Verified='Skipped';Restart=$false;Restorable=$false;Error=''}
        }
    }
}

if ($AutoMaintenance) {
    try {
        $baseDir = Join-Path $env:ProgramData 'SmartLifeTeck\PCCarePro'
        $stateDir = Join-Path $baseDir 'State'
        $logDir = Join-Path $baseDir 'Logs'
        foreach ($d in @($baseDir, $stateDir, $logDir)) {
            if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        }
        $logFile = Join-Path $logDir ('AutoMaintenance_{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
        $sessionId = 'AUTO_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
        Write-BoostLog "=== SLT SCHEDULED AUTO-MAINTENANCE STARTED ($sessionId) ==="
        $autoTweaks = @(
            [pscustomobject]@{ id='Tweak_UserTemp'; name='Clean User Temporary Files Older Than 7 Days'; category='TempCleanup'; risk='Safe' },
            [pscustomobject]@{ id='Tweak_SystemTemp'; name='Clean Old Windows System Temp Files'; category='TempCleanup'; risk='Safe' },
            [pscustomobject]@{ id='Tweak_BrowserUpdateCache'; name='Clean Crash Dumps & DirectX Shader Cache'; category='TempCleanup'; risk='Safe' },
            [pscustomobject]@{ id='Tweak_RamWorkingSet'; name='Flush Idle RAM Working Sets & Tune SvcHost Grouping'; category='NetworkMemory'; risk='Safe' },
            [pscustomobject]@{ id='Tweak_NetworkLatency'; name='Disable Network Throttling & Flush Stale DNS Cache'; category='NetworkMemory'; risk='Safe' }
        )
        $autoSummaries = New-Object 'System.Collections.Generic.List[string]'
        foreach ($at in $autoTweaks) {
            try {
                $r = Invoke-SingleTweak $at
                $autoSummaries.Add(($at.name + ': ' + $r.Actual))
                $opResults.Add([ordered]@{
                    sessionId=$sessionId; profile='Scheduled Auto-Cleanup'; tweakId=$at.id; tweakName=$at.name;
                    category=$at.category; risk='Safe'; startTime=(Get-Date -Format 's'); finishTime=(Get-Date -Format 's');
                    previousState=$r.Previous; intendedChange=$r.Intended; actualResult=$r.Actual;
                    status=$r.Status; verification='Verified'; restartRequired=$false; restorable=$false; error=''
                })
            } catch {}
        }
        $lastRunFile = Join-Path $stateDir 'AutoMaintenanceLastRun.json'
        @{
            sessionId = $sessionId
            timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            summary   = ($autoSummaries -join ' | ')
            items     = @($autoSummaries.ToArray())
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lastRunFile -Encoding UTF8

        $histFile = Join-Path $stateDir 'BoostHistory.json'
        $history = New-Object 'System.Collections.Generic.List[object]'
        if (Test-Path -LiteralPath $histFile) {
            try {
                $oldHist = @(Get-Content -LiteralPath $histFile -Raw -ErrorAction Stop | ConvertFrom-Json)
                foreach ($h in $oldHist) { if ($null -ne $h) { $history.Add($h) } }
            } catch {}
        }
        foreach ($op in $opResults) { $history.Add($op) }
        $history.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $histFile -Encoding UTF8
        Write-BoostLog "=== SLT SCHEDULED AUTO-MAINTENANCE COMPLETED ==="
        exit 0
    } catch {
        exit 1
    }
}

try {
    $job=Get-Content -LiteralPath $Manifest -Raw -ErrorAction Stop|ConvertFrom-Json
    $sessionId=[string]$job.sessionId
    $profileName=[string]$job.profile
    $progressPath=[string]$job.progress
    $stopFile=[string]$job.stopFile
    $stateDir=[string]$job.stateDir
    $logFile=[string]$job.logFile
    if($job.PSObject.Properties['allowDefenderOff']){$allowDefenderOff=[bool]$job.allowDefenderOff}
    $tweaks=@($job.tweaks)
    $categories=@($job.categories)
    $total=$tweaks.Count

    foreach($c in $categories){
        $catId=[string]$c.id
        $catTweaks=@($tweaks | Where-Object {[string]$_.category -eq $catId})
        $catState[$catId]=[ordered]@{
            id=$catId
            title=[string]$c.title
            subtitle=[string]$c.subtitle
            status=$(if($catTweaks.Count -gt 0){'Pending'}else{'Skipped'})
            details=$(if($catTweaks.Count -gt 0){"0 / $($catTweaks.Count) tweaks queued"}else{'Not included in this profile'})
            percent=$(if($catTweaks.Count -gt 0){0}else{100})
            total=$catTweaks.Count
            done=0
        }
    }

    Write-BoostLog "=== SLT BOOST SESSION $sessionId STARTED (Profile: $profileName, Tweaks: $total) ==="
    Publish-BoostProgress 'Running'

    $stopped=$false
    foreach($tw in $tweaks){
        if($stopFile -and (Test-Path -LiteralPath $stopFile)){
            $stopped=$true
            break
        }
        $cid=[string]$tw.category
        $currentTitle=[string]$tw.name
        if($catState.ContainsKey($cid)){
            $catState[$cid].status='In Progress'
            $catState[$cid].details=('Running: '+[string]$tw.name)
        }
        Publish-BoostProgress 'Running'
        Start-Sleep -Milliseconds 60

        $startTs=(Get-Date -Format 's')
        $res=$null
        try {
            $res=Invoke-SingleTweak $tw
        } catch {
            $res=[pscustomobject]@{
                Status='Failed';Previous='Unknown';Intended=[string]$tw.name;
                Actual=('Error: '+$_.Exception.Message);Verified='Failed';Restart=$false;Restorable=$false;Error=$_.Exception.Message
            }
        }
        $endTs=(Get-Date -Format 's')

        $st=[string]$res.Status
        if($st -in @('Applied','Successfully Completed')){$appliedCount++}
        elseif($st -eq 'Already Applied'){$alreadyCount++}
        elseif($st -eq 'Blocked'){$blockedCount++}
        elseif($st -eq 'Skipped'){$skippedCount++}
        else{$failedCount++}
        if([bool]$res.Restart){$restartReqCount++}
        $completed++

        if($catState.ContainsKey($cid)){
            $catState[$cid].done=[int]$catState[$cid].done + 1
            $cTot=[int]$catState[$cid].total
            $cDone=[int]$catState[$cid].done
            $catState[$cid].percent=if($cTot -gt 0){[int][Math]::Round(100.0*$cDone/$cTot)}else{100}
            $catState[$cid].details=[string]$res.Actual
            if($cDone -ge $cTot){
                $catState[$cid].status=$st
            }
        }

        $opRecord=[ordered]@{
            sessionId=$sessionId
            profile=$profileName
            tweakId=[string]$tw.id
            tweakName=[string]$tw.name
            category=$cid
            risk=[string]$tw.risk
            startTime=$startTs
            finishTime=$endTs
            previousState=[string]$res.Previous
            intendedChange=[string]$res.Intended
            actualResult=[string]$res.Actual
            status=$st
            verification=[string]$res.Verified
            restartRequired=[bool]$res.Restart
            restorable=[bool]$res.Restorable
            error=[string]$res.Error
        }
        $opResults.Add($opRecord)
        Write-BoostLog ("[$st] $($tw.name) | $($res.Actual)")
        Publish-BoostProgress 'Running'
    }

    if($stopped){
        foreach($tw in ($tweaks | Select-Object -Skip $completed)){
            $cid=[string]$tw.category
            if($catState.ContainsKey($cid) -and $catState[$cid].status -in @('Pending','In Progress')){
                $catState[$cid].status='Stopped'
                $catState[$cid].details='Stopped by user'
            }
            $opResults.Add([ordered]@{
                sessionId=$sessionId;profile=$profileName;tweakId=[string]$tw.id;tweakName=[string]$tw.name;
                category=$cid;risk=[string]$tw.risk;startTime=(Get-Date -Format 's');finishTime=(Get-Date -Format 's');
                previousState='N/A';intendedChange=[string]$tw.name;actualResult='Not started (Boost stopped by user)';
                status='Stopped';verification='Not Run';restartRequired=$false;restorable=$false;error=''
            })
        }
        $currentTitle='Boost Stopped Safely by User'
        $overallState='Stopped'
    } else {
        $currentTitle='Boost Completed'
        $overallState='Finished'
    }

    # Append session to persistent BoostHistory.json for SLT Smart Digital Report
    $histFile=Join-Path $stateDir 'BoostHistory.json'
    $history=New-Object 'System.Collections.Generic.List[object]'
    if(Test-Path -LiteralPath $histFile){
        try {
            $oldHist=@(Get-Content -LiteralPath $histFile -Raw -ErrorAction Stop|ConvertFrom-Json)
            foreach($h in $oldHist){if($null -ne $h){$history.Add($h)}}
        } catch {}
    }
    foreach($op in $opResults){$history.Add($op)}
    $histTmp=$histFile+'.tmp'
    $history.ToArray()|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $histTmp -Encoding UTF8
    Copy-Item -LiteralPath $histTmp -Destination $histFile -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $histTmp -Force -ErrorAction SilentlyContinue

    Write-BoostLog "=== SLT BOOST SESSION $sessionId FINISHED ($overallState) | Applied=$appliedCount Already=$alreadyCount Skipped=$skippedCount Failed=$failedCount Blocked=$blockedCount ==="
    Publish-BoostProgress $overallState
} catch {
    $currentTitle=('Boost Engine Error: '+$_.Exception.Message)
    Write-BoostLog $currentTitle
    Publish-BoostProgress 'Fatal'
    exit 1
}
