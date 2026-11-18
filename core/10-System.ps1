function Log-SLT([string]$Text) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} | {1}' -f (Get-Date),$Text
    try {Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8} catch {}
    if($script:LogBox) {try {$script:LogBox.AppendText($line+"`r`n");$script:LogBox.ScrollToEnd()} catch {}}
}
if ($script:StateAclProtected -eq $true) { Log-SLT 'ProgramData base, logs, and state folders ACL-restricted to SYSTEM, Administrators, and current operator.' }
else { Log-SLT 'WARNING: ProgramData folder ACL hardening could not be verified; review local access permissions before storing Unattend files.' }
function Get-SLTHardware {
    # SCAN FIX: use shared WMI cache when available; never throw for one failed WMI query.
    $sys=$null;$bios=$null;$os=$null
    if (Get-Command Get-SLTCachedWmiClass -ErrorAction SilentlyContinue) {
        try { $sys=@(Get-SLTCachedWmiClass 'Win32_ComputerSystem')[0] } catch {}
        try { $bios=@(Get-SLTCachedWmiClass 'Win32_BIOS')[0] } catch {}
        try { $os=@(Get-SLTCachedWmiClass 'Win32_OperatingSystem')[0] } catch {}
    } else {
        try { $sys=Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue } catch {}
        try { $bios=Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue } catch {}
        try { $os=Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
    }
    [pscustomobject]@{Maker=if($sys -and $sys.Manufacturer){[string]$sys.Manufacturer}else{'Not reported'};Model=if($sys -and $sys.Model){[string]$sys.Model}else{'Not reported'};Serial=if($bios -and $bios.SerialNumber){[string]$bios.SerialNumber}else{'Not reported'};
      RAM=if($sys -and $sys.TotalPhysicalMemory){([math]::Round($sys.TotalPhysicalMemory/1GB,1))}else{$null};OS=if($os -and $os.Caption){[string]$os.Caption}else{'Not reported'};Build=if($os -and $os.BuildNumber){[string]$os.BuildNumber}else{'Not reported'}}
}
function Get-SLTBadDrivers {
    # Device Manager errors report karta hai; signed drivers ko randomly update nahi karta.
    try {@(Get-PnpDevice -PresentOnly | Where-Object {$_.Status -ne 'OK'} | Select-Object Class,FriendlyName,Status,ConfigManagerErrorCode)}
    catch {Log-SLT ('PnP scan unavailable: '+$_.Exception.Message);@()}
}
function Get-SLTOEMURL([string]$Maker) {
    switch -Regex ($Maker) {
      'Dell|Alienware' {return 'https://www.dell.com/support/home'}
      'HP|Hewlett' {return 'https://support.hp.com/drivers'}
      'Lenovo' {return 'https://pcsupport.lenovo.com/'}
      'ASUS|ASUSTeK' {return 'https://www.asus.com/support/download-center/'}
      'Acer' {return 'https://www.acer.com/us-en/support/drivers-and-manuals'}
      'MSI|Micro-Star' {return 'https://www.msi.com/support/download'}
      'Samsung' {return 'https://www.samsung.com/us/support/downloads/'}
      'Huawei' {return 'https://consumer.huawei.com/en/support/laptops/'}
      'Dynabook|Toshiba' {return 'https://support.dynabook.com/'}
      'Microsoft' {return 'https://support.microsoft.com/surface'}
      'LG' {return 'https://www.lg.com/us/support/software-firmware-drivers'}
      'Razer' {return 'https://mysupport.razer.com/'}
      'Gigabyte' {return 'https://www.gigabyte.com/Support/Laptop'}
      default {return 'https://support.microsoft.com/windows'}
    }
}
function Test-SLTAdmin {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Need-SLTAdmin {if(-not(Test-SLTAdmin)){throw 'Run this tool as Administrator for system-changing actions.'}}
function Open-SLTLink([string]$Url) {Start-Process -FilePath $Url}
function Save-SLTSetting([string]$Key,[string]$Name) {
    # Har badli hui Registry value ka original backup karta hai.
    $path=Join-Path $script:StateDir 'Registry.json'
    $obj=@{}
    if(Test-Path $path) {try { $old=Get-Content $path -Raw|ConvertFrom-Json;foreach($p in $old.PSObject.Properties){$obj[$p.Name]=$p.Value} }catch{throw 'Registry backup unreadable. No setting changed.'}}
    $id="$Key|$Name"
    if(-not $obj.ContainsKey($id)) {
       $entry=Get-ItemProperty -Path $Key -Name $Name -ErrorAction SilentlyContinue
       $found=($null -ne $entry)
       $value=if($found){$entry.$Name}else{$null}
       $valueType = 'DWord'
       if ($found) {
           try { $regKey = Get-Item -LiteralPath $Key -ErrorAction Stop; $valueType = [string]$regKey.GetValueKind($Name) } catch {
               $valueType = if ($value -is [string]) { 'String' } elseif ($value -is [long] -or $value -is [uint64]) { 'QWord' } elseif ($value -is [byte[]]) { 'Binary' } else { 'DWord' }
           }
       }
       $obj[$id]=[pscustomobject]@{Path=$Key;Name=$Name;Exists=$found;Value=$value;Type=$valueType}
       $obj|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding UTF8
    }
}
function Set-SLTSetting([string]$Key,[string]$Name,[int]$Value) {
    Need-SLTAdmin
    Save-SLTSetting $Key $Name
    if(-not(Test-Path $Key)){New-Item -Path $Key -Force|Out-Null}
    New-ItemProperty -Path $Key -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
    Log-SLT "Policy saved: $Name = $Value"
}
function Set-SLTStringSetting([string]$Key,[string]$Name,[string]$Value) {
    Need-SLTAdmin
    Save-SLTSetting $Key $Name
    if(-not(Test-Path $Key)){New-Item -Path $Key -Force|Out-Null}
    New-ItemProperty -Path $Key -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    Log-SLT "String setting saved with rollback: $Name"
}
function Remove-SLTTrackedRegistryValue([string]$Key,[string]$Name) {
    Need-SLTAdmin
    Save-SLTSetting $Key $Name
    Remove-ItemProperty -Path $Key -Name $Name -ErrorAction SilentlyContinue
    Log-SLT "Registry startup value disabled with rollback: $Name"
}
function Restore-SLTSettings {
    Need-SLTAdmin
    $file=Join-Path $script:StateDir 'Registry.json'
    if(-not(Test-Path -LiteralPath $file)){Log-SLT 'No saved policy backup found.';return}
    $data=Get-Content -LiteralPath $file -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
    $remaining=@{};$restored=0
    foreach($p in $data.PSObject.Properties){
      $e=$p.Value
      try {
        if($e.Exists){
            if(-not(Test-Path -LiteralPath $e.Path)){New-Item -Path $e.Path -Force -ErrorAction Stop|Out-Null}
            $valueType = if ($e.PSObject.Properties['Type'] -and $e.Type) { [string]$e.Type } else { 'DWord' }
            $restoreValue = $e.Value
            if ($valueType -eq 'Binary' -and $restoreValue -is [array]) { $restoreValue = [byte[]]@($restoreValue | ForEach-Object { [byte]$_ }) }
            elseif ($valueType -eq 'MultiString' -and $restoreValue -is [array]) { $restoreValue = [string[]]@($restoreValue | ForEach-Object { [string]$_ }) }
            elseif ($valueType -eq 'DWord') { $restoreValue = [int]$restoreValue }
            elseif ($valueType -eq 'QWord') { $restoreValue = [long]$restoreValue }
            New-ItemProperty -Path $e.Path -Name $e.Name -Value $restoreValue -PropertyType $valueType -Force -ErrorAction Stop|Out-Null
        } else { Remove-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue }
        $restored++
        Log-SLT "Restored policy: $($e.Name)"
      } catch {
        $remaining[$p.Name]=$e
        Log-SLT "Restore failed and backup retained: $($e.Name) - $($_.Exception.Message)"
      }
    }
    if ($remaining.Count -gt 0) {
        $remaining | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $file -Encoding UTF8
        Log-SLT ("Restored $restored setting(s); retained $($remaining.Count) failed backup(s) for retry.")
    } else {
        Move-Item -LiteralPath $file -Destination ($file+'.'+(Get-Date -Format yyyyMMdd_HHmmss)+'.restored') -Force
        Log-SLT ("Restored $restored original registry setting(s). Backup archived.")
    }
}
function Restore-SLTUpdatePolicies {
    # Sirf Windows Update keys restore karta hai; Tweaks aur Store guard ko nahi.
    Need-SLTAdmin
    $file=Join-Path $script:StateDir 'Registry.json'
    if(-not(Test-Path -LiteralPath $file)){Log-SLT 'No saved update policies found.';return}
    $backup=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
    $remaining=@{};$changed=0
    foreach($item in $backup.PSObject.Properties) {
       $entry=$item.Value
       if(([string]$entry.Path) -like 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU*') {
          try {
             if($entry.Exists){if(-not(Test-Path $entry.Path)){New-Item -Path $entry.Path -Force|Out-Null};New-ItemProperty -Path $entry.Path -Name $entry.Name -Value ([int]$entry.Value) -PropertyType DWord -Force|Out-Null}
             else {Remove-ItemProperty -Path $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue}
             $changed++
          } catch {Log-SLT ('Restore update setting failed: '+$_.Exception.Message);$remaining[$item.Name]=$entry}
       } else {$remaining[$item.Name]=$entry}
    }
    $remaining|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $file -Encoding UTF8
    Log-SLT "Restored $changed original Windows Update policy settings. Other SLT settings preserved."
}
function Invoke-SLTCleanup {
    # Sirf 7 din se purani TEMP files remove karta hai; locked files skip hoti hain.
    Need-SLTAdmin
    $count=0;$bytes=[long]0
    $dirs=@($env:TEMP, "$env:WINDIR\Temp") | Select-Object -Unique
    foreach($dir in $dirs) {
      if(-not(Test-Path -LiteralPath $dir)){continue}
      Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | ForEach-Object {
        try{$size=$_.Length;Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop;$count++;$bytes+=$size}catch{}
      }
    }
    Log-SLT ('Cleaned {0} old temp files; {1:N1} MB freed. No personal folders touched.' -f $count,($bytes/1MB))
}
function Set-SLTOptimize([ValidateSet('Safe','Balanced','Ultra','Audit')][string]$Mode) {
    Need-SLTAdmin
    Invoke-SLTCleanup
    if($Mode -in @('Balanced','Ultra','Audit')) {
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
       Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    }
    if($Mode -eq 'Ultra'){Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2}
    if($Mode -eq 'Audit') {
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
       # Sirf nonessential consumer promotions aur activity upload ko roke; Windows services safe rahein.
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
       Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
       Log-SLT 'Audit privacy: no activity upload, reduced advertising/personalization; location, security and app frameworks preserved.'
    }
    Log-SLT "$Mode optimization complete. Defender, Appx, updates and core services untouched."
}
function Set-SLTUpdateChoice([ValidateSet('Notify','Default','StoreGuard','StoreRestore')][string]$Mode) {
    Need-SLTAdmin
    $au='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    $store='HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
    switch($Mode) {
     'Notify' {Set-SLTSetting $au 'NoAutoUpdate' 0;Set-SLTSetting $au 'AUOptions' 2;Log-SLT 'Windows Update notify-before-download (Pro, best effort).'}
     'Default' {Restore-SLTUpdatePolicies;Log-SLT 'Original SLT Windows Update policy restored.'}
     'StoreGuard' {Set-SLTSetting $store 'AutoDownload' 2;Log-SLT 'Temporary Store auto-update block for Audit Mode ONLY.'}
     'StoreRestore' {Save-SLTSetting $store 'AutoDownload';Remove-ItemProperty -Path $store -Name 'AutoDownload' -ErrorAction SilentlyContinue;Log-SLT 'Store restriction removed; normal customer app updates allowed.'}
    }
}
function Test-SLTImagePreflight {
    # Read-only system scan; Sysprep pass guarantee nahi.
    $pc=Get-SLTHardware
    $issues=@(Get-SLTBadDrivers)
    $pending=@(@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') | Where-Object { Test-Path $_ })
    $sval=Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -ErrorAction SilentlyContinue
    $store=if($sval){$sval.AutoDownload}else{$null}
    $maskedSerial = if ($pc.Serial -and $pc.Serial -ne 'Not reported' -and $pc.Serial -ne 'N/A') { $serialText=[string]$pc.Serial; if ($serialText.Length -gt 4) { '****' + $serialText.Substring($serialText.Length - 4) } else { '****' } } else { 'Not reported' }
    $pcSafe = [pscustomobject]@{Maker=$pc.Maker;Model=$pc.Model;Serial=$maskedSerial;RAM=$pc.RAM;OS=$pc.OS;Build=$pc.Build}
    $out=[ordered]@{Timestamp=(Get-Date).ToString('s');Computer=$pcSafe;PNPIssues=$issues;PendingRestart=($pending.Count -gt 0);StoreAutoDownload=$store;AuditModeMustBeConfirmedByTechnician=$true;WindowsSIMValidationRequired=$true;LicensedOfficeMustBeChecked=$true;OfflineCaptureAfterShutdown=$true}
    $file=Join-Path $script:LogDir ('Preflight_{0}.json' -f (Get-Date -Format yyyyMMdd_HHmmss))
    $out|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $file -Encoding UTF8
    Log-SLT "Preflight: driver issues $($issues.Count), pending restart $($pending.Count); report $file"
    return $file
}
function New-SLTUnattend([ValidateSet('Generic','Model')][string]$Type,[string]$Username,[string]$DisplayName,[string]$Password,[bool]$AutoLogon) {
    # Generic alag hardware ke liye; Model mode same hardware per tested drivers retain karta hai.
    Need-SLTAdmin
    if($Username -notmatch '^[A-Za-z][A-Za-z0-9._-]{1,19}$'){throw 'Username: 2-20 Latin letters/digits; must start with letter.'}
    if([string]::IsNullOrWhiteSpace($Password) -or $Password.Length -lt 12){throw 'A unique temporary password of at least 12 characters is required.'}
    if([string]::IsNullOrWhiteSpace($DisplayName)){throw 'Display name is required.'}
    $u=[Security.SecurityElement]::Escape($Username);$d=[Security.SecurityElement]::Escape($DisplayName);$pw=[Security.SecurityElement]::Escape($Password)
    $persist=if($Type -eq 'Model'){'true'}else{'false'}
    $auto=''
    if($AutoLogon){$auto="<AutoLogon><Username>$u</Username><Password><Value>$pw</Value><PlainText>true</PlainText></Password><Enabled>true</Enabled><LogonCount>1</LogonCount></AutoLogon>"}
    $genPass = if ($Type -eq 'Model') {
        '<settings pass="generalize"><component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><PersistAllDeviceInstalls>true</PersistAllDeviceInstalls></component></settings>'
    } else { '' }
    $xml=@"
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by SLT Smart PC Boost. Contains a temporary local-account password; protect and delete after deployment. -->
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
 $genPass
 <settings pass="specialize"><component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><ComputerName>*</ComputerName></component></settings>
 <settings pass="oobeSystem">
  <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
   <OOBE><HideEULAPage>true</HideEULAPage><HideOEMRegistrationScreen>true</HideOEMRegistrationScreen><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>3</ProtectYourPC></OOBE>
   <UserAccounts><LocalAccounts><LocalAccount wcm:action="add"><Name>$u</Name><DisplayName>$d</DisplayName><Group>Administrators</Group><Password><Value>$pw</Value><PlainText>true</PlainText></Password></LocalAccount></LocalAccounts></UserAccounts>
   $auto
  </component>
  <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><InputLocale>en-US</InputLocale><SystemLocale>en-US</SystemLocale><UILanguage>en-US</UILanguage><UserLocale>en-US</UserLocale></component>
 </settings>
</unattend>
"@
    $null=[xml]$xml
    $out=Join-Path $script:StateDir ('Unattend_{0}.xml' -f $Type)
    [IO.File]::WriteAllText($out,$xml,(New-Object Text.UTF8Encoding $false))
    # Unattend.xml contains a readable temporary password. Restrict access to SYSTEM,
    # local Administrators, and the current operator; remove the file if ACL hardening fails.
    try {
        $acl = Get-Acl -LiteralPath $out -ErrorAction Stop
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($existingRule in @($acl.Access)) { $acl.RemoveAccessRuleAll($existingRule) }
        $accounts = @('SYSTEM', 'BUILTIN\Administrators', [Security.Principal.WindowsIdentity]::GetCurrent().Name)
        foreach ($account in ($accounts | Select-Object -Unique)) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($account, 'FullControl', 'Allow')
            [void]$acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $out -AclObject $acl -ErrorAction Stop
    } catch {
        Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
        throw ('Could not secure Unattend.xml permissions: ' + $_.Exception.Message)
    }
    Log-SLT "Generated protected $Type Unattend: $out. WARNING: the temporary password is still readable to authorized local administrators; delete the answer file after deployment."
    return $out
}
function Show-SLTInstallReport([object]$Data,[string]$LogFile){
    $items=@($Data.results)
    $chkSym = [char]0x2713
    $infoSym = [char]0x2139
    $crossSym = [char]0x2717

    $installedList = New-Object System.Collections.Generic.List[string]
    $alreadyList   = New-Object System.Collections.Generic.List[string]
    $failedList    = New-Object System.Collections.Generic.List[string]

    foreach($x in $items){
        $st = ([string]$x.status).ToUpperInvariant()
        $nm = [string]$x.name
        $wid = if($x.PSObject.Properties['winget'] -and $x.winget){' ('+[string]$x.winget+')'}else{''}
        $nt = if($x.PSObject.Properties['note'] -and $x.note){'  -  '+[string]$x.note}else{''}
        if($st -eq 'INSTALLED'){
            $installedList.Add("  $chkSym  $nm$wid$nt")
        } elseif($st -eq 'ALREADY INSTALLED'){
            $alreadyList.Add("  $infoSym  $nm$wid$nt")
        } else {
            $failedList.Add("  $crossSym  $nm$wid$nt")
        }
    }

    $summaryLines = New-Object System.Collections.Generic.List[string]
    $summaryLines.Add("=== [$chkSym] INSTALLED ($($installedList.Count)) ===")
    if($installedList.Count -gt 0){ foreach($l in $installedList){ $summaryLines.Add($l) } } else { $summaryLines.Add("  (None)") }
    $summaryLines.Add("")
    $summaryLines.Add("=== [$infoSym] ALREADY INSTALLED ($($alreadyList.Count)) ===")
    if($alreadyList.Count -gt 0){ foreach($l in $alreadyList){ $summaryLines.Add($l) } } else { $summaryLines.Add("  (None)") }
    $summaryLines.Add("")
    $summaryLines.Add("=== [$crossSym] NOT INSTALLED ($($failedList.Count)) ===")
    if($failedList.Count -gt 0){ foreach($l in $failedList){ $summaryLines.Add($l) } } else { $summaryLines.Add("  (None)") }

    $dialog=New-Object Windows.Window
    $dialog.Title='Smart Installation Summary'
    $dialog.Width=740;$dialog.Height=560
    $dialog.WindowStartupLocation='CenterOwner';$dialog.Owner=$script:Window
    Apply-SLTDialogTheme $dialog

    $outer=New-Object Windows.Controls.Grid;$outer.Margin=[Windows.Thickness]::new(22,18,22,16)
    $r0=New-Object Windows.Controls.RowDefinition;$r0.Height=[Windows.GridLength]::Auto
    $r1=New-Object Windows.Controls.RowDefinition;$r1.Height=[Windows.GridLength]::Auto
    $r2=New-Object Windows.Controls.RowDefinition;$r2.Height=New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $r3=New-Object Windows.Controls.RowDefinition;$r3.Height=[Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)|Out-Null;$outer.RowDefinitions.Add($r1)|Out-Null;$outer.RowDefinitions.Add($r2)|Out-Null;$outer.RowDefinitions.Add($r3)|Out-Null

    # Row 0: Title
    $hdrStack=New-Object Windows.Controls.StackPanel;$hdrStack.Margin=[Windows.Thickness]::new(0,0,0,12)
    $hTitle=New-Object Windows.Controls.TextBlock
    $hTitle.Text=if([int]$Data.failures -eq 0 -and [int]$Data.installed -eq 0 -and [int]$Data.already -gt 0){'Smart Installation Summary - All Selected Tools Already Installed'}elseif([int]$Data.failures -eq 0){'Smart Installation Summary - Completed Successfully'}else{'Smart Installation Summary - Batch Finished'}
    $hTitle.FontSize=18;$hTitle.FontWeight='Bold'
    $hTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextAccent')
    $hSub=New-Object Windows.Controls.TextBlock
    $hSub.Text='Review the categorized installation results below (Installed, Already Installed, Not Installed).'
    $hSub.FontSize=11.5;$hSub.Margin=[Windows.Thickness]::new(0,3,0,0)
    $hSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    $hdrStack.Children.Add($hTitle)|Out-Null;$hdrStack.Children.Add($hSub)|Out-Null
    $hdrStack.SetValue([Windows.Controls.Grid]::RowProperty,0)
    $outer.Children.Add($hdrStack)|Out-Null

    # Row 1: 3 Scoreboard Badges (Installed, Already Installed, Not Installed)
    $badgeGrid=New-Object Windows.Controls.Primitives.UniformGrid;$badgeGrid.Columns=3;$badgeGrid.Margin=[Windows.Thickness]::new(0,0,0,12)
    $bSpecs=@(
        @{ Label="$chkSym Installed"; Count=$installedList.Count; Res='SLTStatusOk' },
        @{ Label="$infoSym Already Installed"; Count=$alreadyList.Count; Res='TextAccent' },
        @{ Label="$crossSym Not Installed"; Count=$failedList.Count; Res='SLTStatusError' }
    )
    foreach($bs in $bSpecs){
        $bCard=New-Object Windows.Controls.Border
        $bCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'CardSurface')
        $bCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'CardBorder')
        $bCard.BorderThickness=[Windows.Thickness]::new(1);$bCard.CornerRadius=[Windows.CornerRadius]::new(10)
        $bCard.Padding=[Windows.Thickness]::new(14,8,14,8);$bCard.Margin=[Windows.Thickness]::new(4,0,4,0)
        $bSp=New-Object Windows.Controls.StackPanel
        $bT1=New-Object Windows.Controls.TextBlock;$bT1.Text=$bs.Label;$bT1.FontSize=11;$bT1.FontWeight='Bold'
        $bT1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,$bs.Res)
        $bT2=New-Object Windows.Controls.TextBlock;$bT2.Text=([string]$bs.Count + ' tool(s)');$bT2.FontSize=16;$bT2.FontWeight='Bold';$bT2.Margin=[Windows.Thickness]::new(0,2,0,0)
        $bT2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextPrimary')
        $bSp.Children.Add($bT1)|Out-Null;$bSp.Children.Add($bT2)|Out-Null
        $bCard.Child=$bSp
        $badgeGrid.Children.Add($bCard)|Out-Null
    }
    $badgeGrid.SetValue([Windows.Controls.Grid]::RowProperty,1)
    $outer.Children.Add($badgeGrid)|Out-Null

    # Row 2: Detailed Categorized List Box
    $txt=New-Object Windows.Controls.TextBox
    $txt.Text=($summaryLines -join [Environment]::NewLine)
    $txt.IsReadOnly=$true;$txt.TextWrapping='Wrap';$txt.VerticalScrollBarVisibility='Auto'
    $txt.FontFamily='Consolas';$txt.FontSize=12
    $txt.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardSurface')
    $txt.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty,'CardBorder')
    $txt.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary')
    $txt.Padding=[Windows.Thickness]::new(12)
    $txt.SetValue([Windows.Controls.Grid]::RowProperty,2)
    $outer.Children.Add($txt)|Out-Null

    # Row 3: Small Branding Footer + Buttons
    $footGrid=New-Object Windows.Controls.Grid;$footGrid.Margin=[Windows.Thickness]::new(0,12,0,0)
    $fc0=New-Object Windows.Controls.ColumnDefinition;$fc0.Width=New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $fc1=New-Object Windows.Controls.ColumnDefinition;$fc1.Width=[Windows.GridLength]::Auto
    $footGrid.ColumnDefinitions.Add($fc0)|Out-Null;$footGrid.ColumnDefinitions.Add($fc1)|Out-Null
    $brandTb=New-Object Windows.Controls.TextBlock
    $brandTb.Text="Powered by SmartLifeTeck $([char]0x00B7) Developed by Shahzad"
    $brandTb.FontSize=11;$brandTb.VerticalAlignment='Center'
    $brandTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    $footGrid.Children.Add($brandTb)|Out-Null

    $btnRow=New-Object Windows.Controls.StackPanel;$btnRow.Orientation='Horizontal'
    $certBtn=New-Object Windows.Controls.Button;$certBtn.Content='Customer Software Certificate';$certBtn.Style=$script:Window.FindResource('OutlineButton')
    $certBtn.Margin=[Windows.Thickness]::new(0,0,6,0)
    $certBtn.Add_Click({
        try {
            $certPath = Join-Path $script:LogDir ('SLT_Software_Certificate_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.html')
            $rowsHtml = ($items | ForEach-Object { "<tr><td style='padding:8px;border-bottom:1px solid #e2e8f0;font-weight:600;'>$($_.name)</td><td style='padding:8px;border-bottom:1px solid #e2e8f0;color:#0f766e;font-weight:700;'>$($_.status)</td><td style='padding:8px;border-bottom:1px solid #e2e8f0;color:#64748b;font-size:12px;'>$($_.note)</td></tr>" }) -join ""
            $html = "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Smart Life Teck - Software Setup Certificate</title></head><body style='font-family:Segoe UI,sans-serif;background:#f8faf8;padding:30px;color:#0f172a;'><div style='max-width:780px;margin:0 auto;background:#fff;border:2px solid #0f766e;border-radius:18px;padding:28px;'><h1 style='margin:0;color:#0f5c5c;font-size:24px;'>SMART LIFE TECK - OFFICIAL SOFTWARE SETUP CERTIFICATE</h1><p style='color:#475569;font-size:13px;margin-top:6px;'>Zero Bloat Promise - 100% Official Verified Publishers | Smart Your Digital Life - By Shahzad Babar</p><hr style='border:0;border-top:1px solid #e2e8f0;margin:16px 0;'><table style='width:100%;border-collapse:collapse;font-size:13px;'><thead><tr style='background:#f0fdfa;text-align:left;'><th style='padding:8px;'>Software Name</th><th style='padding:8px;'>Status</th><th style='padding:8px;'>Verification Note</th></tr></thead><tbody>$rowsHtml</tbody></table><p style='margin-top:20px;font-size:12px;color:#64748b;text-align:center;'>www.smartlifeteck.com | info@smartlifeteck.com | WhatsApp +966 553760854 | Powered by Smart Life Teck</p></div></body></html>"
            [IO.File]::WriteAllText($certPath, $html, [Text.Encoding]::UTF8)
            Start-Process -FilePath $certPath
        } catch {}
    }.GetNewClosure())
    $btnRow.Children.Add($certBtn)|Out-Null
    $open=New-Object Windows.Controls.Button;$open.Content='Open Logs';$open.Style=$script:Window.FindResource('OutlineButton')
    $open.Add_Click({Start-Process -FilePath (Split-Path -Parent $LogFile)}.GetNewClosure())
    $close=New-Object Windows.Controls.Button;$close.Content='Close';$close.Style=$script:Window.FindResource('ActionButton')
    $close.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'BtnSelectedBg')
    $close.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'BtnSelectedText')
    $close.Add_Click({$dialog.Close()}.GetNewClosure())
    $btnRow.Children.Add($open)|Out-Null;$btnRow.Children.Add($close)|Out-Null
    $btnRow.SetValue([Windows.Controls.Grid]::ColumnProperty,1)
    $footGrid.Children.Add($btnRow)|Out-Null
    $footGrid.SetValue([Windows.Controls.Grid]::RowProperty,3)
    $outer.Children.Add($footGrid)|Out-Null

    $dialog.Content=$outer;$dialog.ShowDialog()|Out-Null
}

function Play-SLTSuccessChime {
    # Fix #7: Guaranteed audible 4-note ascending chime (523Hz -> 659Hz -> 784Hz -> 1046Hz)
    # Uses SystemSounds + Async Background Runspace with WAV SoundPlayer.PlaySync() + [Console]::Beep
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
    try {
        $psAudio = [PowerShell]::Create()
        [void]$psAudio.AddScript({
            try {
                [Console]::Beep(523, 110)
                [Console]::Beep(659, 110)
                [Console]::Beep(784, 110)
                [Console]::Beep(1046, 240)
            } catch {}
            try {
                $sampleRate = 22050
                $notes = @(
                    @{ Freq = 523.25; DurMs = 115 },
                    @{ Freq = 659.25; DurMs = 115 },
                    @{ Freq = 783.99; DurMs = 115 },
                    @{ Freq = 1046.50; DurMs = 300 }
                )
                $totalSamples = 0
                foreach ($n in $notes) { $totalSamples += [int]($sampleRate * ($n.DurMs / 1000.0)) }
                $dataBytes = $totalSamples * 2
                $ms = New-Object System.IO.MemoryStream
                $bw = New-Object System.IO.BinaryWriter($ms)
                $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
                $bw.Write([int](36 + $dataBytes))
                $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
                $bw.Write([int]16); $bw.Write([short]1); $bw.Write([short]1)
                $bw.Write([int]$sampleRate); $bw.Write([int]($sampleRate * 2))
                $bw.Write([short]2); $bw.Write([short]16)
                $bw.Write([Text.Encoding]::ASCII.GetBytes('data'))
                $bw.Write([int]$dataBytes)
                foreach ($n in $notes) {
                    $sCount = [int]($sampleRate * ($n.DurMs / 1000.0))
                    $freq = [double]$n.Freq
                    for ($i = 0; $i -lt $sCount; $i++) {
                        $t = [double]$i / [double]$sampleRate
                        $env = [Math]::Exp(-3.8 * ([double]$i / [double]$sCount))
                        $val = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * $env * 0.65
                        $sample = [short]([Math]::Max(-32767, [Math]::Min(32767, [int]($val * 32767))))
                        $bw.Write($sample)
                    }
                }
                $bw.Flush(); $ms.Position = 0
                $player = New-Object System.Media.SoundPlayer($ms)
                $player.PlaySync()
            } catch {}
        })
        [void]$psAudio.BeginInvoke()
    } catch {
        try { [Console]::Beep(523,110); [Console]::Beep(659,110); [Console]::Beep(784,110); [Console]::Beep(1046,220) } catch {}
    }
}

function Play-SLTUninstallTone {
    # Fix #7: Guaranteed audible descending 2-note tone for Uninstall Completion (659Hz -> 523Hz)
    try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
    try {
        $psAudio = [PowerShell]::Create()
        [void]$psAudio.AddScript({
            try {
                [Console]::Beep(659, 140)
                [Console]::Beep(523, 240)
            } catch {}
            try {
                $sampleRate = 22050
                $notes = @(
                    @{ Freq = 659.25; DurMs = 150 },
                    @{ Freq = 523.25; DurMs = 280 }
                )
                $totalSamples = 0
                foreach ($n in $notes) { $totalSamples += [int]($sampleRate * ($n.DurMs / 1000.0)) }
                $dataBytes = $totalSamples * 2
                $ms = New-Object System.IO.MemoryStream
                $bw = New-Object System.IO.BinaryWriter($ms)
                $bw.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
                $bw.Write([int](36 + $dataBytes))
                $bw.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
                $bw.Write([int]16); $bw.Write([short]1); $bw.Write([short]1)
                $bw.Write([int]$sampleRate); $bw.Write([int]($sampleRate * 2))
                $bw.Write([short]2); $bw.Write([short]16)
                $bw.Write([Text.Encoding]::ASCII.GetBytes('data'))
                $bw.Write([int]$dataBytes)
                foreach ($n in $notes) {
                    $sCount = [int]($sampleRate * ($n.DurMs / 1000.0))
                    $freq = [double]$n.Freq
                    for ($i = 0; $i -lt $sCount; $i++) {
                        $t = [double]$i / [double]$sampleRate
                        $env = [Math]::Exp(-3.8 * ([double]$i / [double]$sCount))
                        $val = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * $env * 0.65
                        $sample = [short]([Math]::Max(-32767, [Math]::Min(32767, [int]($val * 32767))))
                        $bw.Write($sample)
                    }
                }
                $bw.Flush(); $ms.Position = 0
                $player = New-Object System.Media.SoundPlayer($ms)
                $player.PlaySync()
            } catch {}
        })
        [void]$psAudio.BeginInvoke()
    } catch {
        try { [Console]::Beep(659,140); [Console]::Beep(523,240) } catch {}
    }
}

function Show-SLTInstallMonitor([string]$ProgressFile,[string]$LogFile,[string]$Title,[System.Diagnostics.Process]$Worker,[string]$Verb='Install',[object[]]$OriginalPackages=@()) {
    $chkIcon   = [char]0x2713
    $infoIcon  = [char]0x2139
    $crossIcon = [char]0x2717
    $emDash    = [char]0x2014
    $sparkle   = [char]0x2728
    $conv      = [Windows.Media.BrushConverter]::new()

    $isUninst = ($Verb -eq 'Uninstall')
    $win = New-Object Windows.Window
    $win.Title = if($isUninst){'SLT Smart Uninstallation in Progress'}else{'SLT Smart Installation in Progress'}
    $win.Width = 720; $win.Height = 540; $win.MinWidth = 560
    $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $script:Window
    Apply-SLTDialogTheme $win

    $rootGrid = New-Object Windows.Controls.Grid; $rootGrid.Margin = [Windows.Thickness]::new(20,16,20,14)
    $gr0 = New-Object Windows.Controls.RowDefinition; $gr0.Height = [Windows.GridLength]::Auto
    $gr1 = New-Object Windows.Controls.RowDefinition; $gr1.Height = [Windows.GridLength]::Auto
    $gr2 = New-Object Windows.Controls.RowDefinition; $gr2.Height = [Windows.GridLength]::Auto
    $gr3 = New-Object Windows.Controls.RowDefinition; $gr3.Height = [Windows.GridLength]::Auto
    $gr4 = New-Object Windows.Controls.RowDefinition; $gr4.Height = New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $gr5 = New-Object Windows.Controls.RowDefinition; $gr5.Height = [Windows.GridLength]::Auto
    foreach($r in @($gr0,$gr1,$gr2,$gr3,$gr4,$gr5)){ $rootGrid.RowDefinitions.Add($r)|Out-Null }

    # Row 0: Modal Title + Live Counts
    $hdrGrid = New-Object Windows.Controls.Grid; $hdrGrid.Margin = [Windows.Thickness]::new(0,0,0,8)
    $hc0 = New-Object Windows.Controls.ColumnDefinition; $hc0.Width = New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $hc1 = New-Object Windows.Controls.ColumnDefinition; $hc1.Width = [Windows.GridLength]::Auto
    $hdrGrid.ColumnDefinitions.Add($hc0)|Out-Null; $hdrGrid.ColumnDefinitions.Add($hc1)|Out-Null
    $hdrTitle = New-Object Windows.Controls.TextBlock
    $hdrTitle.Text = if($isUninst){'Software Uninstallation in Progress'}else{'Software Installation in Progress'}
    $hdrTitle.FontSize = 17; $hdrTitle.FontWeight = 'Bold'
    $hdrTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextAccent')
    $countsLbl = New-Object Windows.Controls.TextBlock
    $countsLbl.Text = if($isUninst){'Uninstalled: 0 | Skipped: 0 | Failed: 0'}else{'Installed: 0 | Already: 0 | Failed: 0'}
    $countsLbl.FontSize = 12; $countsLbl.FontWeight = 'Bold'; $countsLbl.VerticalAlignment = 'Center'
    $countsLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    $countsLbl.SetValue([Windows.Controls.Grid]::ColumnProperty,1)
    $hdrGrid.Children.Add($hdrTitle)|Out-Null; $hdrGrid.Children.Add($countsLbl)|Out-Null
    $hdrGrid.SetValue([Windows.Controls.Grid]::RowProperty,0)
    $rootGrid.Children.Add($hdrGrid)|Out-Null

    # Row 1: SMALL SMART BLINKING NOTIFICATION STRIP (Auto-hides after 5 seconds)
    $notifCard = New-Object Windows.Controls.Border
    $notifCard.Background = $conv.ConvertFromString('#064E3B')
    $notifCard.BorderBrush = $conv.ConvertFromString('#10B981')
    $notifCard.BorderThickness = [Windows.Thickness]::new(1.8)
    $notifCard.CornerRadius = [Windows.CornerRadius]::new(10)
    $notifCard.Padding = [Windows.Thickness]::new(14,8,14,8)
    $notifCard.Margin = [Windows.Thickness]::new(0,0,0,8)
    $notifCard.Visibility = 'Collapsed'
    $succStack = New-Object Windows.Controls.StackPanel
    $succMainTxt = New-Object Windows.Controls.TextBlock
    $succMainTxt.Text = "WOW! Processing Packages - Smart Life Teck | Shahzad Babar www.smartlifeteck.com"
    $succMainTxt.FontSize = 13.2; $succMainTxt.FontWeight = 'Bold'; $succMainTxt.Foreground = $conv.ConvertFromString('#ECFDF5')
    $succMainTxt.HorizontalAlignment = 'Center'; $succMainTxt.TextWrapping = 'Wrap'; $succMainTxt.TextAlignment = 'Center'
    $succSubTxt = New-Object Windows.Controls.TextBlock
    $succSubTxt.Text = 'Software Installation Successfully'
    $succSubTxt.FontSize = 11.5; $succSubTxt.FontWeight = 'SemiBold'; $succSubTxt.Foreground = $conv.ConvertFromString('#A7F3D0')
    $succSubTxt.HorizontalAlignment = 'Center'; $succSubTxt.Margin = [Windows.Thickness]::new(0,2,0,0); $succSubTxt.TextWrapping = 'Wrap'; $succSubTxt.TextAlignment = 'Center'
    $succStack.Children.Add($succMainTxt)|Out-Null
    $succStack.Children.Add($succSubTxt)|Out-Null
    $notifCard.Child = $succStack
    $notifCard.SetValue([Windows.Controls.Grid]::RowProperty,1)
    $rootGrid.Children.Add($notifCard)|Out-Null

    # Row 2: TOP STATUS BAR (Current Tool Being Processed)
    $topCard = New-Object Windows.Controls.Border
    $topCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'CardSurface')
    $topCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'CardBorder')
    $topCard.BorderThickness = [Windows.Thickness]::new(1); $topCard.CornerRadius = [Windows.CornerRadius]::new(10)
    $topCard.Padding = [Windows.Thickness]::new(14,9,14,9); $topCard.Margin = [Windows.Thickness]::new(0,0,0,8)
    $topStack = New-Object Windows.Controls.StackPanel
    $topRow = New-Object Windows.Controls.Grid; $topRow.Margin = [Windows.Thickness]::new(0,0,0,5)
    $tc0 = New-Object Windows.Controls.ColumnDefinition; $tc0.Width = New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $tc1 = New-Object Windows.Controls.ColumnDefinition; $tc1.Width = [Windows.GridLength]::Auto
    $topRow.ColumnDefinitions.Add($tc0)|Out-Null; $topRow.ColumnDefinitions.Add($tc1)|Out-Null

    $curToolLbl = New-Object Windows.Controls.TextBlock
    $curToolLbl.Text = $Title; $curToolLbl.FontSize = 12.8; $curToolLbl.FontWeight = 'Bold'
    $curToolLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextPrimary')
    $phasePill = New-Object Windows.Controls.Border
    $phasePill.CornerRadius = [Windows.CornerRadius]::new(6); $phasePill.Padding = [Windows.Thickness]::new(8,2,8,2)
    $phasePill.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'BtnSelectedBg')
    $phaseTxt = New-Object Windows.Controls.TextBlock
    $phaseTxt.Text = 'Checking...'; $phaseTxt.FontSize = 10.5; $phaseTxt.FontWeight = 'Bold'
    $phaseTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'BtnSelectedText')
    $phasePill.Child = $phaseTxt
    $phasePill.SetValue([Windows.Controls.Grid]::ColumnProperty,1)
    $topRow.Children.Add($curToolLbl)|Out-Null; $topRow.Children.Add($phasePill)|Out-Null

    $topBar = New-Object Windows.Controls.ProgressBar; $topBar.Minimum = 0; $topBar.Maximum = 100; $topBar.Value = 25; $topBar.Height = 9
    $topBar.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'BtnSelectedBg')
    $topBar.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardDeep')
    $topBar.BorderThickness = [Windows.Thickness]::new(0)

    $lastActionLbl = New-Object Windows.Controls.TextBlock
    $lastActionLbl.Text = 'Checking package status (max 120 sec per app)...'; $lastActionLbl.FontSize = 11; $lastActionLbl.Margin = [Windows.Thickness]::new(0,4,0,0)
    $lastActionLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')

    $topStack.Children.Add($topRow)|Out-Null; $topStack.Children.Add($topBar)|Out-Null; $topStack.Children.Add($lastActionLbl)|Out-Null
    $topCard.Child = $topStack
    $topCard.SetValue([Windows.Controls.Grid]::RowProperty,2)
    $rootGrid.Children.Add($topCard)|Out-Null

    # Row 3: BOTTOM STATUS BAR (Overall Progress Bar)
    $botCard = New-Object Windows.Controls.Border
    $botCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'CardSurface')
    $botCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'CardBorder')
    $botCard.BorderThickness = [Windows.Thickness]::new(1); $botCard.CornerRadius = [Windows.CornerRadius]::new(10)
    $botCard.Padding = [Windows.Thickness]::new(14,9,14,9); $botCard.Margin = [Windows.Thickness]::new(0,0,0,8)
    $botStack = New-Object Windows.Controls.StackPanel
    $botRow = New-Object Windows.Controls.Grid; $botRow.Margin = [Windows.Thickness]::new(0,0,0,5)
    $bc0 = New-Object Windows.Controls.ColumnDefinition; $bc0.Width = New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $bc1 = New-Object Windows.Controls.ColumnDefinition; $bc1.Width = [Windows.GridLength]::Auto
    $botRow.ColumnDefinitions.Add($bc0)|Out-Null; $botRow.ColumnDefinitions.Add($bc1)|Out-Null

    $overallTitle = New-Object Windows.Controls.TextBlock
    $overallTitle.Text = 'OVERALL BATCH PROGRESS'; $overallTitle.FontSize = 11; $overallTitle.FontWeight = 'Bold'
    $overallTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    $overallPctLbl = New-Object Windows.Controls.TextBlock
    $overallPctLbl.Text = '0 of 0 - 0%'; $overallPctLbl.FontSize = 12; $overallPctLbl.FontWeight = 'Bold'
    $overallPctLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextAccent')
    $overallPctLbl.SetValue([Windows.Controls.Grid]::ColumnProperty,1)
    $botRow.Children.Add($overallTitle)|Out-Null; $botRow.Children.Add($overallPctLbl)|Out-Null

    $overallBar = New-Object Windows.Controls.ProgressBar; $overallBar.Minimum = 0; $overallBar.Maximum = 100; $overallBar.Value = 0; $overallBar.Height = 12
    $overallBar.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'SLTStatusOk')
    $overallBar.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardDeep')
    $overallBar.BorderThickness = [Windows.Thickness]::new(0)

    $botStack.Children.Add($botRow)|Out-Null; $botStack.Children.Add($overallBar)|Out-Null
    $botCard.Child = $botStack
    $botCard.SetValue([Windows.Controls.Grid]::RowProperty,3)
    $rootGrid.Children.Add($botCard)|Out-Null

    # Row 4: Per-Tool Live Results List
    $feedBox = New-Object Windows.Controls.TextBox
    $feedBox.IsReadOnly = $true; $feedBox.TextWrapping = 'Wrap'; $feedBox.VerticalScrollBarVisibility = 'Auto'
    $feedBox.FontFamily = 'Consolas'; $feedBox.FontSize = 11.8
    $feedBox.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardDeep')
    $feedBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty,'CardBorder')
    $feedBox.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary')
    $feedBox.Padding = [Windows.Thickness]::new(12,10,12,10)
    $feedBox.Text = 'Pre-checking selected packages on this PC...'
    $feedBox.SetValue([Windows.Controls.Grid]::RowProperty,4)
    $rootGrid.Children.Add($feedBox)|Out-Null

    # Row 5: Branding Footer + Try Again + Open Log Folder + Close Buttons
    $fGrid = New-Object Windows.Controls.Grid; $fGrid.Margin = [Windows.Thickness]::new(0,10,0,0)
    $fc0 = New-Object Windows.Controls.ColumnDefinition; $fc0.Width = New-Object Windows.GridLength(1,[Windows.GridUnitType]::Star)
    $fc1 = New-Object Windows.Controls.ColumnDefinition; $fc1.Width = [Windows.GridLength]::Auto
    $fGrid.ColumnDefinitions.Add($fc0)|Out-Null; $fGrid.ColumnDefinitions.Add($fc1)|Out-Null

    $footerBrand = New-Object Windows.Controls.TextBlock
    $footerBrand.Text = 'Powered by Smart Life Teck | Shahzad Babar (www.smartlifeteck.com)'
    $footerBrand.FontSize = 10.5; $footerBrand.VerticalAlignment = 'Center'
    $footerBrand.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    $fGrid.Children.Add($footerBrand)|Out-Null

    $buttons = New-Object Windows.Controls.StackPanel; $buttons.Orientation = 'Horizontal'
    $failedPkgsList = New-Object System.Collections.Generic.List[object]

    $retryBtn = New-Object Windows.Controls.Button; $retryBtn.Content = 'Try Again'; $retryBtn.Style = $script:Window.FindResource('ActionButton')
    $retryBtn.MinHeight = 34; $retryBtn.Padding = [Windows.Thickness]::new(14,4,14,4); $retryBtn.Margin = [Windows.Thickness]::new(0,0,6,0)
    $retryBtn.Visibility = 'Collapsed'

    $open = New-Object Windows.Controls.Button; $open.Content = 'Open Log Folder'; $open.Style = $script:Window.FindResource('OutlineButton')
    $open.MinHeight = 34; $open.Padding = [Windows.Thickness]::new(12,4,12,4); $open.Margin = [Windows.Thickness]::new(0,0,6,0)

    $hide = New-Object Windows.Controls.Button; $hide.Content = 'Close'; $hide.Style = $script:Window.FindResource('ActionButton')
    $hide.MinHeight = 34; $hide.Padding = [Windows.Thickness]::new(16,4,16,4)
    $hide.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'BtnSelectedBg')
    $hide.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'BtnSelectedText')

    $buttons.Children.Add($retryBtn)|Out-Null; $buttons.Children.Add($open)|Out-Null; $buttons.Children.Add($hide)|Out-Null
    $buttons.SetValue([Windows.Controls.Grid]::ColumnProperty,1)
    $fGrid.Children.Add($buttons)|Out-Null
    $fGrid.SetValue([Windows.Controls.Grid]::RowProperty,5)
    $rootGrid.Children.Add($fGrid)|Out-Null

    $win.Content = $rootGrid

    $blinkTimer = New-Object Windows.Threading.DispatcherTimer
    $blinkTimer.Interval = [TimeSpan]::FromMilliseconds(500)

    $autoHideTimer = New-Object Windows.Threading.DispatcherTimer
    $autoHideTimer.Interval = [TimeSpan]::FromSeconds(5)

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(420)

    # Store all monitor controls in $script:MonitorState (NO .GetNewClosure() needed!)
    $script:MonitorState = @{
        Win              = $win
        ProgressFile     = $ProgressFile
        LogFile          = $LogFile
        Worker           = $Worker
        Verb             = $Verb
        OriginalPackages = @($OriginalPackages)
        FailedPkgs       = $failedPkgsList
        HdrTitle         = $hdrTitle
        CountsLbl        = $countsLbl
        NotifCard        = $notifCard
        SuccMainTxt      = $succMainTxt
        SuccSubTxt       = $succSubTxt
        TopCard          = $topCard
        CurToolLbl       = $curToolLbl
        PhaseTxt         = $phaseTxt
        TopBar           = $topBar
        LastActionLbl    = $lastActionLbl
        OverallPctLbl    = $overallPctLbl
        OverallBar       = $overallBar
        FeedBox          = $feedBox
        RetryBtn         = $retryBtn
        HideBtn          = $hide
        BlinkState       = $true
        BlinkTimer       = $blinkTimer
        AutoHideTimer    = $autoHideTimer
        Timer            = $timer
        SoundPlayed      = $false
        RefreshDone      = $false
    }

    $retryBtn.Add_Click({
        try {
            $st = $script:MonitorState
            if ($null -ne $st.Win) { $st.Win.Close() }
            if ($null -ne $st.FailedPkgs -and $st.FailedPkgs.Count -gt 0) {
                Start-SLTQueue -Packages @($st.FailedPkgs.ToArray()) -Verb $st.Verb -Manager 'WinGet' -OfflineCache $false -AutoUpgrade $false
            }
        } catch {}
    })

    $open.Add_Click({
        try { Start-Process -FilePath (Split-Path -Parent $script:MonitorState.LogFile) } catch {}
    })

    $hide.Add_Click({
        try {
            if (-not $script:MonitorState.RefreshDone -and $script:MonitorState.Worker.HasExited) {
                $script:MonitorState.RefreshDone = $true
                Refresh-Grid
            }
            $script:MonitorState.Win.Close()
        } catch {}
    })

    $blinkTimer.Add_Tick({
        try {
            if (-not $script:MonitorState.ContainsKey('BlinkTicks')) { $script:MonitorState['BlinkTicks'] = 0 }
            $script:MonitorState['BlinkTicks'] = [int]$script:MonitorState['BlinkTicks'] + 1
            if ([int]$script:MonitorState['BlinkTicks'] -ge 6) {
                $script:MonitorState.BlinkTimer.Stop()
                $script:MonitorState.NotifCard.Opacity = 1.0
                return
            }
            $script:MonitorState.BlinkState = (-not $script:MonitorState.BlinkState)
            $script:MonitorState.NotifCard.Opacity = if($script:MonitorState.BlinkState){ 1.0 } else { 0.42 }
        } catch {}
    })

    $autoHideTimer.Add_Tick({
        try {
            # Persistent result banner: NEVER collapse NotifCard automatically; keep solid at Opacity 1.0 until user clicks Close
            $script:MonitorState.AutoHideTimer.Stop()
            $script:MonitorState.BlinkTimer.Stop()
            $script:MonitorState.NotifCard.Opacity = 1.0
            $script:MonitorState.NotifCard.Visibility = 'Visible'
        } catch {}
    })

    $timer.Add_Tick({
        $st = $script:MonitorState
        if ($null -eq $st) { return }
        $chkSym   = [char]0x2713
        $infoSym  = [char]0x2139
        $crossSym = [char]0x2717
        $emSym    = [char]0x2014

        if (-not (Test-Path -LiteralPath $st.ProgressFile)) {
            if ($st.Worker.HasExited) {
                $st.Timer.Stop()
                $st.CurToolLbl.Text = 'Worker exited before progress started'
                $st.LastActionLbl.Text = 'Check the log report.'
                $st.HideBtn.Content = 'Close'
            }
            return
        }
        try {
            $data = Get-Content -LiteralPath $st.ProgressFile -Raw -ErrorAction Stop | ConvertFrom-Json
            $jobVerb = if($data.PSObject.Properties['verb'] -and $data.verb){[string]$data.verb}else{$st.Verb}
            $isUn = ($jobVerb -eq 'Uninstall')

            $st.OverallBar.Value = [Math]::Min(100,[Math]::Max(0,[double]$data.percent))
            $etaTxt = if($data.PSObject.Properties['remainingEtaMin'] -and [double]$data.remainingEtaMin -gt 0){"  |  ETA ~$([Math]::Ceiling([double]$data.remainingEtaMin)) min"}else{""}
            $st.OverallPctLbl.Text = ("{0} of {1} $emSym {2}%{3}" -f $data.completed,$data.total,$data.percent,$etaTxt)

            $instCnt   = if($data.PSObject.Properties['installed']){[int]$data.installed}else{0}
            $uninstCnt = if($data.PSObject.Properties['uninstalled']){[int]$data.uninstalled}else{0}
            $skipCnt   = if($data.PSObject.Properties['skipped']){[int]$data.skipped}elseif($data.PSObject.Properties['already']){[int]$data.already}else{0}
            $failCnt   = if($data.PSObject.Properties['failures']){[int]$data.failures}else{0}

            if ($isUn) {
                $st.CountsLbl.Text = ("Uninstalled: {0} | Skipped: {1} | Failed: {2}" -f $uninstCnt,$skipCnt,$failCnt)
            } else {
                $st.CountsLbl.Text = ("Installed: {0} | Already: {1} | Failed: {2}" -f $instCnt,$skipCnt,$failCnt)
            }

            $widTxt = if($data.PSObject.Properties['currentWid'] -and $data.currentWid){' ('+[string]$data.currentWid+')'}else{''}
            $st.CurToolLbl.Text = ([string]$data.current + $widTxt)
            $st.LastActionLbl.Text = [string]$data.last

            $ph = if($data.PSObject.Properties['currentPhase'] -and $data.currentPhase){[string]$data.currentPhase}else{'Running'}
            $phPct = if($data.PSObject.Properties['currentPct']){[double]$data.currentPct}else{50}
            $st.TopBar.Value = [Math]::Min(100,[Math]::Max(0,$phPct))

            if ($ph -eq 'Checking') {
                $st.PhaseTxt.Text = '[?] Checking...'
            } elseif ($ph -in @('Installing','Uninstalling')) {
                $st.PhaseTxt.Text = "[->] $ph..."
            } elseif ($ph -in @('Done','Uninstalled')) {
                $st.PhaseTxt.Text = "[$chkSym] $ph"
            } elseif ($ph -in @('Skipped','Already Installed')) {
                $st.PhaseTxt.Text = "[$infoSym] Already Installed"
            } else {
                $st.PhaseTxt.Text = "[$crossSym] $ph"
            }

            if ($data.PSObject.Properties['results'] -and @($data.results).Count -gt 0) {
                $fLines = New-Object System.Collections.Generic.List[string]
                $st.FailedPkgs.Clear()
                foreach ($rx in @($data.results)) {
                    $rst = [string]$rx.status
                    $rNote = if($rx.PSObject.Properties['note'] -and $rx.note){[string]$rx.note}else{''}
                    $rKey  = if($rx.PSObject.Properties['key'] -and $rx.key){[string]$rx.key}else{''}

                    if ($rst -eq 'Installed Successfully') {
                        $fLines.Add("$chkSym $($rx.name) - Installed Successfully")
                        if ($rKey -and $null -ne $script:ScannedInstalledApps) {
                            $script:ScannedInstalledApps[$rKey] = @{ Name=$rx.name; Winget=$rx.winget; Version='Installed' }
                        }
                    } elseif ($rst -eq 'Uninstalled Successfully') {
                        $fLines.Add("$chkSym $($rx.name) - Uninstalled Successfully")
                        if ($rKey -and $null -ne $script:ScannedInstalledApps -and $script:ScannedInstalledApps.ContainsKey($rKey)) {
                            $null = $script:ScannedInstalledApps.Remove($rKey)
                        }
                    } elseif ($rst -eq 'Already Installed Skipped' -or $rst -eq 'Skipped') {
                        $skipReason = if($rNote){$rNote}elseif($isUn){'Not Installed - Package is not currently installed on this PC'}else{'Already Installed - Package already exists on this PC - No download needed'}
                        $fLines.Add("$chkSym $($rx.name) - $skipReason")
                    } else {
                        $failReason = if($rNote){$rNote}else{'Failed - Server Busy - Try Again Later'}
                        $fLines.Add("$crossSym $($rx.name) - $failReason")
                        foreach ($op in $st.OriginalPackages) {
                            $opWid  = if($op -is [hashtable]){$op['winget']}elseif($op.PSObject.Properties['winget']){$op.winget}else{''}
                            $opName = if($op -is [hashtable]){$op['name']}elseif($op.PSObject.Properties['name']){$op.name}else{''}
                            if ($opWid -eq $rx.winget -or $opName -eq $rx.name) {
                                $st.FailedPkgs.Add($op)
                                break
                            }
                        }
                    }
                }
                $st.FeedBox.Text = ($fLines -join [Environment]::NewLine)
                $st.FeedBox.ScrollToEnd()
            }

            if ([string]$data.state -in @('Finished','Fatal')) {
                $st.Timer.Stop()
                $st.HideBtn.Content = 'Close'
                $st.TopCard.Visibility = 'Collapsed'

                $savedMinVal = if($data.PSObject.Properties['savedMinutes'] -and [int]$data.savedMinutes -gt 0){[int]$data.savedMinutes}else{[Math]::Max(1, $skipCnt)}
                $okVal = if($isUn){ $uninstCnt } else { $instCnt }
                $modeStr = if($isUn){ 'Uninstall' } else { 'Install' }

                # Fix #5: Show WOW Notification with full text BEFORE refreshing grid
                Show-WOWNotification -Mode $modeStr -OkCount $okVal -SkipCount $skipCnt -FailCount $failCnt -SavedMin $savedMinVal

                if ($failCnt -gt 0 -and $st.FailedPkgs.Count -gt 0) {
                    $st.RetryBtn.Visibility = 'Visible'
                }

                # Fix #1: Automatic full grid, badge, recycle bin, status line & counter refresh!
                if (-not $st.RefreshDone) {
                    $st.RefreshDone = $true
                    Refresh-Grid
                }
            } elseif ($st.Worker.HasExited) {
                $st.Timer.Stop()
                $st.CurToolLbl.Text = 'Process finished'
                $st.HideBtn.Content = 'Close'
                if (-not $st.RefreshDone) {
                    $st.RefreshDone = $true
                    Refresh-Grid
                }
            }
        } catch {
            Log-SLT ('Monitor tick warning: ' + $_.Exception.Message)
        }
    })

    $win.Add_Closed({
        try {
            $script:MonitorState.Timer.Stop()
            $script:MonitorState.BlinkTimer.Stop()
            $script:MonitorState.AutoHideTimer.Stop()
            if (-not $script:MonitorState.RefreshDone) {
                $script:MonitorState.RefreshDone = $true
                Refresh-Grid
            }
        } catch {}
    })

    $timer.Start()
    $win.Show() | Out-Null
}

function Start-SLTQueue([object[]]$Packages,[string]$Verb,[string]$Manager,[bool]$OfflineCache=$false,[bool]$AutoUpgrade=$true) {
    # One quiet background PowerShell, visible progress WPF monitor; no terminal flashing.
    Need-SLTAdmin
    if(@($Packages).Count -eq 0){throw 'No packages selected.'}
    $id=Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $manifest=Join-Path $script:StateDir ('PackageJob_'+$id+'.json')
    $progress=Join-Path $script:StateDir ('PackageProgress_'+$id+'.json')
    $jobLog=Join-Path $script:LogDir ('PackageQueue_'+$id+'.txt')
    $cacheDir=Join-Path $script:Root 'SLT_Offline_Cache'
    @{verb=$Verb;manager=$Manager;offlineCache=$OfflineCache;autoUpgrade=$AutoUpgrade;cacheDir=$cacheDir;packages=@($Packages);progress=$progress;log=$jobLog}|
       ConvertTo-Json -Depth 7|Set-Content -LiteralPath $manifest -Encoding UTF8
    $worker=Join-Path $script:Root 'tools\Run-SLT-Packages.ps1'
    $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Manifest "'+$manifest+'"'
    $process=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -ErrorAction Stop
    Show-SLTInstallMonitor $progress $jobLog ('Preparing '+$Verb.ToLowerInvariant()+' for '+@($Packages).Count+' packages') $process $Verb $Packages
    Log-SLT ("Started {0} package(s): {1} using {2}. Progress: {3}" -f @($Packages).Count,$Verb,$Manager,$progress)
}
function Start-SLTExternalPackage([string]$ID,[ValidateSet('Install','Uninstall','Upgrade')][string]$Verb,[ValidateSet('WinGet','Chocolatey')][string]$Manager) {
   Start-SLTQueue @(@{name=$ID;winget=$ID;choco='';}) $Verb $Manager
}
function Open-SLTInstalledApplications {
   # Native Settings view: audit installed software, no changes performed.
   Start-Process 'ms-settings:appsfeatures'
}
function Open-SLTAdvancedTools {
    # Smart Life Teck native system maintenance & administrative console launcher.
    Need-SLTAdmin
    Start-Process -FilePath 'control.exe' -ArgumentList 'admintools'
    Log-SLT 'Opened Smart Life Teck / Windows Administrative Tools console. Developed by Shahzad Babar.'
}
function Export-SLTTaskDefinition([string]$TaskName) {
    Need-SLTAdmin
    $safeName = $TaskName -replace '[^A-Za-z0-9_-]','_'
    $backupPath = Join-Path $script:StateDir ('ScheduledTask_{0}_{1}.xml' -f $safeName,(Get-Date -Format 'yyyyMMdd_HHmmss'))
    $xmlLines = & schtasks.exe /Query /TN $TaskName /XML 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $xmlLines) { throw ("Could not export existing scheduled task: $TaskName") }
    Set-Content -LiteralPath $backupPath -Value ($xmlLines -join "`r`n") -Encoding UTF8 -ErrorAction Stop
    Log-SLT ("Exported scheduled task backup: $TaskName -> $backupPath")
    return $backupPath
}
function Start-SLTMonthlyCleanup {
    Need-SLTAdmin
    $taskName = 'SLT Monthly Safe Temp Cleanup'
    $scriptPath = Join-Path $script:Base 'MonthlyClean.ps1'
    $taskExists = $false
    & schtasks.exe /Query /TN $taskName 2>$null | Out-Null
    $taskExists = ($LASTEXITCODE -eq 0)
    $taskBackup = $null
    if ($taskExists) {
        $taskBackup = Export-SLTTaskDefinition $taskName
        $confirmReplace = [Windows.MessageBox]::Show(("A scheduled task named '$taskName' already exists. Its XML will be backed up to:`n$taskBackup`n`nReplace it with the SLT monthly temp-cleanup task?"),'Confirm Scheduled Task Replacement','YesNo','Warning')
        if ($confirmReplace -ne 'Yes') { Log-SLT 'Monthly cleanup schedule replacement cancelled.'; return }
    }
    $scriptBackup = $null
    $scriptExisted = Test-Path -LiteralPath $scriptPath
    if ($scriptExisted) {
        $scriptBackup = Join-Path $script:StateDir ('MonthlyClean_{0}.ps1.bak' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Copy-Item -LiteralPath $scriptPath -Destination $scriptBackup -Force -ErrorAction Stop
        if (-not $taskExists) {
            $confirmScript = [Windows.MessageBox]::Show(("An existing MonthlyClean.ps1 file was found and backed up to:`n$scriptBackup`n`nReplace it with the SLT cleanup script?"),'Confirm Cleanup Script Replacement','YesNo','Warning')
            if ($confirmScript -ne 'Yes') { return }
        }
    }
    $content=@'
# SLT monthly old temp cleanup; use only old files, no personal directories.
$limit=(Get-Date).AddDays(-7)
foreach($folder in @($env:TEMP,"$env:WINDIR\Temp")) {
 if(Test-Path -LiteralPath $folder) {Get-ChildItem -LiteralPath $folder -File -Force -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -lt $limit} | ForEach-Object {try{Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop}catch{}}}
}
'@
    $tmpScript = $scriptPath + '.tmp'
    try {
        Set-Content -LiteralPath $tmpScript -Value $content -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $tmpScript -Destination $scriptPath -Force -ErrorAction Stop
        $arg=('powershell.exe -NoProfile -File "{0}"' -f $scriptPath)
        $createArgs = @('/Create','/TN',$taskName,'/SC','MONTHLY','/D','1','/ST','12:00','/RU','SYSTEM','/RL','HIGHEST','/TR',$arg)
        if ($taskExists) { $createArgs += '/F' }
        & schtasks.exe @createArgs | Out-Null
        if($LASTEXITCODE -ne 0){throw "Task scheduling failed: $LASTEXITCODE"}
        Log-SLT 'Monthly cleanup set for day 1 at 12:00; old unlocked temp files only; no resident agent.'
    } catch {
        Remove-Item -LiteralPath $tmpScript -Force -ErrorAction SilentlyContinue
        if ($scriptBackup -and (Test-Path -LiteralPath $scriptBackup)) { Copy-Item -LiteralPath $scriptBackup -Destination $scriptPath -Force -ErrorAction SilentlyContinue }
        elseif (-not $scriptExisted -and (Test-Path -LiteralPath $scriptPath)) { Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue }
        if ($taskBackup -and (Test-Path -LiteralPath $taskBackup)) { try { & schtasks.exe /Create /TN $taskName /XML $taskBackup /F | Out-Null } catch {} }
        throw
    }
}
function Get-SLTUsbFolder {
    $usbRoot=[IO.Path]::GetPathRoot($script:Root)
    $letter=$usbRoot.Substring(0,1)
    try{$part=Get-Partition -DriveLetter $letter -ErrorAction Stop|Select-Object -First 1;$disk=$part|Get-Disk -ErrorAction Stop;if($disk.BusType -eq 'USB'){return (Join-Path $usbRoot 'SLT_Diagnostic_Reports')}}catch{}
    return $null
}
function Invoke-SLTDiagnostics {
    # Windows native hardware report; USB mode saves outputs to removable drive ONLY.
    $pc=Get-SLTHardware;$issues=@(Get-SLTBadDrivers)
    $report=New-Object System.Collections.Generic.List[string]
    $report.Add('SLT Smart PC Boost - Diagnostics '+(Get-Date))
    $report.Add("Manufacturer: $($pc.Maker) | Model: $($pc.Model) | Serial: $($pc.Serial)")
    $report.Add("Windows: $($pc.OS) | RAM: $($pc.RAM) GB | Driver issues: $($issues.Count)")
    try {$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1;$report.Add("CPU: $($cpu.Name)")}catch{}
    try {Get-CimInstance Win32_VideoController|ForEach-Object{$report.Add("GPU: $($_.Name) | Driver: $($_.DriverVersion)")}}catch{}

    try {Get-PhysicalDisk|ForEach-Object {$report.Add("Disk: $($_.FriendlyName) | Health=$($_.HealthStatus) | SizeGB=$([math]::Round($_.Size/1GB,1))")}}catch {$report.Add('Disk health detail unavailable; use CrystalDiskInfo USB edition if needed.')}
    foreach($i in $issues){$report.Add("Driver: $($i.FriendlyName) - $($i.Status)")}
    $text=$report -join "`r`n"
    Log-SLT $text
    $usb=Get-SLTUsbFolder
    if($usb) {
       New-Item -Path $usb -ItemType Directory -Force|Out-Null
       $out=Join-Path $usb ('Health_{0}.txt' -f (Get-Date -Format yyyyMMdd_HHmmss))
       $text|Set-Content -LiteralPath $out -Encoding UTF8
       $battery=Join-Path $usb ('Battery_{0}.html' -f (Get-Date -Format yyyyMMdd_HHmmss))
       & powercfg.exe /batteryreport /output $battery | Out-Null
       Log-SLT "USB diagnostics saved: $out and $battery"
    } else {Log-SLT 'Read-only diagnostics shown above. For portable battery export, run SLT directly from a USB drive.'}
}

# Catalog records may legally omit Description. Never read an absent member under StrictMode.
function Get-SLTOptionalText {
    param([AllowNull()][object]$Object,[string]$Property,[string]$Fallback='')
    if($null -eq $Object) { return $Fallback }
    if($Object -is [System.Collections.IDictionary]) {
        if($Object.Contains($Property) -and $null -ne $Object[$Property]) { return [string]$Object[$Property] }
        return $Fallback
    }
    $p = $Object.PSObject.Properties[$Property]
    if($null -eq $p -or $null -eq $p.Value -or [string]::IsNullOrWhiteSpace([string]$p.Value)) { return $Fallback }
    return [string]$p.Value
}
function Get-SLTUpstreamDescription {
    param([AllowNull()][object]$Record)
    $title=Get-SLTOptionalText $Record 'Content' 'SLT option'
    return (Get-SLTOptionalText $Record 'Description' ('Smart Life Teck: '+$title+'. Review this option before applying any changes.'))
}

# Single source of truth for the 203-tool catalog (data\applications.json).
# Used by pages\02-Install.ps1 (UI) AND tools\Run-SLT-StartupScan.ps1 (headless
# background worker) so both always see the exact same AppRecords/AppIndex -
# no duplicated parsing logic to keep in sync by hand.
function Get-SLTAppCatalogRecords([string]$RootPath) {
    $catalog = Get-Content -LiteralPath (Join-Path $RootPath 'data\applications.json') -Raw | ConvertFrom-Json
    $records = @(foreach($p in $catalog.PSObject.Properties) {
        $v = $p.Value
        $cat = (Get-SLTOptionalText $v 'category' 'System utilities')
        $grp = (Get-SLTOptionalText $v 'group' $(if($cat -eq 'Manual Install'){'B'}elseif($cat -eq 'Operating Systems'){'OS'}else{'A'}))
        $tierVal = if($v.PSObject.Properties['tier'] -and $null -ne $v.tier){[int]$v.tier}else{3}
        $prioVal = if($v.PSObject.Properties['priority'] -and $null -ne $v.priority){[int]$v.priority}else{999}
        $essFlag = if($v.PSObject.Properties['essential'] -and $null -ne $v.essential){[bool]$v.essential}else{$false}
        $essRank = if($v.PSObject.Properties['essential_rank'] -and $null -ne $v.essential_rank){[int]$v.essential_rank}else{999}
        $szMb    = if($v.PSObject.Properties['size_mb'] -and $null -ne $v.size_mb){[int]$v.size_mb}else{65}
        $etaMn   = if($v.PSObject.Properties['eta_min'] -and $null -ne $v.eta_min){[double]$v.eta_min}else{0.6}
        $kws     = if($v.PSObject.Properties['match_keywords'] -and $null -ne $v.match_keywords){@($v.match_keywords)}else{@()}
        $pub     = (Get-SLTOptionalText $v 'publisher' '')

        [pscustomobject]@{
            Key           = [string]$p.Name
            Name          = (Get-SLTOptionalText $v 'content' $p.Name)
            Category      = $cat
            Group         = $grp
            Tier          = $tierVal
            Priority      = $prioVal
            Essential     = $essFlag
            EssentialRank = $essRank
            SizeMb        = $szMb
            EtaMin        = $etaMn
            Winget        = (Get-SLTOptionalText $v 'winget' '')
            Choco         = (Get-SLTOptionalText $v 'choco' '')
            Url           = (Get-SLTOptionalText $v 'link' '')
            Description   = (Get-SLTOptionalText $v 'description' 'Verified official software publisher.')
            Note          = (Get-SLTOptionalText $v 'note' '')
            BtnLabel      = (Get-SLTOptionalText $v 'btn_label' 'Download')
            SltAction     = (Get-SLTOptionalText $v 'slt_action' '')
            Publisher     = $pub
            MatchKeywords = $kws
            OsGroup       = (Get-SLTOptionalText $v 'os_group' '')
            OsBadge       = (Get-SLTOptionalText $v 'os_badge' '')
            OsRam         = (Get-SLTOptionalText $v 'os_ram' '')
            OsSize        = (Get-SLTOptionalText $v 'os_size' '')
            OsBestFor     = (Get-SLTOptionalText $v 'os_best_for' '')
            OsWarning     = (Get-SLTOptionalText $v 'os_warning' '')
        }
    })

    $webOnly = @{}; $essential = @{}
    foreach($a in $records){
        if($a.Group -in @('B','OS') -or $a.Category -in @('Manual Install','Operating Systems','Official Web Tools')){
            $webOnly[$a.Key] = $true
        }
        if($a.Essential){ $essential[$a.Key] = $true }
    }
    $index = @{}; foreach($p in $records){ $index[$p.Key] = $p }

    $priority = @{}
    $featuredFile = Join-Path $RootPath 'config\install_featured.json'
    if(Test-Path -LiteralPath $featuredFile){
        try {
            $featured = Get-Content -LiteralPath $featuredFile -Raw | ConvertFrom-Json
            $rank = 0
            foreach($key in @($featured.featured)) {
                if(-not $priority.ContainsKey([string]$key)){
                    $priority[[string]$key] = $rank
                    $rank++
                }
            }
        } catch { Log-SLT ('Install priorities fallback: ' + $_.Exception.Message) }
    }

    [pscustomobject]@{
        AppRecords     = $records
        AppIndex       = $index
        WebOnlyKeys    = $webOnly
        EssentialKeys  = $essential
        InstallPriority= $priority
    }
}

# Separate DISM worker keeps UI responsive; read the worker log before capture.
function Start-SLTComponentCleanup {
 Need-SLTAdmin
 $worker=Join-Path $script:Root 'tools\Invoke-SLT-ComponentCleanup.ps1'
 if(-not (Test-Path -LiteralPath $worker)){throw 'DISM worker missing.'}
 Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -File "'+$worker+'"') -Verb RunAs
 Log-SLT 'DISM worker started. Wait for exit code 0 in worker window before Sysprep. No /ResetBase.'
}


function Save-SLTBRState {
    try {
        $stateFile = Join-Path $script:StateDir 'BackupRestoreState_v52.json'
        $doneList = @($script:BRCompletedStages.Keys | Where-Object { $script:BRCompletedStages[$_] })
        @{ completed = $doneList; updated = (Get-Date -Format 's') } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $stateFile -Encoding UTF8
    } catch {}
}

function Load-SLTBRState {
    try {
        $stateFile = Join-Path $script:StateDir 'BackupRestoreState_v52.json'
        if (Test-Path -LiteralPath $stateFile) {
            $obj = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            if ($obj -and $obj.completed) {
                foreach ($k in @($obj.completed)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$k)) {
                        $script:BRCompletedStages[[string]$k] = $true
                    }
                }
            }
        }
    } catch {}
}

function Remove-SLTSysprepSafeAppx([string[]]$Patterns) {
    # Appx removal affects installed apps and may affect every Windows user. Require an explicit confirmation.
    Need-SLTAdmin
    $patternSummary = (@($Patterns | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join "`n")
    $confirmText = "This operation can uninstall Store apps for the current user, all users, and the Windows image. Reinstallation may be required.`n`nTargets:`n$patternSummary`n`nContinue only if you have reviewed this list."
    $confirm = [Windows.MessageBox]::Show($confirmText,'Confirm Windows App Removal','YesNo','Warning')
    if ($confirm -ne 'Yes') { Log-SLT 'Appx removal cancelled by operator.'; return 0 }
    $removedCount = 0
    foreach ($procName in @('WinStore.App','StoreExperienceHost','Widgets','WidgetService','Clipchamp','Solitaire','Microsoft.Photos','HxTsr','HxOutlook','olk','Teams','ms-teams','msteams','Cortana','PhoneExperienceHost','YourPhone','WindowsMaps','ZuneVideo','ZuneMusic')) {
        try { Get-Process -Name ($procName + '*') -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    }
    foreach ($pat in $Patterns) {
        # 1. Remove for Current User first (do NOT skip IsFramework for explicit patterns like Winget.Source!)
        try {
            $curPkgs = @(Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue)
            foreach ($cp in $curPkgs) {
                if ($cp.NonRemovable -eq $true -or [string]$cp.SignatureKind -eq 'System') { continue }
                try {
                    Remove-AppxPackage -Package $cp.PackageFullName -ErrorAction SilentlyContinue
                    $removedCount++
                } catch {}
            }
        } catch {}
        # 2. Remove for AllUsers
        try {
            $allPkgs = @(Get-AppxPackage -AllUsers -Name $pat -ErrorAction SilentlyContinue)
            foreach ($ap in $allPkgs) {
                if ($ap.NonRemovable -eq $true -or [string]$ap.SignatureKind -eq 'System') { continue }
                try {
                    Remove-AppxPackage -Package $ap.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                    $removedCount++
                } catch {}
            }
        } catch {}
        # 3. Only remove Provisioned package if no CurrentUser instance remains (prevents 'installed for a user, but not provisioned'!)
        try {
            $stillUser = @(Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue)
            if ($stillUser.Count -eq 0) {
                $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pat })
                foreach ($pr in $prov) {
                    try {
                        Remove-AppxProvisionedPackage -Online -PackageName $pr.PackageName -ErrorAction SilentlyContinue | Out-Null
                    } catch {}
                }
            }
        } catch {}
    }
    Log-SLT ('Confirmed Appx cleanup finished (' + $removedCount + ' package instances removed across CurrentUser + AllUsers + Provisioned).')
}

function Repair-SLTSysprepEnvironment {
    # Complete Self-Healing Sysprep Preparation Engine for Windows 11 (Audit Mode, OOBE & Hyper-V VM):
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # 1. Blocks Store AutoDownload & Consumer Features so Store cannot stage apps behind the scenes.
    # 2. Leaves user processes and Windows Update services untouched.
    # 3. Inventories removable AppX packages without changing service states or deleting them.
    # 4. Inspects pending reboot/Sysprep state without clearing Windows servicing markers.
    # 5. Does not change BitLocker; suspension is handled only by the explicit Sysprep launch workflow.
    $fixedItems = 0
    try {
        Need-SLTAdmin
        # 1. Enforce Store & Consumer Feature blocks
        Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2
        Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'DisableOSUpgrade' 1
        Set-SLTSetting 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate' 'AutoDownload' 2
        Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
        Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
        Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 0
        Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled' 0
        Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled' 0
    } catch {}

    # 2. Do not terminate user apps or stop Windows Update services automatically.
    # An operator can close apps manually and retry Sysprep if Windows reports a package lock.
    try { if ($null -ne $script:AsyncScanTimer) { $script:AsyncScanTimer.Stop() } } catch {}
    Log-SLT 'Sysprep preparation: user processes and Windows Update services were left untouched.'

    # 3. Inventory removable AppX packages without changing service states or removing packages.
    try {
        $appxCount = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.NonRemovable -ne $true -and [string]$_.SignatureKind -ne 'System' }).Count
        Log-SLT ("Sysprep preparation: detected $appxCount removable AppX package instance(s); none were removed automatically. Use the separate confirmed app-removal action only after reviewing the list.")
    } catch { Log-SLT ('AppX inventory unavailable: ' + $_.Exception.Message) }

    # 6. Inspect Sysprep and pending-reboot state only. Do not erase Windows servicing markers
    # or force registry values; Windows Setup/servicing owns these state transitions.
    try {
        $pendingPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        )
        $pendingFound = @($pendingPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0
        $sessMgrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        $sessMgrState = Get-ItemProperty -Path $sessMgrPath -ErrorAction SilentlyContinue
        $pendingRename = $null -ne $sessMgrState -and $null -ne $sessMgrState.PSObject.Properties['PendingFileRenameOperations']
        if ($pendingFound -or $pendingRename) {
            Log-SLT 'Pending reboot/rename state detected. No servicing markers were deleted. Reboot Windows and rerun Sysprep preparation.'
        } else {
            Log-SLT 'No common pending reboot markers detected. Sysprep registry state was left unchanged.'
        }
        $sysprepState = Get-ItemProperty -Path 'HKLM:\SYSTEM\Setup\Status\SysprepStatus' -ErrorAction SilentlyContinue
        if ($sysprepState) { Log-SLT ("Sysprep status observed: GeneralizationState=$($sysprepState.GeneralizationState), CleanupState=$($sysprepState.CleanupState). No values were forced.") }
    } catch { Log-SLT ('Sysprep state inspection unavailable: ' + $_.Exception.Message) }

    # BitLocker is deliberately untouched by this general audit helper.
    $ErrorActionPreference = $oldEap

    Log-SLT ("Repair-SLTSysprepEnvironment completed: " + $fixedItems + " packages removed automatically (none); AppX inventory, pending reboot, and Sysprep state inspected.")
    return $fixedItems
}
Set-Item -Path Function:\global:Repair-SLTSysprepEnvironment -Value ${function:Repair-SLTSysprepEnvironment}

function Suspend-SLTBitLockerForSysprep {
    Need-SLTAdmin
    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) -or -not (Get-Command Suspend-BitLocker -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ Success=$false; Suspended=$false; Message='BitLocker cmdlets are unavailable; encryption state could not be verified. Sysprep was not launched.' }
    }
    try {
        $volume = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        if ($null -eq $volume) {
            return [pscustomobject]@{ Success=$false; Suspended=$false; Message='C: BitLocker status could not be read. Sysprep was not launched.' }
        }
        $volumeStatus = [string]$volume.VolumeStatus
        $protection = [string]$volume.ProtectionStatus
        $percentRaw = $volume.EncryptionPercentage
        if ($null -eq $percentRaw -or [string]::IsNullOrWhiteSpace([string]$percentRaw)) {
            return [pscustomobject]@{ Success=$false; Suspended=$false; Message='C: encryption percentage was not reported. Sysprep was not launched.' }
        }
        $percent = [int]$percentRaw
        if ($volumeStatus -eq 'FullyDecrypted' -and $percent -eq 0) {
            return [pscustomobject]@{ Success=$true; Suspended=$false; Message='C: is verified as fully decrypted; no BitLocker change was required.' }
        }
        if ($percent -eq 0 -and $volumeStatus -ne 'FullyDecrypted') {
            return [pscustomobject]@{ Success=$false; Suspended=$false; Message=("C: reported an inconsistent BitLocker state ($volumeStatus, $percent%). Sysprep was not launched.") }
        }
        if ($protection -eq 'Off') {
            return [pscustomobject]@{ Success=$true; Suspended=$false; Message='C: is encrypted and BitLocker protection is already suspended/off.' }
        }
        if ($protection -ne 'On') {
            return [pscustomobject]@{ Success=$false; Suspended=$false; Message=("Unrecognized BitLocker protection state: $protection. Sysprep was not launched.") }
        }
        Suspend-BitLocker -MountPoint 'C:' -RebootCount 2 -ErrorAction Stop | Out-Null
        $verify = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        if ([string]$verify.ProtectionStatus -eq 'Off' -and [int]$verify.EncryptionPercentage -gt 0) {
            Log-SLT ("BitLocker protection suspended for two reboots; C: remains encrypted ($($verify.EncryptionPercentage)%).")
            return [pscustomobject]@{ Success=$true; Suspended=$true; Message=("BitLocker protection suspended for two reboots. C: remains encrypted ($($verify.EncryptionPercentage)%).") }
        }
        return [pscustomobject]@{ Success=$false; Suspended=$false; Message='BitLocker suspension could not be verified. C: was not decrypted; Sysprep was not launched.' }
    } catch {
        Log-SLT ('BitLocker pre-Sysprep check failed: ' + $_.Exception.Message)
        return [pscustomobject]@{ Success=$false; Suspended=$false; Message=('BitLocker status/suspension failed: ' + $_.Exception.Message + '. C: was not decrypted; Sysprep was not launched.') }
    }
}
Set-Item -Path Function:\global:Suspend-SLTBitLockerForSysprep -Value ${function:Suspend-SLTBitLockerForSysprep}

# Default User NTUSER.DAT mutation helper removed in Phase 1: no automatic profile hive changes.

function Invoke-SLTSingleOptimizationItem([string]$ItemId, [string]$Tier='SMART') {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $detail = 'Applied'
    try {
        switch ($ItemId) {
            's1' {
                try { Remove-SLTTrackedRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'com.squirrel.Teams.Teams' } catch {}
                try { Remove-SLTTrackedRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'Teams' } catch {}
                $detail = 'Disabled Teams auto-start in HKCU Run'
            }
            's2' {
                try { Remove-SLTTrackedRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive' } catch {}
                $detail = 'Disabled OneDrive auto-start in HKCU Run'
            }
            's3' {
                try { Remove-SLTTrackedRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'Spotify' } catch {}
                $detail = 'Disabled Spotify auto-start in HKCU Run'
            }
            's4' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableMmx' 0 } catch {}
                $detail = 'Disabled Phone Link (EnableMmx = 0)'
            }
            's5' {
                try { Invoke-SLTCleanup } catch {}
                $detail = 'Cleared %TEMP% user cache files'
            }
            's6' {
                try { Invoke-SLTCleanup } catch {}
                $detail = 'Cleared Windows\Temp system cache files'
            }
            's7' {
                # Preserve Prefetch: Windows maintains it to optimize application startup.
                $detail = 'Skipped for safety: Windows Prefetch cache is preserved.'
            }
            's8' {
                # Preserve Windows Update download cache to avoid disrupting servicing/update state.
                $detail = 'Skipped for safety: Windows Update download cache is preserved.'
            }
            's9' {
                $confirmRecycle = [Windows.MessageBox]::Show('This permanently removes items currently in the Recycle Bin. Continue only if you have reviewed it.','Confirm Empty Recycle Bin','YesNo','Warning')
                if ($confirmRecycle -eq 'Yes') {
                    try { Clear-RecycleBin -Force -ErrorAction Stop; $detail = 'Recycle Bin emptied after operator confirmation' } catch { $detail = ('Recycle Bin cleanup failed: ' + $_.Exception.Message) }
                } else { $detail = 'Skipped: operator cancelled Recycle Bin cleanup' }
            }
            's10' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 } catch {}
                $detail = 'Applied reversible telemetry policy; DiagTrack service state left unchanged'
            }
            's11' {
                $detail = 'Skipped: service startup changes are disabled until a verified service rollback feature is available'
            }
            's12' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1 } catch {}
                $detail = 'Disabled background Location Tracking'
            }
            's13' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1 } catch {}
                $detail = 'Disabled Advertising ID & tailored ads'
            }
            's14' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
                } catch {}
                $detail = 'Disabled Activity History & cloud timeline sync'
            }
            's15' {
                try {
                    Set-SLTSetting 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
                } catch {}
                $detail = 'Blocked Feedback Hub nag prompts'
            }
            's16' {
                try { Remove-SLTSysprepSafeAppx @('*CandyCrush*','*BubbleWitch*','*MarchofEmpires*','*Disney*','*SpotifyAB*','*Clipchamp*') } catch {}
                $detail = 'Removed consumer games & Clipchamp (Sysprep-safe)'
            }
            's17' {
                try {
                    Set-SLTSetting 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
                } catch {}
                $detail = 'Disabled background Xbox GameDVR recording'
            }
            's18' {
                try { Remove-SLTSysprepSafeAppx @('*MixedReality.Portal*','*Microsoft3DViewer*') } catch {}
                $detail = 'Removed Mixed Reality & 3D Viewer (Sysprep-safe)'
            }
            's19' {
                try { Remove-SLTSysprepSafeAppx @('*MicrosoftSolitaireCollection*') } catch {}
                $detail = 'Removed Solitaire casual bloatware (Sysprep-safe)'
            }
            's20' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
                    Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
                } catch {}
                $detail = 'Blocked background Store app drain & consumer features'
            }
            's21' {
                try {
                    Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
                    Set-SLTStringSetting 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2'
                    Set-SLTSetting 'HKCU:\Control Panel\Desktop' 'FontSmoothingType' 2
                    Set-SLTStringSetting 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '1'
                } catch {}
                $detail = 'Set Best Performance visual mode while keeping ClearType smooth fonts'
            }
            's22' {
                try {
                    Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
                    Set-SLTStringSetting 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0'
                } catch {}
                $detail = 'Disabled window minimize/maximize & taskbar animations'
            }
            's23' {
                try { Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 0 } catch {}
                $detail = 'Disabled desktop & listview drop shadows'
            }
            's24' {
                try { Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 } catch {}
                $detail = 'Disabled Acrylic / Mica transparency blur overhead'
            }
            's25' {
                $detail = 'Skipped: power-plan changes are disabled until the original active plan can be restored'
            }
            's26' {
                $detail = 'Skipped: USB selective-suspend changes are disabled until power-setting rollback is implemented'
            }
            's27' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' 'SubmitSamplesConsent' 2 } catch {}
                $detail = 'Set Defender sample submission to safe minimal mode'
            }
            'u1' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 } catch {}
                $detail = 'Disabled Taskbar Widgets & News feed using a rollback-tracked policy'
            }
            'u2' {
                try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' 'ChatIcon' 3 } catch {}
                $detail = 'Disabled Taskbar Chat / Meet Now icon'
            }
            'u3' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
                    Set-SLTSetting 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
                } catch {}
                $detail = 'Disabled Windows Copilot auto-start'
            }
            'u4' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
                } catch {}
                $detail = 'Disabled Microsoft Edge Startup Boost & background processes'
            }
            'u5' {
                $detail = 'Skipped: SysMain service changes are disabled until service-state backup/restore is implemented'
            }
            'u6' {
                $detail = 'Skipped: Print Spooler startup type is left unchanged for compatibility'
            }
            'u7' {
                $detail = 'Skipped: Fax service changes are disabled until service-state backup/restore is implemented'
            }
            'u8' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0
                    Set-SLTSetting 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
                } catch {}
                $detail = 'Disabled Start Menu Bing web search suggestions'
            }
            'u9' {
                $detail = 'Skipped: scheduled-task changes are disabled until original task state can be restored'
            }
            'u10' {
                $detail = 'Skipped: scheduled-task changes are disabled until original task state can be restored'
            }
            'u11' {
                $detail = 'Skipped: scheduled-task changes are disabled until original task state can be restored'
            }
            'u12' {
                $detail = 'Skipped: Shadow Copy status inspection is not implemented in this optimization action'
            }
            'u13' {
                $detail = 'Skipped: hibernation changes require a verified restore workflow'
            }
            'u14' {
                $detail = 'Skipped: Pagefile status inspection is not implemented in this optimization action'
            }
            'u15' {
                try { Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' 'WpadOverride' 1 } catch {}
                $detail = 'Disabled WPAD auto-proxy lookup delay'
            }
            'e1' {
                $confirmOneDrive = [Windows.MessageBox]::Show('This policy disables OneDrive sync on this PC. Files already stored locally are not deleted, but changes will stop syncing until the setting is restored. Continue?','Confirm OneDrive Sync Change','YesNo','Warning')
                if ($confirmOneDrive -eq 'Yes') {
                    try { Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1; $detail = 'Disabled OneDrive sync using a rollback-tracked policy' } catch { $detail = ('OneDrive policy failed: ' + $_.Exception.Message) }
                } else { $detail = 'Skipped: operator cancelled OneDrive sync change' }
            }
            'e2' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
                    Remove-SLTSysprepSafeAppx @('*Microsoft.549981C3F5F10*')
                } catch {}
                $detail = 'Removed Cortana app & disabled background voice agent'
            }
            'e3' {
                try {
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'AllowPrelaunch' 0
                    Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'AllowTabPreloading' 0
                } catch {}
                $detail = 'Disabled Edge Prelaunch & New Tab preloading'
            }
            'e4' {
                try { Remove-SLTSysprepSafeAppx @('*WindowsMaps*','*People*','*BingNews*','*BingWeather*','*GetHelp*','*GetStarted*','*PowerAutomate*','*Todos*') } catch {}
                $detail = 'Removed Maps, People, News, Weather & Todo apps (Sysprep-safe)'
            }
            'e5' {
                try {
                    Set-SLTSetting 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' 67108864
                    Set-SLTStringSetting 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0'
                } catch {}
                $detail = 'Applied reversible SvcHost and UI menu-delay settings; service shutdown timeout and memory compression were left unchanged'
            }
            'e6' {
                $detail = 'Skipped: pagefile changes are disabled until automatic/custom pagefile settings can be backed up and restored'
            }
            'e7' {
                try { Set-SLTSetting 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0 } catch {}
                $detail = 'Disabled background speech telemetry'
            }
            'e8' {
                $detail = 'Skipped: Defender scan-load settings are disabled until the original value can be backed up and restored'
            }
            'c1' {
                $confirmDism = [Windows.MessageBox]::Show('DISM component cleanup removes superseded Windows component versions and can reduce the ability to roll back some updates. Run this only after a verified backup. Continue?','Confirm DISM Component Cleanup','YesNo','Warning')
                if ($confirmDism -eq 'Yes') {
                    try { Start-Process -FilePath 'dism.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup' -WindowStyle Hidden -ErrorAction Stop; $detail = 'Started DISM component cleanup after confirmation' } catch { $detail = ('DISM cleanup failed to start: ' + $_.Exception.Message) }
                } else { $detail = 'Skipped: operator cancelled DISM component cleanup' }
            }
            'c2' {
                $confirmCompact = [Windows.MessageBox]::Show('CompactOS compresses Windows system binaries. It can save disk space but may affect performance. Continue?','Confirm CompactOS Compression','YesNo','Warning')
                if ($confirmCompact -eq 'Yes') {
                    try { Start-Process -FilePath 'compact.exe' -ArgumentList '/compactos:always' -WindowStyle Hidden -ErrorAction Stop; $detail = 'Started CompactOS compression after confirmation' } catch { $detail = ('CompactOS failed to start: ' + $_.Exception.Message) }
                } else { $detail = 'Skipped: operator cancelled CompactOS compression' }
            }
            'c3' {
                $detail = 'Skipped: no separate WinSxS cleanup action is implemented; use the confirmed DISM component cleanup option'
            }
            'c4' {
                $script:BRLzxCompression = $true
                $detail = 'Enabled LZX Maximum Compression flag for Stage 09 WIM capture'
            }
            'c5' {
                try { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue } catch {}
                $detail = 'Purged Delivery Optimization cache'
            }
            'c6' {
                $detail = 'Skipped for safety: Windows Update download cache is preserved'
            }
            'c7' {
                try {
                    $expCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
                    if (Test-Path -LiteralPath $expCache) {
                        Get-ChildItem -LiteralPath $expCache -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    }
                } catch {}
                $detail = 'Cleaned Explorer thumbnail caches'
            }
            'sysprep_heal' {
                $detail = 'Skipped: Sysprep readiness is available only in the dedicated Backup & Restore workflow'
            }
            'default_hive' {
                $detail = 'Skipped: Default User profile is never modified automatically'
            }
        }
    } catch {} finally {
        $ErrorActionPreference = $oldEap
    }
    return $detail
}
Set-Item -Path Function:\global:Invoke-SLTSingleOptimizationItem -Value ${function:Invoke-SLTSingleOptimizationItem}

function Invoke-SLTOptimizationHub([string]$Tier, [hashtable]$Checks, [scriptblock]$StatusCallback = $null) {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $applied = 0
    try {
        $smartIds = @('s1','s2','s3','s4','s5','s6','s7','s8','s9','s10','s11','s12','s13','s14','s15','s16','s17','s18','s19','s20','s21','s22','s23','s24','s25','s26','s27')
        $ultraIds = @('u1','u2','u3','u4','u5','u6','u7','u8','u9','u10','u11','u12','u13','u14','u15')
        $extIds   = @('e1','e2','e3','e4','e5','e6','e7','e8')
        $compIds  = @('c1','c2','c3','c4','c5','c6','c7')

        $runIds = if ($Tier -eq 'SMART') {
            $smartIds
        } elseif ($Tier -eq 'ULTRA') {
            $smartIds + $ultraIds
        } elseif ($Tier -eq 'EXTREME') {
            $smartIds + $ultraIds + $extIds
        } else {
            $compIds
        }

        foreach ($id in $runIds) {
            if ($Checks[$id]) {
                $msg = Invoke-SLTSingleOptimizationItem -ItemId $id -Tier $Tier
                $applied++
                if ($null -ne $StatusCallback) {
                    try { & $StatusCallback $id $msg } catch {}
                }
            }
        }
        Log-SLT ('Optimization Hub [' + $Tier + '] completed (' + $applied + ' selected actions applied/processed; skipped actions are reported individually). Sysprep and Default User profile were not modified.')
    } catch {} finally {
        $ErrorActionPreference = $oldEap
    }
    return $applied
}
Set-Item -Path Function:\global:Invoke-SLTOptimizationHub -Value ${function:Invoke-SLTOptimizationHub}

Set-Item -Path Function:\global:Start-SLTQueue -Value ${function:Start-SLTQueue}
Set-Item -Path Function:\global:Show-SLTInstallMonitor -Value ${function:Show-SLTInstallMonitor}
