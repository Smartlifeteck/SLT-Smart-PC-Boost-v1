# =====================================================================
# PAGE 5 (Index 4): BACKUP & RESTORE FACTORY (One Window, No Scroll, 4-Theme Unified Engine)
# Powered by Smart Life Teck (www.smartlifeteck.com) | Developed by Shahzad Babar
# =====================================================================
$page = New-SLTPage 4
$script:BROptAppliedItems = @{}
$script:BROptSelectedCountLbl = $null
$script:BROptStepIdx = 0
$script:BROptAppliedCnt = 0
$script:BROptAdvanceNext = $false

# Keep Hub & OEM Driver Helpers for cross-page compatibility
function Start-SLTCollection([ValidateSet('AI','Social','Websites')][string]$Name,[switch]$Silent){
 $worker=Join-Path $script:Root 'tools\Build-SLT-Collections.ps1'
 if (-not (Test-Path -LiteralPath $worker)) { if (Get-Command Log-SLT -ErrorAction SilentlyContinue) { Log-SLT ('Optional worker not present: ' + $worker) 'WARN' }; return }
 $stamp=Get-Date -Format 'yyyyMMdd_HHmmss_fff'
 $report=Join-Path $script:StateDir ('Hub_'+$Name+'_'+$stamp+'.json')
 $stdout=Join-Path $script:LogDir ('Hub_'+$Name+'_'+$stamp+'_stdout.txt')
 $stderr=Join-Path $script:LogDir ('Hub_'+$Name+'_'+$stamp+'_stderr.txt')
 $args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$worker+'" -Mode '+$Name+' -Report "'+$report+'"'
 try {
    if(-not (Test-Path -LiteralPath $worker)){throw ('Missing hub worker: '+$worker)}
    Log-SLT ('Creating SLT '+$Name+' Hub ...')
    $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr -ErrorAction Stop
    if(-not $proc.WaitForExit(60000)){
        try{$proc.Kill()}catch{}
        throw 'Hub creation exceeded 60 seconds and was stopped.'
    }
    if(-not(Test-Path -LiteralPath $report)){ 
        $detail=''
        if(Test-Path -LiteralPath $stderr){$detail=((Get-Content -LiteralPath $stderr -Tail 10 -ErrorAction SilentlyContinue) -join ' ')}
        $proc.Refresh()
        throw ('Hub worker did not create a completion receipt (exit code: '+[string]$proc.ExitCode+'). '+$detail)
    }
    $receipt=Get-Content -LiteralPath $report -Raw -ErrorAction Stop|ConvertFrom-Json
    if([string]$receipt.status -ne 'Success'){throw 'Hub completion receipt reports failure.'}
    $shortcut=[string]$receipt.shortcut;$dashboard=[string]$receipt.dashboard
    if([string]::IsNullOrWhiteSpace($shortcut) -or [string]::IsNullOrWhiteSpace($dashboard)){
       throw 'Hub completion receipt is missing file paths.'
    }
    if(-not(Test-Path -LiteralPath $shortcut -PathType Leaf) -or -not(Test-Path -LiteralPath $dashboard -PathType Leaf)){
       throw 'Hub shortcut or dashboard missing after creation.'
    }
    $isAlready=($receipt.PSObject.Properties['already'] -and [bool]$receipt.already)
    $hubLabel=if($receipt.PSObject.Properties['hubName'] -and -not [string]::IsNullOrWhiteSpace([string]$receipt.hubName)){[string]$receipt.hubName}else{('SLT '+$Name+' Hub')}
    if($isAlready){
       $message=('Already Installed! {0} ({1} tools) is already installed and ready on your Desktop.' -f $hubLabel,$receipt.count)
       $boxTitle='SLT Smart PC Boost | Already Installed'
    } else {
       $message=('Congratulations! Tools Installed Successfully - {0} ({1} tools) is ready on your Desktop.' -f $hubLabel,$receipt.count)
       $boxTitle='SLT Smart PC Boost | Congratulations - Tools Installed Successfully'
    }
    Log-SLT ($message+' | Powered by Smart Life Teck | Developed by Shahzad Babar | Desktop shortcut: '+$shortcut)
    if(-not $Silent){
       [Windows.MessageBox]::Show(($message+[Environment]::NewLine+[Environment]::NewLine+'Powered by Smart Life Teck  |  Developed by Shahzad Babar'+[Environment]::NewLine+'POWERED BY SMART LIFE TECK  |  DEVELOPED BY SHAHZAD BABAR'),$boxTitle,'OK','Information')|Out-Null
    }
    return [pscustomobject]@{Name=$hubLabel;Mode=$Name;Status=$(if($isAlready){'ALREADY INSTALLED'}else{'INSTALLED'});Count=$receipt.count;Shortcut=$shortcut}
 } catch {
    $errorText=$_.Exception.Message
    try{Log-SLT ('Hub '+$Name+' failed: '+$errorText+' | Worker log: '+$stderr)}catch{}
    if(-not $Silent){
       [Windows.MessageBox]::Show(('SLT '+$Name+' Hub could not be created. The main app remains open.'+[Environment]::NewLine+$errorText+[Environment]::NewLine+'Log: '+$stderr),'SLT Smart PC Boost | Hub Error','OK','Warning')|Out-Null
    }
    return [pscustomobject]@{Name=('SLT '+$Name+' Hub');Mode=$Name;Status='FAILED';Count=0;Error=$errorText}
 }
}

function Invoke-SLTOEMTool {
    Need-SLTAdmin
    $hw=Get-SLTHardware;$tool=$null;$arguments=@()
    if($hw.Maker -match 'Dell') {
       $candidates=@("$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe", "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe")
       foreach($p in $candidates){if(Test-Path -LiteralPath $p){$tool=$p;break}}
       $arguments=@('/applyUpdates','-updateType=driver','-silent','-reboot=disable')
    } elseif($hw.Maker -match 'HP|Hewlett') {
       $candidates=@("$env:ProgramFiles\HP\HPIA\HPImageAssistant.exe", "${env:ProgramFiles(x86)}\HP\HPIA\HPImageAssistant.exe")
       foreach($p in $candidates){if(Test-Path -LiteralPath $p){$tool=$p;break}}
       $arguments=@('/Operation:Analyze','/Category:Drivers','/Selection:Recommended','/Action:Install','/Silent')
    }
    if($tool) {
       Start-Process -FilePath $tool -ArgumentList $arguments -PassThru | Out-Null
       Log-SLT "Official OEM driver-only updater launched for $($hw.Maker); verify log and reboot."
    } else {
       Log-SLT "No preinstalled supported OEM CLI for $($hw.Maker) $($hw.Model); opening official support."
       Open-SLTLink (Get-SLTOEMURL $hw.Maker)
    }
}

# =====================================================================
# STAGE DEFINITIONS: BACKUP (00-09), RESTORE (01-07), OPTIMIZATION HUB (4 TABS)
# =====================================================================
$script:BRStoreGuardCode = @"
# Reversible Store Auto-Download policy guard; preserve WinGet Source
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /v AutoDownload /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f
# Windows Update and Store services are left running; no service startup state is changed.
# Preserve Microsoft.WinGet.Source. If Sysprep reports a specific package conflict,
# review and remove that exact package manually after backing up the image.
Write-Host 'WinGet Source preserved. No Appx packages were removed automatically.'
# Leave Windows Update and Store service states unchanged.
"@

$script:BRBackupStages = @(
    @{ id='b00'; no='00'; title='Windows 11 Download'; badge='OFFICIAL'; critical=$false;
       instruction='Download genuine Windows 11 ISO only from Microsoft official site - Use for clean Audit Mode Master (Ctrl+Shift+F3 at OOBE).';
       items=@() },
    @{ id='b01'; no='01'; title='Store OFF (Before Internet)'; badge='CRITICAL'; critical=$true;
       instruction='Paste this in Terminal as Administrator (or click Apply Store OFF Directly). This is necessary for Sysprep. It blocks Microsoft Store auto-updates before connecting internet to prevent bloat restoration.';
       items=@() },
    @{ id='b02'; no='02'; title='Windows Update'; badge=''; critical=$false;
       instruction='Install all Windows updates and runtimes before optimization to make the Master image stable.';
       items=@(
           @{ id='wu1'; label='Windows Update Full (Open Settings)'; group='Core Updates'; tip='Opens Windows Update so you can install cumulative patches.' },
           @{ id='wu2'; label='Driver Updates via Windows Update'; group='Core Updates'; tip='Opens Optional Driver Updates in Windows Settings.' },
           @{ id='wu3'; label='Cumulative Security Patch Check'; group='Core Updates'; tip='Verifies latest Windows build and security patch level.' },
           @{ id='wu4'; label='.NET Framework 3.5 & 4.8 Check'; group='Runtimes'; tip='Verifies .NET Framework runtime readiness.' },
           @{ id='wu5'; label='Visual C++ Redistributables 2015-2022'; group='Runtimes'; tip='Ensures VC++ runtime libraries are ready for apps.' }
       ) },
    @{ id='b03'; no='03'; title='Driver Strategy Generic/Brand'; badge=''; critical=$false;
       instruction='Choose driver mode: Generic for multi-model resale (Hyper-V / universal), or Brand for dedicated identical laptop units.';
       items=@(
           @{ id='dr1'; label='Generic Drivers (Multi-Model Resale - Universal)'; group='Driver Mode'; tip='Sets PersistAllDeviceInstalls=false so image boots on any brand.' },
           @{ id='dr2'; label='Brand Specific Dell / HP / Lenovo Auto'; group='Driver Mode'; tip='Keeps tested drivers for identical laptop model batches.' },
           @{ id='dr3'; label='Keep Essential Chipset + GPU + WLAN Only'; group='Filter & Clean'; tip='Preserves core connectivity and graphics drivers.' },
           @{ id='dr4'; label='Remove OEM Bloatware (McAfee / Norton / Trial)'; group='Filter & Clean'; tip='Removes third-party trial antivirus and OEM nagware.' },
           @{ id='dr5'; label='Prepare Driver Pack Folder C:\Drivers'; group='Setup'; tip='Creates C:\Drivers staging directory for driver injection.' }
       ) },
    @{ id='b04'; no='04'; title='SLT Bundle (PC Tools)'; badge='SLT'; critical=$false;
       instruction='Install SLT PC Tools and customer desktop shortcuts before Audit optimization (internal QC tools are kept separate).';
       items=@(
           @{ id='slt1'; label='Open SLT PC Tools Catalog (Chrome, VLC, 7-Zip, PDF)'; group='Core Bundle'; tip='Opens SLT Smart Installation filtered to SLT PC Tools.' },
           @{ id='slt2'; label='Apply SLT Clean Desktop & Taskbar Preset'; group='Core Bundle'; tip='Configures clean taskbar and desktop icon layout.' },
           @{ id='slt3'; label='Create SLT AI, Social & Productivity Desktop Hubs'; group='Customer Hubs'; tip='Installs the 3 branded Smart Life Teck web hubs on Desktop.' },
           @{ id='slt4'; label='Create SLT Smart PC Boost Desktop Logo Shortcut'; group='Customer Hubs'; tip='Places the official Smart Life Teck logo shortcut on Desktop.' },
           @{ id='slt5'; label='Pre-configure Remote Support (AnyDesk Ready)'; group='Support Tools'; tip='Prepares online support shortcut for 6-month service warranty.' }
       ) },
    @{ id='b05'; no='05'; title='OPTIMIZATION HUB'; badge='4 TABS'; critical=$false;
       instruction='High-options Optimization & Debloating Hub - Switch between SMART, ULTRA, EXTREME (4GB Low-End), and COMPACT in this same window.';
       items=@() },
    @{ id='b06'; no='06'; title='Audit Safety Check'; badge=''; critical=$false;
       instruction='Validate that the system is 100% safe for Sysprep generalization (checks Pending Reboot, Store Guard, Appx Provisioned state, and Disk Space).';
       items=@(
           @{ id='au1'; label='Run Sysprep Audit & Pending Reboot Validate'; group='Safety Checks'; tip='Verifies no pending Windows Update or CBS reboot blocks Sysprep.' },
           @{ id='au2'; label='Check Core Services State (wuauserv / AppXSvc)'; group='Safety Checks'; tip='Ensures required system services are in a healthy state.' },
           @{ id='au3'; label='Verify Free Disk Space (>15 GB Required)'; group='Safety Checks'; tip='Checks C: drive free space before image capture.' },
           @{ id='au4'; label='Remove Temp Profiles & Old Panther Logs'; group='Pre-Sysprep Clean'; tip='Cleans old Sysprep logs and temporary files.' },
           @{ id='au5'; label='Clear Windows Event Logs & Export Preflight JSON'; group='Pre-Sysprep Clean'; tip='Saves preflight verification report to Logs folder.' }
       ) },
    @{ id='b07'; no='07'; title='Answer File Generic/Brand'; badge=''; critical=$false;
       instruction='Prepare Unattend.xml for automated OOBE (skips EULA & Microsoft Account requirement, creates local Administrator account).';
       items=@(
           @{ id='af1'; label='Generic Answer File (All Brands - PersistDrivers=false)'; group='Answer File Mode'; tip='Unattend.xml contains the temporary account password in readable form. Use a unique password of at least 12 characters, keep the file private, and delete it after deployment.' },
           @{ id='af2'; label='Brand Specific Unattend (Same Model - PersistDrivers=true)'; group='Answer File Mode'; tip='Retains hardware drivers for identical laptop models.' },
           @{ id='af3'; label='OOBE Skip + Create Local Admin Account'; group='OOBE Automation'; tip='Skips online account requirement and creates local admin.' },
           @{ id='af4'; label='EULA Auto Accept & Telemetry Minimal'; group='OOBE Automation'; tip='Automatically accepts license agreement during OOBE.' },
           @{ id='af5'; label='Copy Unattend.xml to C:\Windows\Panther'; group='Deploy XML'; tip='Copies validated Unattend.xml to Panther for Sysprep.' }
       ) },
    @{ id='b08'; no='08'; title='Generalise & Shutdown'; badge='SYSPREP'; critical=$false;
       instruction='Critical: review pending reboot/Appx state, verify BitLocker status, then run Sysprep. No Store packages or servicing markers are deleted automatically.';
       items=@(
           @{ id='gs1'; label='Sysprep /Generalize /OOBE /Shutdown (Clean Master)'; group='Sysprep Core'; tip='Launches Windows Sysprep /generalize /oobe /shutdown.' },
           @{ id='gs2'; label='Review Appx Inventory & Sysprep State (No Auto Removal)'; group='Validation'; tip='Inventories removable Appx packages and pending reboot/Sysprep state. Does not uninstall apps or modify Sysprep registry markers.' },
           @{ id='gs3'; label='Remove Setup History & Temp Caches'; group='Clean'; tip='Cleans old Panther logs and temporary setup caches prior to shutdown.' },
           @{ id='gs4'; label='Shutdown After Sysprep (Required if SLT Suspends BitLocker)'; group='Sysprep Core'; tip='If SLT suspends BitLocker for this run, shutdown must remain selected. /quit is blocked in that case so protection is not left suspended on a running desktop.' },
           @{ id='gs5'; label='Include Unattend.xml Answer File (Only if Stage 07 Used)'; group='Validation'; tip='Check ONLY if you generated an Unattend.xml in Stage 07. Leave unchecked for clean standard OOBE without Unattend.' }
       ) },
    @{ id='b09'; no='09'; title='Take Backup LZX'; badge='FINAL'; critical=$false;
       instruction='Capture Gold Master WIM with LZX maximum compression (run from WinPE / Rescue USB after Stage 08 shutdown, or copy command below).';
       items=@(
           @{ id='bk1'; label='DISM Capture with LZX Maximum Compression'; group='Capture Engine'; tip='Uses /Compress:maximum (LZX) for smallest WIM size.' },
           @{ id='bk2'; label='Save Master Image to Target WIM Path'; group='Target Path'; tip='Writes WIM to external NVMe/USB drive (e.g. D:\SLT_Backup.wim).' },
           @{ id='bk3'; label='Verify WIM Image Integrity (/CheckIntegrity)'; group='Verification'; tip='Enables WIM integrity verification during capture.' },
           @{ id='bk4'; label='Export Image Size & SHA256 Checksum Log'; group='Verification'; tip='Logs WIM file size and SHA256 hash after capture.' },
           @{ id='bk5'; label='Copy Ready WinPE DISM Capture Script to USB'; group='Capture Engine'; tip='Saves CAPTURE_SLT_MASTER.cmd onto target drive for WinPE.' }
       ) }
)

$script:BRRestoreStages = @(
    @{ id='r01'; no='01'; title='Select & Apply WIM'; badge=''; critical=$false;
       instruction='Select Master WIM image and apply to target laptop disk partition (from WinPE or recovery environment).';
       items=@(
           @{ id='rw1'; label='Select Master WIM (D:\SLT_Backup.wim)'; group='Source & Disk'; tip='Verifies source WIM file path.' },
           @{ id='rw2'; label='Choose Partition Layout GPT (UEFI Standard)'; group='Source & Disk'; tip='Prepares UEFI GPT partition layout guidance.' },
           @{ id='rw3'; label='Apply via DISM /Apply-Image /Index:1'; group='Apply & Boot'; tip='Generates/runs DISM Apply-Image command.' },
           @{ id='rw4'; label='Fix UEFI Boot (bcdboot C:\Windows /f UEFI)'; group='Apply & Boot'; tip='Rebuilds UEFI BCD boot records.' },
           @{ id='rw5'; label='Verify Apply 100% Success & Export Script'; group='Verification'; tip='Saves APPLY_SLT_MASTER.cmd helper script.' }
       ) },
    @{ id='r02'; no='02'; title='Re-Enable Store & Update'; badge=''; critical=$false;
       instruction='Re-enable Microsoft Store and Windows Update services that were blocked during Audit Mode Master creation.';
       items=@(
           @{ id='re1'; label='Enable Microsoft Store AutoDownload (Remove Audit Block)'; group='Microsoft Store'; tip='Removes AutoDownload=2 policy so customer Store works normally.' },
           @{ id='re2'; label='Sync Microsoft Store App Licenses'; group='Microsoft Store'; tip='Restores normal Store update behavior.' },
           @{ id='re3'; label='Start Windows Update Service (wuauserv)'; group='Windows Update'; tip='Starts wuauserv service immediately.' },
           @{ id='re4'; label='Set wuauserv Startup Type Automatic'; group='Windows Update'; tip='Ensures Windows Update service starts automatically.' },
           @{ id='re5'; label='Open Windows Update to Check Critical Patches'; group='Windows Update'; tip='Opens Windows Update settings page.' }
       ) },
    @{ id='r03'; no='03'; title='Driver Update - Official Auto Detect'; badge='AUTO'; critical=$false;
       instruction='Fastest official method - Automatically detects laptop manufacturer & model via WMI and opens official driver support or OEM updater.';
       items=@() },
    @{ id='r04'; no='04'; title='Post-Restore Optimization'; badge=''; critical=$false;
       instruction='Restore essential customer services, verify display & power plan, and clean post-imaging temporary files.';
       items=@(
           @{ id='po1'; label='Verify Essential Customer Services Running'; group='System Services'; tip='Ensures Audio, WLAN, Bluetooth, and Store services are running.' },
           @{ id='po2'; label='Update Display Resolution & Smooth ClearType Fonts'; group='Display & Power'; tip='Ensures sharp font smoothing and display scaling.' },
           @{ id='po3'; label='Power Plan Switching (Unavailable)'; group='Display & Power'; tip='Disabled until the original active power plan can be backed up and restored.' },
           @{ id='po4'; label='Clear Post-Apply Temp & Panther Setup Logs'; group='Cleanup & Security'; tip='Cleans old temp files and setup logs.' },
           @{ id='po5'; label='Delete Unattend.xml (Remove Any Temporary Password)'; group='Cleanup & Security'; tip='Deletes any leftover Unattend.xml before customer handover.' }
       ) },
    @{ id='r05'; no='05'; title='Special 4GB Extreme (Optional)'; badge='OPTIONAL'; critical=$false;
       instruction='Optional low-end turbo enhancement specifically for 4GB RAM laptops after restore (saves 400-700 MB RAM).';
       items=@(
           @{ id='ex1'; label='Apply Reversible SvcHost Threshold'; group='4GB RAM Turbo'; tip='Applies a tracked registry value. Memory compression and service states are left unchanged.' },
           @{ id='ex2'; label='SysMain Service Tuning (Unavailable)'; group='4GB RAM Turbo'; tip='Disabled until original service state can be backed up and restored safely.' },
           @{ id='ex3'; label='Fixed Pagefile (Unavailable)'; group='Memory & Storage'; tip='Disabled until the original automatic/custom pagefile configuration can be backed up and restored.' },
           @{ id='ex4'; label='Reduce UI Animations & Blur (Tracked Settings)'; group='Visual Speed'; tip='Uses rollback-tracked registry settings and preserves font smoothing.' },
           @{ id='ex5'; label='Enable CompactOS Compression (Confirmation Required)'; group='Memory & Storage'; tip='Compresses Windows system binaries; actual space savings vary and performance may be affected.' }
       ) },
    @{ id='r06'; no='06'; title='Hardware Inspection Link'; badge=''; critical=$false;
       instruction='Linked module - Jump directly to Auto Hardware Scan, Manual QC Scan, or Digital 1-Page A4 Reports.';
       items=@() },
    @{ id='r07'; no='07'; title='Finalize & Ready'; badge='QC PASS'; critical=$false;
       instruction='Final Windows Genuine Activation check, QC verification, and Customer Certificate readiness before delivery.';
       items=@(
           @{ id='fn1'; label='Activation Check - Verify Windows Genuine License'; group='License & QC'; tip='Checks Windows activation state via slmgr /xpr.' },
           @{ id='fn2'; label='Verify Hardware QC Passed (Keyboard / Screen / Battery)'; group='License & QC'; tip='Confirms hardware inspection items are checked.' },
           @{ id='fn3'; label='Remove SLT Audit & Temporary Diagnostic Logs'; group='Privacy & Clean'; tip='Cleans temporary setup and answer files.' },
           @{ id='fn4'; label='Verify Desktop Web Hubs & Support Shortcuts'; group='Customer Ready'; tip='Ensures SLT Desktop shortcuts are present.' },
           @{ id='fn5'; label='Mark Ready for Customer & Open A4 Certificate Preview'; group='Customer Ready'; tip='Marks laptop QC Pass and opens Digital Report.' }
       ) }
)

$script:BROptTiers = @(
    @{ id='SMART';   label='SMART';   sub='Safe . Recommended'; desc='Applies rollback-tracked startup, privacy, and visual settings plus old-temp cleanup. Optional Store-app removals require confirmation and are not automatically reversible.' },
    @{ id='ULTRA';   label='ULTRA';   sub='High . 8GB+ RAM';    desc='Includes SMART plus additional tracked privacy, Edge background, and UI settings. Service, scheduled-task, hibernation, and pagefile changes remain disabled until rollback support is ready.' },
    @{ id='EXTREME'; label='EXTREME'; sub='4GB Low-End Only';   desc='Includes ULTRA plus additional tracked settings and optional app removals. Fixed pagefile, service, and Default User profile changes are not applied automatically.' },
    @{ id='COMPACT'; label='COMPACT'; sub='Optional Image Size Reduction'; desc='Runs selected DISM component cleanup, confirmed CompactOS compression, and LZX WIM capture preparation. Actual savings depend on the Windows image.' }
)

$script:BROptSmartItems = @(
    @{ id='s1';  label='Teams auto-start OFF';                   group='Startup & Temp' },
    @{ id='s2';  label='OneDrive auto-start OFF';                group='Startup & Temp' },
    @{ id='s3';  label='Spotify auto-start OFF';                 group='Startup & Temp' },
    @{ id='s4';  label='Phone Link auto-start OFF';              group='Startup & Temp' },
    @{ id='s5';  label='%TEMP% User Cache Clear';                group='Startup & Temp' },
    @{ id='s6';  label='Windows\Temp System Clear';              group='Startup & Temp' },
    @{ id='s7';  label='Preserve Windows Prefetch (Recommended)'; group='Startup & Temp' },
    @{ id='s8';  label='Preserve Windows Update Cache (Recommended)'; group='Startup & Temp' },
    @{ id='s9';  label='Empty Recycle Bin (Confirmation Required)'; group='Startup & Temp' },
    @{ id='s10'; label='Apply Reversible Telemetry Policy';         group='Privacy & Bloat' },
    @{ id='s11'; label='WAP Push Service Tuning (Unavailable)';    group='Privacy & Bloat' },
    @{ id='s12'; label='Location Tracking OFF';                  group='Privacy & Bloat' },
    @{ id='s13'; label='Advertising ID & Tailored Ads OFF';      group='Privacy & Bloat' },
    @{ id='s14'; label='Activity History Upload OFF';            group='Privacy & Bloat' },
    @{ id='s15'; label='Feedback Hub Prompts Never';             group='Privacy & Bloat' },
    @{ id='s16'; label='Candy Crush & Consumer Games Remove';    group='Privacy & Bloat' },
    @{ id='s17'; label='Xbox GameDVR Background OFF (Keep Core)';group='Privacy & Bloat' },
    @{ id='s18'; label='Mixed Reality & 3D Viewer Remove';       group='Privacy & Bloat' },
    @{ id='s19'; label='Solitaire Casual Bloat Remove';          group='Privacy & Bloat' },
    @{ id='s20'; label='Background Apps OFF (Keep Essential)';   group='Visual & Power' },
    @{ id='s21'; label='Best Performance - Keep Smooth Fonts';   group='Visual & Power' },
    @{ id='s22'; label='No Window Minimize/Maximize Animations'; group='Visual & Power' },
    @{ id='s23'; label='No Drop Shadows Under Windows';          group='Visual & Power' },
    @{ id='s24'; label='Transparency / Acrylic Blur OFF';        group='Visual & Power' },
    @{ id='s25'; label='High Performance Power Plan (Unavailable)'; group='Visual & Power' },
    @{ id='s26'; label='USB Selective Suspend (Unavailable)';      group='Visual & Power' },
    @{ id='s27'; label='Defender Auto Sample Submission OFF';    group='Visual & Power' }
)

$script:BROptUltraOnlyItems = @(
    @{ id='u1';  label='Disable Widgets & News Feed (Tracked Policy)'; group='Ultra UI & Edge' },
    @{ id='u2';  label='Taskbar Chat / Meet Now Icon OFF';       group='Ultra UI & Edge' },
    @{ id='u3';  label='Windows Copilot Auto-Start OFF';         group='Ultra UI & Edge' },
    @{ id='u4';  label='Edge Startup Boost & Background OFF';    group='Ultra UI & Edge' },
    @{ id='u5';  label='SysMain Tuning (Unavailable)';            group='Ultra Services' },
    @{ id='u6';  label='Print Spooler Tuning (Unavailable)';     group='Ultra Services' },
    @{ id='u7';  label='Fax Service Tuning (Unavailable)';       group='Ultra Services' },
    @{ id='u8';  label='Search Web Bing Suggestions OFF';        group='Ultra Services' },
    @{ id='u9';  label='Scheduled Task Tuning (Unavailable)';     group='Ultra System' },
    @{ id='u10'; label='CEIP Task Tuning (Unavailable)';          group='Ultra System' },
    @{ id='u11'; label='App Experience Task Tuning (Unavailable)'; group='Ultra System' },
    @{ id='u12'; label='Shadow Copy Status (Unavailable)';         group='Ultra System' },
    @{ id='u13'; label='Hibernation Tuning (Unavailable)';      group='Ultra System' },
    @{ id='u14'; label='Pagefile Status (Unavailable)';           group='Ultra System' },
    @{ id='u15'; label='WPAD Auto Proxy Lookup OFF';             group='Ultra System' }
)

$script:BROptExtremeOnlyItems = @(
    @{ id='e1';  label='Disable OneDrive Sync Engine (High Risk)'; group='Extreme 4GB RAM' },
    @{ id='e2';  label='Cortana App & Remnants Remove';          group='Extreme 4GB RAM' },
    @{ id='e3';  label='Edge Prelaunch & Tab Preloading OFF';    group='Extreme 4GB RAM' },
    @{ id='e4';  label='Maps / People / News / Weather Remove';  group='Extreme 4GB RAM' },
    @{ id='e5';  label='Tracked SvcHost Threshold + UI Timing';  group='Extreme 4GB RAM' },
    @{ id='e6';  label='Fixed Pagefile (Unavailable)';           group='Extreme 4GB RAM' },
    @{ id='e7';  label='Language Background Speech Telemetry OFF';group='Extreme 4GB RAM' },
    @{ id='e8';  label='Defender Scan Load Tuning (Unavailable)'; group='Extreme 4GB RAM' }
)

$script:BROptCompactItems = @(
    @{ id='c1';  label='DISM Component Cleanup (Confirmation Required)'; group='DISM & CompactOS' },
    @{ id='c2';  label='CompactOS Compression (Confirmation Required)'; group='DISM & CompactOS' },
    @{ id='c3';  label='Separate WinSxS Cleanup (Unavailable)';    group='DISM & CompactOS' },
    @{ id='c4';  label='LZX Maximum Compression WIM Flag';       group='Image Size Cleanup' },
    @{ id='c5';  label='Delivery Optimization Cache Remove';     group='Image Size Cleanup' },
    @{ id='c6';  label='Preserve Windows Update Cache';           group='Image Size Cleanup' },
    @{ id='c7';  label='Clear Explorer Thumbnail Cache';          group='Image Size Cleanup' }
)

# Initialize all checkboxes to $true by default and load saved stage completion state
foreach ($st in ($script:BRBackupStages + $script:BRRestoreStages)) {
    foreach ($it in $st.items) {
        if (-not $script:BRChecks.ContainsKey($it.id)) {
            $script:BRChecks[$it.id] = $(if ($it.id -eq 'gs5') { $false } else { $true })
        }
    }
}
foreach ($it in ($script:BROptSmartItems + $script:BROptUltraOnlyItems + $script:BROptExtremeOnlyItems + $script:BROptCompactItems)) {
    if (-not $script:BRChecks.ContainsKey($it.id)) { $script:BRChecks[$it.id] = $true }
}
$script:BROptAppliedItems = @{}
$script:BROptSelectedCountLbl = $null
$script:BROptStepIdx = 0
$script:BROptAppliedCnt = 0
$script:BROptAdvanceNext = $false
if (-not $script:BRCompletedStages.ContainsKey('b00')) { $script:BRCompletedStages['b00'] = $true }
if (Get-Command Load-SLTBRState -ErrorAction SilentlyContinue) { Load-SLTBRState }

function Sync-SLTBRAutoDetectedStages {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $script:BRCompletedStages['b00'] = $true
        # b01: Check if Store AutoDownload=2 is already set on this PC
        $stVal = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -ErrorAction SilentlyContinue
        if ($null -ne $stVal -and $stVal.AutoDownload -eq 2) {
            $script:BRCompletedStages['b01'] = $true
        }
        # b03: Check if C:\Drivers folder exists
        if (Test-Path -LiteralPath 'C:\Drivers') {
            $script:BRCompletedStages['b03'] = $true
        }
        # b04: Check if SLT Desktop shortcut exists
        $desk = [Environment]::GetFolderPath('Desktop')
        if ((Test-Path -LiteralPath (Join-Path $desk 'SMART PC BOOST.lnk')) -or (Test-Path -LiteralPath (Join-Path $desk 'SLT AI Hub.lnk'))) {
            $script:BRCompletedStages['b04'] = $true
        }
        # b05: Check if optimization telemetry policy is already applied
        $telVal = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -ErrorAction SilentlyContinue
        if (($null -ne $telVal -and $telVal.AllowTelemetry -eq 0) -or $script:BROptAppliedItems.Count -gt 0) {
            $script:BRCompletedStages['b05'] = $true
        }
        # b06: Check if Preflight report exists in LogDir
        if ($null -ne $script:LogDir -and @(Get-ChildItem -LiteralPath $script:LogDir -Filter 'Preflight_*.json' -ErrorAction SilentlyContinue).Count -gt 0) {
            $script:BRCompletedStages['b06'] = $true
        }
        # b07: Check if Unattend XML exists in StateDir
        if ($null -ne $script:StateDir -and @(Get-ChildItem -LiteralPath $script:StateDir -Filter 'Unattend_*.xml' -ErrorAction SilentlyContinue).Count -gt 0) {
            $script:BRCompletedStages['b07'] = $true
        }
        # b09: Check if CAPTURE_SLT_MASTER_LZX.cmd exists in StateDir
        if ($null -ne $script:StateDir -and (Test-Path -LiteralPath (Join-Path $script:StateDir 'CAPTURE_SLT_MASTER_LZX.cmd'))) {
            $script:BRCompletedStages['b09'] = $true
        }
        # r02: Fast Registry check for wuauserv Start mode (avoids SCM delay at startup)
        $wuaReg = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv' -Name 'Start' -ErrorAction SilentlyContinue
        if ($null -ne $wuaReg -and $wuaReg.Start -ne 4 -and ($null -eq $stVal -or $stVal.AutoDownload -ne 2)) {
            $script:BRCompletedStages['r02'] = $true
        }
    } catch {} finally {
        $ErrorActionPreference = $oldEap
    }
}
Sync-SLTBRAutoDetectedStages

function Get-SLTBROptItemsForTier([string]$Tier) {
    if ($Tier -eq 'SMART')   { return $script:BROptSmartItems }
    if ($Tier -eq 'ULTRA')   { return ($script:BROptSmartItems + $script:BROptUltraOnlyItems) }
    if ($Tier -eq 'EXTREME') { return ($script:BROptSmartItems + $script:BROptUltraOnlyItems + $script:BROptExtremeOnlyItems) }
    return $script:BROptCompactItems
}

function Set-SLTBRBanner([string]$Msg) {
    $script:BRClickCount++
    if ($null -ne $script:BRFooterStatusLbl) {
        $script:BRFooterStatusLbl.Text = "$Msg  (Action #$($script:BRClickCount))"
    }
    if ($null -ne $script:BRStatusBannerTxt) {
        $script:BRStatusBannerTxt.Text = $Msg
    }
    Log-SLT ("Backup & Restore Factory: " + $Msg)
}

function Toggle-SLTBRStageDone([string]$StageId, [switch]$ForceDone) {
    if ($ForceDone) {
        $script:BRCompletedStages[$StageId] = $true
    } else {
        $cur = ($script:BRCompletedStages.ContainsKey($StageId) -and [bool]$script:BRCompletedStages[$StageId])
        $script:BRCompletedStages[$StageId] = (-not $cur)
    }
    if (Get-Command Save-SLTBRState -ErrorAction SilentlyContinue) { Save-SLTBRState }
    Update-SLTBRVisuals

Set-Item -Path Function:\global:Start-SLTCollection -Value ${function:Start-SLTCollection}
Set-Item -Path Function:\global:Invoke-SLTOEMTool -Value ${function:Invoke-SLTOEMTool}
Set-Item -Path Function:\global:Sync-SLTBRAutoDetectedStages -Value ${function:Sync-SLTBRAutoDetectedStages}
Set-Item -Path Function:\global:Get-SLTBROptItemsForTier -Value ${function:Get-SLTBROptItemsForTier}
Set-Item -Path Function:\global:Set-SLTBRBanner -Value ${function:Set-SLTBRBanner}
Set-Item -Path Function:\global:Toggle-SLTBRStageDone -Value ${function:Toggle-SLTBRStageDone}
Set-Item -Path Function:\global:Show-SLTOptimizationLiveStatusModal -Value ${function:Show-SLTOptimizationLiveStatusModal}
Set-Item -Path Function:\global:Invoke-SLTBRRunStage -Value ${function:Invoke-SLTBRRunStage}
Set-Item -Path Function:\global:Render-SLTBRStageList -Value ${function:Render-SLTBRStageList}
Set-Item -Path Function:\global:New-SLTBRChecklistGrid -Value ${function:New-SLTBRChecklistGrid}
Set-Item -Path Function:\global:Render-SLTBRDetail -Value ${function:Render-SLTBRDetail}
Set-Item -Path Function:\global:Update-SLTBRVisuals -Value ${function:Update-SLTBRVisuals}
}

# =====================================================================
# REAL STAGE EXECUTION HANDLER (Executes Checked Items for Any Stage!)
# =====================================================================
function Show-SLTOptimizationLiveStatusModal([string]$Tier, [hashtable]$Checks) {
    # Crash-Proof Step-by-Step Optimization Live Status Window (Runs on Main Runspace via DispatcherTimer - Zero ThreadPool Crash!)
    $tierItems = @(Get-SLTBROptItemsForTier $Tier)
    $activeItems = New-Object System.Collections.Generic.List[object]
    foreach ($it in $tierItems) {
        if ($Checks[$it.id]) {
            $activeItems.Add($it)
        }
    }
    if ($activeItems.Count -eq 0) {
        [Windows.MessageBox]::Show('Please select at least one optimization item first.', "Stage 05 - $Tier Optimization", 'OK', 'Information') | Out-Null
        return $false
    }
    # Normal optimization tiers do not run Sysprep preparation or modify the Default User profile.
    $totalSteps = $activeItems.Count

    $dlg = New-Object Windows.Window
    $dlg.Title = "SLT Smart PC Boost v1.0.0 - $Tier Optimization Live Status"
    $dlg.Width = 650
    $dlg.Height = 475
    $dlg.WindowStartupLocation = 'CenterOwner'
    try { if ($null -ne $script:Window -and $script:Window.IsVisible) { $dlg.Owner = $script:Window } } catch {}
    $dlg.ResizeMode = 'NoResize'
    $dlg.Topmost = $true
    Apply-SLTDialogTheme $dlg

    $conv = [Windows.Media.BrushConverter]::new()
    $outer = New-Object Windows.Controls.Grid
    $outer.Margin = [Windows.Thickness]::new(22, 18, 22, 18)
    $r0 = New-Object Windows.Controls.RowDefinition; $r0.Height = [Windows.GridLength]::Auto
    $r1 = New-Object Windows.Controls.RowDefinition; $r1.Height = [Windows.GridLength]::Auto
    $r2 = New-Object Windows.Controls.RowDefinition; $r2.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $r3 = New-Object Windows.Controls.RowDefinition; $r3.Height = [Windows.GridLength]::Auto
    $outer.RowDefinitions.Add($r0)|Out-Null; $outer.RowDefinitions.Add($r1)|Out-Null
    $outer.RowDefinitions.Add($r2)|Out-Null; $outer.RowDefinitions.Add($r3)|Out-Null

    # Header Row
    $hdrGrid = New-Object Windows.Controls.Grid
    $hc0 = New-Object Windows.Controls.ColumnDefinition; $hc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $hc1 = New-Object Windows.Controls.ColumnDefinition; $hc1.Width = [Windows.GridLength]::Auto
    $hdrGrid.ColumnDefinitions.Add($hc0)|Out-Null; $hdrGrid.ColumnDefinitions.Add($hc1)|Out-Null

    $hStack = New-Object Windows.Controls.StackPanel
    $hTitle = New-Object Windows.Controls.TextBlock
    $hTitle.Text = "Stage 05: $Tier Optimization & Debloating"
    $hTitle.FontSize = 16.5; $hTitle.FontWeight = 'Bold'
    $hTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
    $hSub = New-Object Windows.Controls.TextBlock
    $hSub.Text = "Executing $totalSteps optimization steps safely (App stays open & auto-marks Completed)..."
    $hSub.FontSize = 11.5; $hSub.Margin = [Windows.Thickness]::new(0,2,0,0)
    $hSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $hStack.Children.Add($hTitle)|Out-Null; $hStack.Children.Add($hSub)|Out-Null
    $hdrGrid.Children.Add($hStack)|Out-Null

    $tBadge = New-Object Windows.Controls.Border
    $tBadge.CornerRadius = [Windows.CornerRadius]::new(8)
    $tBadge.Padding = [Windows.Thickness]::new(12,5,12,5)
    $tBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
    $tBadge.VerticalAlignment = 'Center'
    $tBadge.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $tBadgeTxt = New-Object Windows.Controls.TextBlock
    $tBadgeTxt.Text = "0 / $totalSteps"
    $tBadgeTxt.FontSize = 12; $tBadgeTxt.FontWeight = 'Bold'
    $tBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
    $tBadge.Child = $tBadgeTxt
    $hdrGrid.Children.Add($tBadge)|Out-Null
    $hdrGrid.SetValue([Windows.Controls.Grid]::RowProperty, 0)
    $outer.Children.Add($hdrGrid)|Out-Null

    # Progress Bar Row
    $progStack = New-Object Windows.Controls.StackPanel
    $progStack.Margin = [Windows.Thickness]::new(0, 14, 0, 12)
    $pBar = New-Object Windows.Controls.ProgressBar
    $pBar.Height = 14; $pBar.Minimum = 0; $pBar.Maximum = 100; $pBar.Value = 2
    $pBar.Foreground = $conv.ConvertFromString('#10B981')
    $pBar.Background = $conv.ConvertFromString('#1E293B')
    $pBar.BorderThickness = [Windows.Thickness]::new(0)
    $progStack.Children.Add($pBar)|Out-Null

    $statLbl = New-Object Windows.Controls.TextBlock
    $statLbl.Text = "Preparing $Tier optimization queue..."
    $statLbl.FontSize = 12; $statLbl.FontWeight = 'Bold'
    $statLbl.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    $statLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    $progStack.Children.Add($statLbl)|Out-Null
    $progStack.SetValue([Windows.Controls.Grid]::RowProperty, 1)
    $outer.Children.Add($progStack)|Out-Null

    # Scrollable Step Feed Box
    $feedBdr = New-Object Windows.Controls.Border
    $feedBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $feedBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $feedBdr.BorderThickness = [Windows.Thickness]::new(1)
    $feedBdr.CornerRadius = [Windows.CornerRadius]::new(10)
    $feedBdr.Padding = [Windows.Thickness]::new(12, 10, 12, 10)
    $feedBdr.Margin = [Windows.Thickness]::new(0, 0, 0, 14)

    $scrollViewer = New-Object Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'
    $feedStack = New-Object Windows.Controls.StackPanel
    $scrollViewer.Content = $feedStack
    $feedBdr.Child = $scrollViewer
    $feedBdr.SetValue([Windows.Controls.Grid]::RowProperty, 2)
    $outer.Children.Add($feedBdr)|Out-Null

    # Bottom Button Row
    $btnRow = New-Object Windows.Controls.StackPanel
    $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'

    $btnClose = New-Object Windows.Controls.Button
    $btnClose.Content = 'Optimizing...'
    $btnClose.Style = $script:Window.FindResource('OutlineButton')
    $btnClose.Width = 145; $btnClose.Height = 36; $btnClose.MinHeight = 36
    $btnClose.FontWeight = 'SemiBold'; $btnClose.FontSize = 11.8
    $btnClose.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
    $btnClose.IsEnabled = $false
    $btnClose.IsCancel = $true
    $btnClose.Tag = $dlg
    $btnClose.Add_Click({
        param($s, $e)
        $script:BROptAdvanceNext = $false
        try { $s.Tag.Close() } catch {}
    })

    $btnNextStage = New-Object Windows.Controls.Button
    $btnNextStage.Content = 'Next: Stage 06 (Audit Check) ->'
    $btnNextStage.Style = $script:Window.FindResource('ActionButton')
    $btnNextStage.Width = 225; $btnNextStage.Height = 36; $btnNextStage.MinHeight = 36
    $btnNextStage.FontWeight = 'Bold'; $btnNextStage.FontSize = 12
    $btnNextStage.IsEnabled = $false
    $btnNextStage.IsDefault = $true
    $btnNextStage.Tag = $dlg
    $btnNextStage.Add_Click({
        param($s, $e)
        $script:BROptAdvanceNext = $true
        try { $s.Tag.Close() } catch {}
    })

    $btnRow.Children.Add($btnClose)|Out-Null
    $btnRow.Children.Add($btnNextStage)|Out-Null
    $btnRow.SetValue([Windows.Controls.Grid]::RowProperty, 3)
    $outer.Children.Add($btnRow)|Out-Null

    $dlg.Content = $outer

    $chkIcon = [char]0x2714
    $script:BROptStepIdx = 0
    $script:BROptAppliedCnt = 0
    $script:BROptAdvanceNext = $false

    $optTimer = New-Object Windows.Threading.DispatcherTimer
    $optTimer.Interval = [TimeSpan]::FromMilliseconds(45)
    $optTimer.Add_Tick({
        try {
            if ($script:BROptStepIdx -lt $totalSteps) {
                $curObj = $activeItems[$script:BROptStepIdx]
                $curId  = [string]$curObj.id
                $curLbl = [string]$curObj.label
                $stepNum = $script:BROptStepIdx + 1

                $statLbl.Text = ("Applying [{0}/{1}]: {2}..." -f $stepNum, $totalSteps, $curLbl)
                $detailMsg = Invoke-SLTSingleOptimizationItem -ItemId $curId -Tier $Tier

                $script:BROptAppliedItems[$curId] = $true
                if ($curId -notin @('sysprep_heal','default_hive')) {
                    $script:BROptAppliedCnt++
                }
                $script:BROptStepIdx++

                $pct = [int][Math]::Min(100, [Math]::Round(100.0 * $script:BROptStepIdx / $totalSteps))
                $pBar.Value = $pct
                $tBadgeTxt.Text = ("{0} / {1}" -f $script:BROptStepIdx, $totalSteps)

                $rowTb = New-Object Windows.Controls.TextBlock
                $rowTb.Text = ("$chkIcon  [{0}/{1}] {2}  -  {3}" -f $stepNum, $totalSteps, $curLbl, $detailMsg)
                $rowTb.FontSize = 11.2
                $rowTb.FontWeight = 'SemiBold'
                $rowTb.Foreground = $conv.ConvertFromString('#34D399')
                $rowTb.Margin = [Windows.Thickness]::new(0, 2, 0, 2)
                $rowTb.TextWrapping = 'Wrap'
                $feedStack.Children.Add($rowTb)|Out-Null
                $scrollViewer.ScrollToEnd()
            } else {
                $optTimer.Stop()
                $pBar.Value = 100
                $tBadgeTxt.Text = "DONE $chkIcon"
                $hTitle.Text = "$chkIcon  $Tier Optimization Completed Automatically!"
                $hSub.Text = "Stage 05 has been automatically marked Completed ($chkIcon) in the sidebar."
                $statLbl.Text = ("Processed {0} selected optimization items. Review skipped actions and the run log." -f $script:BROptAppliedCnt)
                $statLbl.Foreground = $conv.ConvertFromString('#34D399')

                # Automatically mark Stage 05 as Done right now so user sees tick mark immediately!
                Toggle-SLTBRStageDone 'b05' -ForceDone

                $btnClose.Content = 'Done & Close'
                $btnClose.IsEnabled = $true
                $btnNextStage.IsEnabled = $true
                $btnNextStage.Background = $conv.ConvertFromString('#059669')
                $btnNextStage.Foreground = $conv.ConvertFromString('#FFFFFF')
            }
        } catch {
            $script:BROptStepIdx++
        }
    })

    $dlg.Add_Loaded({ $optTimer.Start() })
    $dlg.Add_Closing({ try { $optTimer.Stop() } catch {} })
    $dlg.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Escape' -and $btnClose.IsEnabled) {
            try { $s.Close() } catch {}
        }
    })

    [void]$dlg.ShowDialog()
    if ($script:BROptAdvanceNext) {
        $script:BRBackupIndex = 6
        Update-SLTBRVisuals
    }
    return $true
}

function Invoke-SLTBRRunStage([string]$StageId) {
    try {
        switch ($StageId) {
            'b00' {
                Open-SLTLink 'https://www.microsoft.com/en-us/software-download/windows11'
                Toggle-SLTBRStageDone 'b00' -ForceDone
                Set-SLTBRBanner 'Stage 00: Opened Official Microsoft Windows 11 Download page.'
            }
            'b01' {
                Need-SLTAdmin
                Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2
                Set-SLTSetting 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate' 'AutoDownload' 2
                Set-SLTSetting 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
                # Do not stop Windows Update/Store services. The reversible Store policy guard is sufficient here.
                if (Get-Command Repair-SLTSysprepEnvironment -ErrorAction SilentlyContinue) {
                    try { Repair-SLTSysprepEnvironment | Out-Null } catch {}
                }
                Toggle-SLTBRStageDone 'b01' -ForceDone
                Set-SLTBRBanner 'Stage 01 Completed: Store AutoDownload policy applied. WinGet Source and Windows Update/Store services were preserved.'
            }
            'b02' {
                if ($script:BRChecks['wu1']) { try { Start-Process 'ms-settings:windowsupdate' } catch {} }
                if ($script:BRChecks['wu2']) { try { Start-Process 'ms-settings:windowsupdate-optionalupdates' } catch {} }
                Toggle-SLTBRStageDone 'b02' -ForceDone
                Set-SLTBRBanner 'Stage 02 Started: Windows Update & Runtime checks launched.'
            }
            'b03' {
                Need-SLTAdmin
                if ($script:BRChecks['dr5']) {
                    try { New-Item -ItemType Directory -Path 'C:\Drivers' -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
                }
                if ($script:BRChecks['dr1']) {
                    $script:DevType = New-Object Windows.Controls.ComboBox
                    $script:DevType.Items.Add('Generic')|Out-Null; $script:DevType.SelectedIndex = 0
                }
                Toggle-SLTBRStageDone 'b03' -ForceDone
                Set-SLTBRBanner 'Stage 03 Completed: Driver strategy configured and C:\Drivers prepared.'
            }
            'b04' {
                if ($script:BRChecks['slt3']) {
                    foreach ($h in @('AI','Social','Websites')) {
                        try { Start-SLTCollection -Name $h -Silent | Out-Null } catch {}
                    }
                }
                if ($script:BRChecks['slt4']) {
                    if (Get-Command Install-SLTLogoLaunchers -ErrorAction SilentlyContinue) { Install-SLTLogoLaunchers }
                }
                Toggle-SLTBRStageDone 'b04' -ForceDone
                Set-SLTBRBanner 'Stage 04 Completed: SLT Desktop Hubs & Logo Shortcuts installed.'
                if ($script:BRChecks['slt1']) {
                    Switch-SLTPage 1
                    try { $script:CategoryCombo.SelectedItem = 'SLT PC TOOLS' } catch {}
                }
            }
            'b05' {
                Need-SLTAdmin
                Show-SLTOptimizationLiveStatusModal -Tier $script:BROptSubTab -Checks $script:BRChecks | Out-Null
                Toggle-SLTBRStageDone 'b05' -ForceDone
                Set-SLTBRBanner ("Stage 05 Completed: " + $script:BROptSubTab + " optimization actions processed (" + $script:BROptAppliedCnt + " items); review the run log and pending checks before Sysprep.")
                Update-SLTBRVisuals
            }
            'b06' {
                Need-SLTAdmin
                $cleanedCnt = 0
                if (Get-Command Repair-SLTSysprepEnvironment -ErrorAction SilentlyContinue) {
                    try { $cleanedCnt = [int](Repair-SLTSysprepEnvironment) } catch {}
                }
                $repFile = Test-SLTImagePreflight
                $freeGB = 0
                try { $cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue; if ($cDrive) { $freeGB = [math]::Round($cDrive.Free / 1GB, 1) } } catch {}
                Toggle-SLTBRStageDone 'b06' -ForceDone
                Set-SLTBRBanner ("Stage 06 Audit completed: Appx inventory and Sysprep/pending-reboot state inspected; no packages or servicing markers deleted. Free space: " + $freeGB + " GB")
            }
            'b07' {
                Need-SLTAdmin
                if (-not ($script:BRChecks['af1'] -or $script:BRChecks['af2'])) {
                    Get-ChildItem -LiteralPath $script:StateDir -Filter 'Unattend_*.xml' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                    $pantherXml = Join-Path $env:WINDIR 'Panther\unattend.xml'
                    if (Test-Path -LiteralPath $pantherXml) {
                        $isSltFile = Select-String -LiteralPath $pantherXml -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                        if ($isSltFile) { Remove-Item -LiteralPath $pantherXml -Force -ErrorAction SilentlyContinue }
                        else { Set-SLTBRBanner 'Unattend OFF selected, but an external Panther\unattend.xml exists. It was preserved; review it before Sysprep.' }
                    }
                    $script:BRChecks['gs5'] = $false
                    Toggle-SLTBRStageDone 'b07' -ForceDone
                    Set-SLTBRBanner 'Stage 07 Completed: Unattend.xml is OFF (Standard Windows OOBE will run after Sysprep).'
                    return
                }
                $uMode = if ($null -ne $script:BRUnattendModeCombo -and $script:BRUnattendModeCombo.SelectedIndex -eq 1) { 'Model' } elseif ($script:BRChecks['af2'] -and -not $script:BRChecks['af1']) { 'Model' } else { 'Generic' }
                $uName = if ($null -ne $script:BRUnattendUserBox -and -not [string]::IsNullOrWhiteSpace($script:BRUnattendUserBox.Text)) { $script:BRUnattendUserBox.Text.Trim() } else { 'SLTUser' }
                $uDisp = if ($null -ne $script:BRUnattendDispBox -and -not [string]::IsNullOrWhiteSpace($script:BRUnattendDispBox.Text)) { $script:BRUnattendDispBox.Text.Trim() } else { 'Smart Life Teck' }
                $uPass = if ($null -ne $script:BRUnattendPassBox) { $script:BRUnattendPassBox.Password } else { '' }
                if ([string]::IsNullOrWhiteSpace($uPass)) { throw 'Enter a unique temporary local-account password before generating Unattend.xml. No default password is provided.' }
                if ($script:BRChecks['af5']) {
                    $existingPanther = Join-Path $env:WINDIR 'Panther\unattend.xml'
                    if (Test-Path -LiteralPath $existingPanther) {
                        $existingIsSlt = Select-String -LiteralPath $existingPanther -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                        if (-not $existingIsSlt) { throw 'An external Panther\unattend.xml already exists. It was preserved; back it up and move it manually before selecting Copy to Panther.' }
                    }
                }
                try { $xmlPath = New-SLTUnattend $uMode $uName $uDisp $script:BRUnattendPassBox.SecurePassword $false }
                finally { if ($null -ne $script:BRUnattendPassBox) { $script:BRUnattendPassBox.Clear() }; $uPass = $null }
                if ($script:BRChecks['af5']) {
                    try {
                        $panther = Join-Path $env:WINDIR 'Panther'
                        New-Item -ItemType Directory -Path $panther -Force -ErrorAction Stop | Out-Null
                        $pantherFile = Join-Path $panther 'unattend.xml'
                        Copy-Item -LiteralPath $xmlPath -Destination $pantherFile -Force -ErrorAction Stop
                        $sourceAcl = Get-Acl -LiteralPath $xmlPath -ErrorAction Stop
                        Set-Acl -LiteralPath $pantherFile -AclObject $sourceAcl -ErrorAction Stop
                    } catch {
                        try { if (Test-Path -LiteralPath $pantherFile) { $copiedIsSlt = Select-String -LiteralPath $pantherFile -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue; if ($copiedIsSlt) { Remove-Item -LiteralPath $pantherFile -Force -ErrorAction SilentlyContinue } } } catch {}
                        try { if (Test-Path -LiteralPath $xmlPath) { $sourceIsSlt = Select-String -LiteralPath $xmlPath -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue; if ($sourceIsSlt) { Remove-Item -LiteralPath $xmlPath -Force -ErrorAction SilentlyContinue } } } catch {}
                        throw ('Could not securely deploy Unattend.xml to Panther. SLT-generated temporary files were cleaned up: ' + $_.Exception.Message)
                    }
                }
                $script:BRChecks['gs5'] = $true
                Toggle-SLTBRStageDone 'b07' -ForceDone
                Set-SLTBRBanner ("Stage 07 Completed: Generated " + $uMode + " Unattend.xml (" + $xmlPath + ") & enabled for Stage 08.")
            }
            'b08' {
                Need-SLTAdmin
                if (-not (Show-SLTDecision 'STAGE 08: GENERALISE & SHUTDOWN (SYSPREP)' 'Run Windows Sysprep now?' 'This runs Sysprep. SLT will not remove Appx packages, delete pending-reboot markers, or decrypt C:. If BitLocker is active, protection may be suspended for two reboots; data stays encrypted, but the volume key is made available in clear and boot-integrity protection is temporarily reduced. Back up the recovery key and keep physical access controlled. Existing external Panther answer files block launch.' $true)) { return }

                Set-SLTBRBanner 'Stage 08: verifying pending reboot state and BitLocker protection before Sysprep...'
                $pendingPaths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
                $pendingFound = @($pendingPaths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0
                $sessMgr = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
                $pendingRename = $null -ne $sessMgr -and $null -ne $sessMgr.PSObject.Properties['PendingFileRenameOperations']
                if ($pendingFound -or $pendingRename) { Set-SLTBRBanner 'Sysprep stopped: Windows reports a pending reboot/rename. Restart Windows, rerun Stage 06, then retry.'; return }
                # Validate answer-file state before any BitLocker operation. Preserve external Panther files.
                $prePanther = Join-Path $env:WINDIR 'Panther\unattend.xml'
                if (Test-Path -LiteralPath $prePanther) {
                    $prePantherIsSlt = Select-String -LiteralPath $prePanther -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                    if (-not $prePantherIsSlt) { Set-SLTBRBanner 'Sysprep stopped before BitLocker changes: external Panther\unattend.xml exists and was preserved. Back it up and move it manually after review.'; return }
                }
                if ($script:BRChecks['gs5']) {
                    $preMode = if ($null -ne $script:BRUnattendModeCombo -and $script:BRUnattendModeCombo.SelectedIndex -eq 1) { 'Model' } elseif ($script:BRChecks['af2'] -and -not $script:BRChecks['af1']) { 'Model' } else { 'Generic' }
                    $preXml = Join-Path $script:StateDir ('Unattend_{0}.xml' -f $preMode)
                    if (-not (Test-Path -LiteralPath $preXml) -or -not (Select-String -LiteralPath $preXml -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue)) {
                        Set-SLTBRBanner 'Sysprep stopped before BitLocker changes: selected SLT Unattend file is missing or not verified. Recreate it in Stage 07.'; return
                    }
                } else {
                    $prePanther = Join-Path $env:WINDIR 'Panther\unattend.xml'
                    if (Test-Path -LiteralPath $prePanther) {
                        $preIsSlt = Select-String -LiteralPath $prePanther -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                        if (-not $preIsSlt) { Set-SLTBRBanner 'Sysprep stopped before BitLocker changes: external Panther\unattend.xml exists and was preserved. Review it manually.'; return }
                    }
                }
                if ($script:BRChecks['gs2'] -and (Get-Command Repair-SLTSysprepEnvironment -ErrorAction SilentlyContinue)) {
                    try { Repair-SLTSysprepEnvironment | Out-Null } catch { Set-SLTBRBanner ('Sysprep readiness review failed: ' + $_.Exception.Message); return }
                }
                $bitlockerCheck = Suspend-SLTBitLockerForSysprep
                if (-not $bitlockerCheck.Success) { Set-SLTBRBanner $bitlockerCheck.Message; return }
                if ($bitlockerCheck.Suspended -and -not $script:BRChecks['gs4']) {
                    try {
                        Resume-BitLocker -MountPoint 'C:' -ErrorAction Stop | Out-Null
                        Set-SLTBRBanner 'Sysprep stopped: SLT suspended BitLocker, so Shutdown After Sysprep must remain selected. BitLocker protection was resumed; select shutdown and retry.'
                    } catch {
                        Set-SLTBRBanner ('Sysprep stopped: shutdown is required while BitLocker is suspended. Automatic resume failed: ' + $_.Exception.Message + '. Resume BitLocker manually before continuing.')
                    }
                    return
                }
                Log-SLT $bitlockerCheck.Message

                # Archive old Sysprep logs/markers; never delete diagnostic evidence.
                if ($script:BRChecks['gs3']) {
                    try {
                        $archiveDir = Join-Path $script:StateDir ('SysprepLogs_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
                        New-Item -ItemType Directory -Path $archiveDir -Force -ErrorAction Stop | Out-Null
                        foreach ($oldLog in @(
                            (Join-Path $env:WINDIR 'System32\Sysprep\Panther\setupact.log'),
                            (Join-Path $env:WINDIR 'System32\Sysprep\Panther\setuperr.log'),
                            (Join-Path $env:WINDIR 'System32\Sysprep\Sysprep_succeeded.tag')
                        )) {
                            if (Test-Path -LiteralPath $oldLog) {
                                try { Move-Item -LiteralPath $oldLog -Destination (Join-Path $archiveDir (Split-Path $oldLog -Leaf)) -Force -ErrorAction Stop } catch { Log-SLT ('Could not archive Sysprep log: ' + $_.Exception.Message) }
                            }
                        }
                    } catch { Log-SLT ('Sysprep log archive skipped: ' + $_.Exception.Message) }
                }

                $sysprepArgs = @('/generalize','/oobe')
                if ($script:BRChecks['gs4']) { $sysprepArgs += '/shutdown' } else { $sysprepArgs += '/quit' }
                if ($script:BRChecks['gs5']) {
                    $sysprepArgs += ('/unattend:"' + $preXml + '"')
                } else {
                    # The preflight above already rejected external files. Recheck to avoid a race;
                    # only remove an SLT-generated Panther answer file.
                    $stalePantherXml = Join-Path $env:WINDIR 'Panther\unattend.xml'
                    if (Test-Path -LiteralPath $stalePantherXml) {
                        $isSltFile = Select-String -LiteralPath $stalePantherXml -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                        if ($isSltFile) { Remove-Item -LiteralPath $stalePantherXml -Force -ErrorAction SilentlyContinue }
                        else {
                            if ($bitlockerCheck.Suspended) { try { Resume-BitLocker -MountPoint 'C:' -ErrorAction Stop | Out-Null } catch { Log-SLT ('BitLocker resume after Sysprep preflight abort failed: ' + $_.Exception.Message) } }
                            Set-SLTBRBanner 'Sysprep stopped: an external Panther\unattend.xml appeared during preflight and was preserved. Review it manually.'; return
                        }
                    }
                }

                $sysprepExe = Join-Path $env:WINDIR 'System32\Sysprep\Sysprep.exe'
                try {
                    $sysprepProc = Start-Process -FilePath $sysprepExe -ArgumentList $sysprepArgs -PassThru -ErrorAction Stop
                    if ($null -eq $sysprepProc) { throw 'Sysprep process did not start.' }
                    Toggle-SLTBRStageDone 'b08' -ForceDone
                    Set-SLTBRBanner ('Stage 08 Launched: Sysprep ' + ($sysprepArgs -join ' ') + '. No Appx packages or servicing markers were removed; BitLocker state: ' + $bitlockerCheck.Message)
                } catch {
                    if ($bitlockerCheck.Suspended) { try { Resume-BitLocker -MountPoint 'C:' -ErrorAction Stop | Out-Null; Log-SLT 'BitLocker protection resumed because Sysprep failed to launch.' } catch { Log-SLT ('BitLocker resume after Sysprep launch failure failed: ' + $_.Exception.Message) } }
                    Set-SLTBRBanner ('Sysprep failed to launch: ' + $_.Exception.Message)
                    return
                }
            }
            'b09' {
                $wimPath = if ($null -ne $script:BRWimPathBox -and -not [string]::IsNullOrWhiteSpace($script:BRWimPathBox.Text)) { $script:BRWimPathBox.Text.Trim() } else { 'D:\SLT_Backup.wim' }
                $imgName = if ($null -ne $script:BRImageNameBox -and -not [string]::IsNullOrWhiteSpace($script:BRImageNameBox.Text)) { $script:BRImageNameBox.Text.Trim() } else { 'SLT-GOLD-MASTER-W11' }
                $cmdStr = 'dism /Capture-Image /ImageFile:"' + $wimPath + '" /CaptureDir:C:\ /Name:"' + $imgName + '" /Compress:maximum /CheckIntegrity /Verify'
                try { [Windows.Clipboard]::SetText($cmdStr) } catch {}
                if ($script:BRChecks['bk5']) {
                    try {
                        $outCmd = Join-Path $script:StateDir 'CAPTURE_SLT_MASTER_LZX.cmd'
                        [IO.File]::WriteAllText($outCmd, ("@echo off`r`necho Capturing Smart Life Teck Master Image (LZX Max)...`r`n" + $cmdStr + "`r`npause`r`n"))
                    } catch {}
                }
                Toggle-SLTBRStageDone 'b09' -ForceDone
                Set-SLTBRBanner ('Stage 09 Ready: DISM LZX Capture command copied to clipboard & saved (' + $wimPath + ').')
            }
            'r01' {
                $wimPath = if ($null -ne $script:BRRestoreWimBox -and -not [string]::IsNullOrWhiteSpace($script:BRRestoreWimBox.Text)) { $script:BRRestoreWimBox.Text.Trim() } else { 'D:\SLT_Backup.wim' }
                $applyCmd = 'dism /Apply-Image /ImageFile:"' + $wimPath + '" /Index:1 /ApplyDir:C:\ /CheckIntegrity' + "`r`n" + 'bcdboot C:\Windows /f UEFI'
                try { [Windows.Clipboard]::SetText($applyCmd) } catch {}
                Toggle-SLTBRStageDone 'r01' -ForceDone
                Set-SLTBRBanner ('Stage 01 Ready: DISM Apply-Image & BCDBoot commands copied to clipboard (' + $wimPath + ').')
            }
            'r02' {
                Need-SLTAdmin
                if ($script:BRChecks['re1'] -or $script:BRChecks['re2']) {
                    Set-SLTUpdateChoice 'StoreRestore'
                }
                # Service startup type is intentionally left unchanged; the app does not own this setting.
                if ($script:BRChecks['re3']) {
                    try { Start-Service -Name 'wuauserv' -ErrorAction SilentlyContinue } catch {}
                }
                if ($script:BRChecks['re5']) {
                    try { Start-Process 'ms-settings:windowsupdate' } catch {}
                }
                Toggle-SLTBRStageDone 'r02' -ForceDone
                Set-SLTBRBanner 'Stage 02 Completed: Microsoft Store policy restored. Windows Update service startup type was not modified.'
            }
            'r03' {
                Need-SLTAdmin
                Invoke-SLTOEMTool
                Toggle-SLTBRStageDone 'r03' -ForceDone
                Set-SLTBRBanner 'Stage 03 Completed: Official OEM Driver Auto-Detection launched.'
            }
            'r04' {
                Need-SLTAdmin
                if ($script:BRChecks['po2']) {
                    try {
                        Set-SLTStringSetting 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2'
                        Set-SLTSetting 'HKCU:\Control Panel\Desktop' 'FontSmoothingType' 2
                    } catch {}
                }
                # Power-plan switching is disabled until the original active plan can be restored.
                if ($script:BRChecks['po4']) {
                    try { Invoke-SLTCleanup } catch {}
                }
                if ($script:BRChecks['po5']) {
                    try {
                        Get-ChildItem -LiteralPath $script:StateDir -Filter 'Unattend_*.xml' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                        $pantherXml = Join-Path $env:WINDIR 'Panther\unattend.xml'
                        if (Test-Path -LiteralPath $pantherXml) {
                            $isSltFile = Select-String -LiteralPath $pantherXml -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                            if ($isSltFile) { Remove-Item -LiteralPath $pantherXml -Force -ErrorAction SilentlyContinue }
                            else { Set-SLTBRBanner 'Unattend cleanup skipped: Panther\unattend.xml was not generated by SLT Smart PC Boost and was preserved.' }
                        }
                    } catch {}
                }
                Toggle-SLTBRStageDone 'r04' -ForceDone
                Set-SLTBRBanner 'Stage 04 Completed: tracked display setting, temp cleanup, and SLT-generated Unattend cleanup finished. Power plan left unchanged.'
            }
            'r05' {
                Need-SLTAdmin
                if ($script:BRChecks['ex1']) {
                    try { Set-SLTSetting 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' 67108864 } catch {}
                }
                # SysMain service and pagefile changes are disabled until exact original state can be restored.
                if ($script:BRChecks['ex4']) {
                    try {
                        Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
                        Set-SLTSetting 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
                        Set-SLTStringSetting 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2'
                    } catch {}
                }
                if ($script:BRChecks['ex5']) {
                    $compactConfirm = [Windows.MessageBox]::Show('CompactOS compresses Windows system binaries and can affect performance. Continue?','Confirm CompactOS','YesNo','Warning')
                    if ($compactConfirm -eq 'Yes') { try { Start-Process -FilePath 'compact.exe' -ArgumentList '/compactos:always' -WindowStyle Hidden } catch {} }
                }
                Toggle-SLTBRStageDone 'r05' -ForceDone
                Set-SLTBRBanner 'Stage 05 Completed: tracked SvcHost/UI settings applied where selected. SysMain/pagefile changes were skipped; CompactOS required confirmation.'
            }
            'r06' {
                Toggle-SLTBRStageDone 'r06' -ForceDone
                Switch-SLTPage 5
                if (Get-Command Switch-SLTHWTab -ErrorAction SilentlyContinue) { Switch-SLTHWTab 'Auto' }
            }
            'r07' {
                if ($script:BRChecks['fn1']) {
                    try { Start-Process -FilePath 'slmgr.vbs' -ArgumentList '/xpr' } catch {}
                }
                if ($script:BRChecks['fn3']) {
                    try { Get-ChildItem -LiteralPath $script:StateDir -Filter 'Unattend_*.xml' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue } catch {}
                }
                if ($script:BRChecks['fn4']) {
                    if (Get-Command Install-SLTLogoLaunchers -ErrorAction SilentlyContinue) { Install-SLTLogoLaunchers }
                }
                Toggle-SLTBRStageDone 'r07' -ForceDone
                Set-SLTBRBanner 'Stage 07 Finalized: Activation checked, Audit logs cleaned, Laptop Ready for Customer Delivery!'
                if ($script:BRChecks['fn5']) {
                    Switch-SLTPage 5
                    if (Get-Command Switch-SLTHWTab -ErrorAction SilentlyContinue) { Switch-SLTHWTab 'Report' }
                }
            }
        }
    } catch {
        $err = $_.Exception.Message
        Set-SLTBRBanner ('Error in Stage ' + $StageId + ': ' + $err)
        [Windows.MessageBox]::Show($err, 'Smart Life Teck - Stage Action Notice', 'OK', 'Warning')|Out-Null
    }
}

# =====================================================================
# UI BUILDER FOR ONE-WINDOW BACKUP & RESTORE FACTORY
# =====================================================================
$factoryRoot = New-Object Windows.Controls.Grid
$frRow0 = New-Object Windows.Controls.RowDefinition; $frRow0.Height = [Windows.GridLength]::Auto
$frRow1 = New-Object Windows.Controls.RowDefinition; $frRow1.Height = [Windows.GridLength]::Auto
$frRow2 = New-Object Windows.Controls.RowDefinition; $frRow2.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$frRow3 = New-Object Windows.Controls.RowDefinition; $frRow3.Height = [Windows.GridLength]::Auto
$factoryRoot.RowDefinitions.Add($frRow0)|Out-Null
$factoryRoot.RowDefinitions.Add($frRow1)|Out-Null
$factoryRoot.RowDefinitions.Add($frRow2)|Out-Null
$factoryRoot.RowDefinitions.Add($frRow3)|Out-Null

# --- ROW 0: TOP HEADER BAR (54px) ---
$topBar = New-Object Windows.Controls.Border
$topBar.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'SidebarBg')
$topBar.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SidebarBorder')
$topBar.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
$topBar.Padding = [Windows.Thickness]::new(18,10,18,10)
$topBar.SetValue([Windows.Controls.Grid]::RowProperty, 0)

$topGrid = New-Object Windows.Controls.Grid
$tgC0 = New-Object Windows.Controls.ColumnDefinition; $tgC0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$tgC1 = New-Object Windows.Controls.ColumnDefinition; $tgC1.Width = [Windows.GridLength]::Auto
$topGrid.ColumnDefinitions.Add($tgC0)|Out-Null
$topGrid.ColumnDefinitions.Add($tgC1)|Out-Null

$topLeft = New-Object Windows.Controls.StackPanel
$topLeft.Orientation = 'Horizontal'; $topLeft.VerticalAlignment = 'Center'
$sltBadge = New-Object Windows.Controls.Border
$sltBadge.Width = 36; $sltBadge.Height = 36; $sltBadge.CornerRadius = [Windows.CornerRadius]::new(10)
$sltBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
$sltBadge.Margin = [Windows.Thickness]::new(0,0,12,0)
$sltBadgeTxt = New-Object Windows.Controls.TextBlock
$sltBadgeTxt.Text = 'SLT'; $sltBadgeTxt.FontSize = 12.5; $sltBadgeTxt.FontWeight = 'Bold'
$sltBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
$sltBadgeTxt.HorizontalAlignment = 'Center'; $sltBadgeTxt.VerticalAlignment = 'Center'
$sltBadge.Child = $sltBadgeTxt

$topTitleStack = New-Object Windows.Controls.StackPanel
$topTitleStack.VerticalAlignment = 'Center'
$topH1 = New-Object Windows.Controls.TextBlock
$topH1.Text = 'SLT Smart PC Boost v1.0.0 - Backup & Restore Factory'
$topH1.FontSize = 15; $topH1.FontWeight = 'Bold'
$topH1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$topSub = New-Object Windows.Controls.TextBlock
$topSub.Text = 'ONE WINDOW  .  NO SCROLL  .  SYSPREP-SAFE & 4GB LOW-RAM OPTIMIZATION'
$topSub.FontSize = 10; $topSub.FontWeight = 'SemiBold'
$topSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$topSub.Margin = [Windows.Thickness]::new(0,2,0,0)
$topTitleStack.Children.Add($topH1)|Out-Null
$topTitleStack.Children.Add($topSub)|Out-Null
$topLeft.Children.Add($sltBadge)|Out-Null
$topLeft.Children.Add($topTitleStack)|Out-Null
$topLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$topGrid.Children.Add($topLeft)|Out-Null

$topRight = New-Object Windows.Controls.StackPanel
$topRight.Orientation = 'Horizontal'; $topRight.VerticalAlignment = 'Center'
$modePillBox = New-Object Windows.Controls.Border
$modePillBox.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$modePillBox.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$modePillBox.BorderThickness = [Windows.Thickness]::new(1)
$modePillBox.CornerRadius = [Windows.CornerRadius]::new(12)
$modePillBox.Padding = [Windows.Thickness]::new(3)
$modePillRow = New-Object Windows.Controls.StackPanel; $modePillRow.Orientation = 'Horizontal'

$btnBackupMode = New-Object Windows.Controls.Border
$btnBackupMode.CornerRadius = [Windows.CornerRadius]::new(9); $btnBackupMode.Padding = [Windows.Thickness]::new(14,6,14,6); $btnBackupMode.Cursor = 'Hand'
$lblBackupMode = New-Object Windows.Controls.TextBlock; $lblBackupMode.Text = 'BACKUP MASTER (00-09)'; $lblBackupMode.FontSize = 11.5; $lblBackupMode.FontWeight = 'Bold'
$btnBackupMode.Child = $lblBackupMode

$btnRestoreMode = New-Object Windows.Controls.Border
$btnRestoreMode.CornerRadius = [Windows.CornerRadius]::new(9); $btnRestoreMode.Padding = [Windows.Thickness]::new(14,6,14,6); $btnRestoreMode.Cursor = 'Hand'; $btnRestoreMode.Margin = [Windows.Thickness]::new(4,0,0,0)
$lblRestoreMode = New-Object Windows.Controls.TextBlock; $lblRestoreMode.Text = 'RESTORE DEPLOY (01-07)'; $lblRestoreMode.FontSize = 11.5; $lblRestoreMode.FontWeight = 'Bold'
$btnRestoreMode.Child = $lblRestoreMode

$script:BRTopBackupBtn = $btnBackupMode; $script:BRTopBackupLbl = $lblBackupMode
$script:BRTopRestoreBtn = $btnRestoreMode; $script:BRTopRestoreLbl = $lblRestoreMode

$btnBackupMode.Add_MouseLeftButtonUp({
    $script:BRMode = 'BACKUP'
    Set-SLTBRBanner 'BACKUP MASTER mode opened (Stages 00 to 09).'
    Update-SLTBRVisuals
})
$btnRestoreMode.Add_MouseLeftButtonUp({
    $script:BRMode = 'RESTORE'
    Set-SLTBRBanner 'RESTORE DEPLOY mode opened (Stages 01 to 07).'
    Update-SLTBRVisuals
})

$modePillRow.Children.Add($btnBackupMode)|Out-Null
$modePillRow.Children.Add($btnRestoreMode)|Out-Null
$modePillBox.Child = $modePillRow

$donePill = New-Object Windows.Controls.Border
$donePill.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
$donePill.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
$donePill.BorderThickness = [Windows.Thickness]::new(1); $donePill.CornerRadius = [Windows.CornerRadius]::new(10)
$donePill.Padding = [Windows.Thickness]::new(12,6,12,6); $donePill.Margin = [Windows.Thickness]::new(10,0,0,0)
$doneRow = New-Object Windows.Controls.StackPanel; $doneRow.Orientation = 'Horizontal'; $doneRow.VerticalAlignment = 'Center'
$doneDot = New-Object Windows.Shapes.Ellipse; $doneDot.Width = 8; $doneDot.Height = 8; $doneDot.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'SLTStatusOk'); $doneDot.Margin = [Windows.Thickness]::new(0,0,6,0); $doneDot.VerticalAlignment = 'Center'
$doneTxt = New-Object Windows.Controls.TextBlock; $doneTxt.Text = '1/10 DONE'; $doneTxt.FontSize = 11.5; $doneTxt.FontWeight = 'Bold'; $doneTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$script:BRTopDoneLbl = $doneTxt
$doneRow.Children.Add($doneDot)|Out-Null; $doneRow.Children.Add($doneTxt)|Out-Null
$donePill.Child = $doneRow

$topRight.Children.Add($modePillBox)|Out-Null
$topRight.Children.Add($donePill)|Out-Null
$topRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$topGrid.Children.Add($topRight)|Out-Null
$topBar.Child = $topGrid
$factoryRoot.Children.Add($topBar)|Out-Null

# --- ROW 1: THIN FULL-WIDTH PROGRESS STRIP (4px) ---
$progStripGrid = New-Object Windows.Controls.Grid
$progStripGrid.Height = 4
$progStripGrid.SetResourceReference([Windows.Controls.Grid]::BackgroundProperty, 'CardDeep')
$psC0 = New-Object Windows.Controls.ColumnDefinition; $psC0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$psC1 = New-Object Windows.Controls.ColumnDefinition; $psC1.Width = New-Object Windows.GridLength(9, [Windows.GridUnitType]::Star)
$progStripGrid.ColumnDefinitions.Add($psC0)|Out-Null
$progStripGrid.ColumnDefinitions.Add($psC1)|Out-Null
$progFillRect = New-Object Windows.Controls.Border
$progFillRect.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
$progFillRect.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$progStripGrid.Children.Add($progFillRect)|Out-Null
$script:BRTopProgressCol0 = $psC0; $script:BRTopProgressCol1 = $psC1
$progStripGrid.SetValue([Windows.Controls.Grid]::RowProperty, 1)
$factoryRoot.Children.Add($progStripGrid)|Out-Null

# --- ROW 2: MAIN SPLIT BODY (Left 310px Stage Sidebar + Right Stage Detail Workspace) ---
$splitBody = New-Object Windows.Controls.Grid
$sbC0 = New-Object Windows.Controls.ColumnDefinition; $sbC0.Width = New-Object Windows.GridLength(310)
$sbC1 = New-Object Windows.Controls.ColumnDefinition; $sbC1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$splitBody.ColumnDefinitions.Add($sbC0)|Out-Null
$splitBody.ColumnDefinitions.Add($sbC1)|Out-Null
$splitBody.SetValue([Windows.Controls.Grid]::RowProperty, 2)

# LEFT 310px STAGE SIDEBAR
$stageSidebar = New-Object Windows.Controls.Border
$stageSidebar.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'SidebarBg')
$stageSidebar.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SidebarBorder')
$stageSidebar.BorderThickness = [Windows.Thickness]::new(0,0,1,0)
$stageSidebar.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$sideDock = New-Object Windows.Controls.DockPanel

# Top strip of Stage Sidebar
$sideTopBdr = New-Object Windows.Controls.Border
$sideTopBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$sideTopBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SidebarBorder')
$sideTopBdr.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
$sideTopBdr.Padding = [Windows.Thickness]::new(12,7,12,7)
[Windows.Controls.DockPanel]::SetDock($sideTopBdr, 'Top')
$sideTopGrid = New-Object Windows.Controls.Grid
$stC0 = New-Object Windows.Controls.ColumnDefinition; $stC0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$stC1 = New-Object Windows.Controls.ColumnDefinition; $stC1.Width = [Windows.GridLength]::Auto
$sideTopGrid.ColumnDefinitions.Add($stC0)|Out-Null; $sideTopGrid.ColumnDefinitions.Add($stC1)|Out-Null
$sideHdrTxt = New-Object Windows.Controls.TextBlock
$sideHdrTxt.Text = 'STAGES - CLICK TO OPEN'
$sideHdrTxt.FontSize = 10; $sideHdrTxt.FontWeight = 'Bold'
$sideHdrTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$sideHdrTxt.VerticalAlignment = 'Center'
$sideCountBdr = New-Object Windows.Controls.Border
$sideCountBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
$sideCountBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
$sideCountBdr.BorderThickness = [Windows.Thickness]::new(1); $sideCountBdr.CornerRadius = [Windows.CornerRadius]::new(6); $sideCountBdr.Padding = [Windows.Thickness]::new(6,2,6,2)
$sideCountTxt = New-Object Windows.Controls.TextBlock; $sideCountTxt.Text = '10 STAGES'; $sideCountTxt.FontSize = 9.5; $sideCountTxt.FontWeight = 'Bold'
$sideCountTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$script:BRSideCountBadge = $sideCountTxt
$sideCountBdr.Child = $sideCountTxt
$sideCountBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$sideTopGrid.Children.Add($sideHdrTxt)|Out-Null; $sideTopGrid.Children.Add($sideCountBdr)|Out-Null
$sideTopBdr.Child = $sideTopGrid
$sideDock.Children.Add($sideTopBdr)|Out-Null

# Bottom progress footer of Stage Sidebar
$sideBotBdr = New-Object Windows.Controls.Border
$sideBotBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$sideBotBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SidebarBorder')
$sideBotBdr.BorderThickness = [Windows.Thickness]::new(0,1,0,0)
$sideBotBdr.Padding = [Windows.Thickness]::new(12,8,12,8)
[Windows.Controls.DockPanel]::SetDock($sideBotBdr, 'Bottom')
$sideBotStack = New-Object Windows.Controls.StackPanel
$sideBotRow = New-Object Windows.Controls.Grid
$sbc0 = New-Object Windows.Controls.ColumnDefinition; $sbc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$sbc1 = New-Object Windows.Controls.ColumnDefinition; $sbc1.Width = [Windows.GridLength]::Auto
$sbc2 = New-Object Windows.Controls.ColumnDefinition; $sbc2.Width = [Windows.GridLength]::Auto
$sideBotRow.ColumnDefinitions.Add($sbc0)|Out-Null; $sideBotRow.ColumnDefinitions.Add($sbc1)|Out-Null; $sideBotRow.ColumnDefinitions.Add($sbc2)|Out-Null
$sbProgLbl = New-Object Windows.Controls.TextBlock; $sbProgLbl.Text = 'Stage Progress'; $sbProgLbl.FontSize = 10.5; $sbProgLbl.FontWeight = 'SemiBold'
$sbProgLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$sbPctLbl = New-Object Windows.Controls.TextBlock; $sbPctLbl.Text = '10%'; $sbPctLbl.FontSize = 11; $sbPctLbl.FontWeight = 'Bold'; $sbPctLbl.Margin = [Windows.Thickness]::new(0,0,8,0)
$sbPctLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$script:BRSidePctLbl = $sbPctLbl
$sbPctLbl.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

$sbResetBtn = New-Object Windows.Controls.Border
$sbResetBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
$sbResetBtn.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
$sbResetBtn.BorderThickness = [Windows.Thickness]::new(1); $sbResetBtn.CornerRadius = [Windows.CornerRadius]::new(6); $sbResetBtn.Padding = [Windows.Thickness]::new(6,1,6,1); $sbResetBtn.Cursor = 'Hand'
$sbResetTxt = New-Object Windows.Controls.TextBlock; $sbResetTxt.Text = 'Reset'; $sbResetTxt.FontSize = 9.5; $sbResetTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$sbResetBtn.Child = $sbResetTxt
$sbResetBtn.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)
$sbResetBtn.Add_MouseLeftButtonUp({
    $script:BRCompletedStages = @{ 'b00' = $true }
    if (Get-Command Save-SLTBRState -ErrorAction SilentlyContinue) { Save-SLTBRState }
    Set-SLTBRBanner 'Stage completion ticks reset for new device.'
    Update-SLTBRVisuals
})
$sideBotRow.Children.Add($sbProgLbl)|Out-Null; $sideBotRow.Children.Add($sbPctLbl)|Out-Null; $sideBotRow.Children.Add($sbResetBtn)|Out-Null

$sbBarOuter = New-Object Windows.Controls.Border
$sbBarOuter.Height = 6; $sbBarOuter.CornerRadius = [Windows.CornerRadius]::new(3); $sbBarOuter.Margin = [Windows.Thickness]::new(0,6,0,0)
$sbBarOuter.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WindowBg')
$sbBarGrid = New-Object Windows.Controls.Grid
$sbg0 = New-Object Windows.Controls.ColumnDefinition; $sbg0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$sbg1 = New-Object Windows.Controls.ColumnDefinition; $sbg1.Width = New-Object Windows.GridLength(9, [Windows.GridUnitType]::Star)
$sbBarGrid.ColumnDefinitions.Add($sbg0)|Out-Null; $sbBarGrid.ColumnDefinitions.Add($sbg1)|Out-Null
$sbBarFill = New-Object Windows.Controls.Border; $sbBarFill.CornerRadius = [Windows.CornerRadius]::new(3)
$sbBarFill.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
$sbBarFill.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$sbBarGrid.Children.Add($sbBarFill)|Out-Null
$sbBarOuter.Child = $sbBarGrid
$script:BRSideProgressCol0 = $sbg0; $script:BRSideProgressCol1 = $sbg1

$sideBotStack.Children.Add($sideBotRow)|Out-Null
$sideBotStack.Children.Add($sbBarOuter)|Out-Null
$sideBotBdr.Child = $sideBotStack
$sideDock.Children.Add($sideBotBdr)|Out-Null

# Stage list container (fits all 10 stages compactly without scrolling)
$stageListPanel = New-Object Windows.Controls.StackPanel
$stageListPanel.Margin = [Windows.Thickness]::new(8,6,8,6)
$script:BRStageListPanel = $stageListPanel
$sideDock.Children.Add($stageListPanel)|Out-Null
$stageSidebar.Child = $sideDock
$splitBody.Children.Add($stageSidebar)|Out-Null

# RIGHT STAGE DETAIL WORKSPACE (Same Window, No Scroll)
$detailHost = New-Object Windows.Controls.Border
$detailHost.Padding = [Windows.Thickness]::new(18,12,18,10)
$detailHost.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$script:BRDetailHost = $detailHost
$splitBody.Children.Add($detailHost)|Out-Null
$factoryRoot.Children.Add($splitBody)|Out-Null

# --- ROW 3: BOTTOM LIVE STATUS FOOTER (26px) ---
$botFooter = New-Object Windows.Controls.Border
$botFooter.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'FooterBg')
$botFooter.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SidebarBorder')
$botFooter.BorderThickness = [Windows.Thickness]::new(0,1,0,0)
$botFooter.Padding = [Windows.Thickness]::new(16,5,16,5)
$botFooter.SetValue([Windows.Controls.Grid]::RowProperty, 3)

$bfGrid = New-Object Windows.Controls.Grid
$bfC0 = New-Object Windows.Controls.ColumnDefinition; $bfC0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$bfC1 = New-Object Windows.Controls.ColumnDefinition; $bfC1.Width = [Windows.GridLength]::Auto
$bfGrid.ColumnDefinitions.Add($bfC0)|Out-Null; $bfGrid.ColumnDefinitions.Add($bfC1)|Out-Null

$bfLeft = New-Object Windows.Controls.StackPanel; $bfLeft.Orientation = 'Horizontal'; $bfLeft.VerticalAlignment = 'Center'
$bfBrand = New-Object Windows.Controls.TextBlock
$bfBrand.Text = 'SLT Smart PC Boost Factory v1.0.0   |   '
$bfBrand.FontSize = 10; $bfBrand.FontWeight = 'Bold'
$bfBrand.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$bfStatus = New-Object Windows.Controls.TextBlock
$bfStatus.Text = 'Stage 00 opened - Click any stage on the left to open its options in this same window.'
$bfStatus.FontSize = 10
$bfStatus.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$script:BRFooterStatusLbl = $bfStatus
$bfLeft.Children.Add($bfBrand)|Out-Null; $bfLeft.Children.Add($bfStatus)|Out-Null
$bfLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$bfRight = New-Object Windows.Controls.StackPanel; $bfRight.Orientation = 'Horizontal'; $bfRight.VerticalAlignment = 'Center'
$bfDot = New-Object Windows.Shapes.Ellipse; $bfDot.Width = 7; $bfDot.Height = 7; $bfDot.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'SLTStatusOk'); $bfDot.Margin = [Windows.Thickness]::new(0,0,6,0); $bfDot.VerticalAlignment = 'Center'
$bfReady = New-Object Windows.Controls.TextBlock; $bfReady.Text = 'READY   |   '; $bfReady.FontSize = 10; $bfReady.FontWeight = 'Bold'; $bfReady.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
$bfStageName = New-Object Windows.Controls.TextBlock; $bfStageName.Text = '00 Windows 11 Download'; $bfStageName.FontSize = 10; $bfStageName.FontWeight = 'SemiBold'; $bfStageName.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$script:BRFooterStageLbl = $bfStageName
$bfRight.Children.Add($bfDot)|Out-Null; $bfRight.Children.Add($bfReady)|Out-Null; $bfRight.Children.Add($bfStageName)|Out-Null
$bfRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

$bfGrid.Children.Add($bfLeft)|Out-Null; $bfGrid.Children.Add($bfRight)|Out-Null
$botFooter.Child = $bfGrid
$factoryRoot.Children.Add($botFooter)|Out-Null

$page.Children.Add($factoryRoot)|Out-Null

# =====================================================================
# DYNAMIC RENDERERS: LEFT STAGE LIST & RIGHT STAGE DETAIL PANEL
# =====================================================================
function Render-SLTBRStageList {
    if ($null -eq $script:BRStageListPanel) { return }
    $script:BRStageListPanel.Children.Clear()
    $stages = if ($script:BRMode -eq 'BACKUP') { $script:BRBackupStages } else { $script:BRRestoreStages }
    $activeIdx = if ($script:BRMode -eq 'BACKUP') { $script:BRBackupIndex } else { $script:BRRestoreIndex }
    $chkSym = [char]0x2713

    for ($idx = 0; $idx -lt $stages.Count; $idx++) {
        $st = $stages[$idx]
        $isActive = ($idx -eq $activeIdx)
        $isDone = ($script:BRCompletedStages.ContainsKey($st.id) -and [bool]$script:BRCompletedStages[$st.id])

        $rowBdr = New-Object Windows.Controls.Border
        $rowBdr.CornerRadius = [Windows.CornerRadius]::new(10)
        $rowBdr.Padding = [Windows.Thickness]::new(10,6,10,6)
        $rowBdr.Margin = [Windows.Thickness]::new(0,2,0,2)
        $rowBdr.Cursor = 'Hand'
        $rowBdr.Tag = $idx

        if ($isActive) {
            $rowBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
            $rowBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            $rowBdr.BorderThickness = [Windows.Thickness]::new(3,1,1,1)
        } else {
            $rowBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
            $rowBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            $rowBdr.BorderThickness = [Windows.Thickness]::new(1)
        }

        $rGrid = New-Object Windows.Controls.Grid
        $rc0 = New-Object Windows.Controls.ColumnDefinition; $rc0.Width = [Windows.GridLength]::Auto
        $rc1 = New-Object Windows.Controls.ColumnDefinition; $rc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $rc2 = New-Object Windows.Controls.ColumnDefinition; $rc2.Width = [Windows.GridLength]::Auto
        $rGrid.ColumnDefinitions.Add($rc0)|Out-Null; $rGrid.ColumnDefinitions.Add($rc1)|Out-Null; $rGrid.ColumnDefinitions.Add($rc2)|Out-Null

        # 26px Circle Number / Tick
        $circ = New-Object Windows.Controls.Border
        $circ.Width = 26; $circ.Height = 26; $circ.CornerRadius = [Windows.CornerRadius]::new(13)
        $circ.Margin = [Windows.Thickness]::new(0,0,10,0); $circ.VerticalAlignment = 'Center'
        $circTxt = New-Object Windows.Controls.TextBlock
        $circTxt.FontSize = 11; $circTxt.FontWeight = 'Bold'
        $circTxt.HorizontalAlignment = 'Center'; $circTxt.VerticalAlignment = 'Center'
        if ($isDone) {
            $circ.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'SLTStatusOk')
            $circTxt.Text = "$chkSym"
            $circTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
        } elseif ($isActive) {
            $circ.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
            $circTxt.Text = $st.no
            $circTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
        } else {
            $circ.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $circ.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
            $circ.BorderThickness = [Windows.Thickness]::new(1)
            $circTxt.Text = $st.no
            $circTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        }
        $circ.Child = $circTxt
        $circ.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
        $rGrid.Children.Add($circ)|Out-Null

        # Middle Title + Badge
        $midStack = New-Object Windows.Controls.StackPanel; $midStack.VerticalAlignment = 'Center'
        $titleRow = New-Object Windows.Controls.StackPanel; $titleRow.Orientation = 'Horizontal'
        $tLbl = New-Object Windows.Controls.TextBlock
        $tLbl.Text = $st.title; $tLbl.FontSize = 12; $tLbl.FontWeight = $(if ($isActive) { 'Bold' } else { 'SemiBold' })
        $tLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($isActive) { 'TextAccent' } else { 'BtnText' }))
        $titleRow.Children.Add($tLbl)|Out-Null
        if ($st.critical) {
            $critDot = New-Object Windows.Shapes.Ellipse
            $critDot.Width = 7; $critDot.Height = 7; $critDot.Margin = [Windows.Thickness]::new(6,0,0,0); $critDot.VerticalAlignment = 'Center'
            $critDot.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'SLTStatusError')
            $titleRow.Children.Add($critDot)|Out-Null
        }

        $subRow = New-Object Windows.Controls.StackPanel; $subRow.Orientation = 'Horizontal'; $subRow.Margin = [Windows.Thickness]::new(0,1,0,0)
        $noLbl = New-Object Windows.Controls.TextBlock
        $noLbl.Text = ('No. ' + $st.no); $noLbl.FontSize = 9.5
        $noLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $subRow.Children.Add($noLbl)|Out-Null
        if (-not [string]::IsNullOrWhiteSpace($st.badge)) {
            $bdg = New-Object Windows.Controls.Border
            $bdg.CornerRadius = [Windows.CornerRadius]::new(4); $bdg.Padding = [Windows.Thickness]::new(5,0,5,0); $bdg.Margin = [Windows.Thickness]::new(6,0,0,0)
            $bdg.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $bdg.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, $(if ($st.critical) { 'SLTStatusError' } else { 'CardBorder' }))
            $bdg.BorderThickness = [Windows.Thickness]::new(1)
            $bdgTxt = New-Object Windows.Controls.TextBlock
            $bdgTxt.Text = $st.badge; $bdgTxt.FontSize = 8.5; $bdgTxt.FontWeight = 'Bold'
            $bdgTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($st.critical) { 'SLTStatusError' } else { 'TextAccent' }))
            $bdg.Child = $bdgTxt
            $subRow.Children.Add($bdg)|Out-Null
        }
        $midStack.Children.Add($titleRow)|Out-Null
        $midStack.Children.Add($subRow)|Out-Null
        $midStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
        $rGrid.Children.Add($midStack)|Out-Null

        # Right Done Tick
        if ($isDone) {
            $rtTick = New-Object Windows.Controls.Border
            $rtTick.Width = 18; $rtTick.Height = 18; $rtTick.CornerRadius = [Windows.CornerRadius]::new(9)
            $rtTick.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $rtTick.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SLTStatusOk')
            $rtTick.BorderThickness = [Windows.Thickness]::new(1); $rtTick.VerticalAlignment = 'Center'
            $rtTxt = New-Object Windows.Controls.TextBlock
            $rtTxt.Text = "$chkSym"; $rtTxt.FontSize = 10; $rtTxt.FontWeight = 'Bold'
            $rtTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
            $rtTxt.HorizontalAlignment = 'Center'; $rtTxt.VerticalAlignment = 'Center'
            $rtTick.Child = $rtTxt
            $rtTick.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)
            $rGrid.Children.Add($rtTick)|Out-Null
        }

        $rowBdr.Child = $rGrid
        $rowBdr.Add_MouseLeftButtonUp({
            param($s, $e)
            $clickedIdx = [int]$s.Tag
            if ($script:BRMode -eq 'BACKUP') {
                $script:BRBackupIndex = $clickedIdx
                $stObj = $script:BRBackupStages[$clickedIdx]
            } else {
                $script:BRRestoreIndex = $clickedIdx
                $stObj = $script:BRRestoreStages[$clickedIdx]
            }
            Set-SLTBRBanner ($stObj.no + ' ' + $stObj.title + ' opened in same window')
            Update-SLTBRVisuals
        })
        $script:BRStageListPanel.Children.Add($rowBdr)|Out-Null
    }
}

function New-SLTBRChecklistGrid([object[]]$Items, [int]$Columns=2) {
    $groups = [ordered]@{}
    foreach ($it in $Items) {
        $gName = if ($it.ContainsKey('group') -and -not [string]::IsNullOrWhiteSpace($it.group)) { [string]$it.group } else { 'Options' }
        if (-not $groups.Contains($gName)) { $groups[$gName] = @() }
        $groups[$gName] += $it
    }
    $uGrid = New-Object Windows.Controls.Primitives.UniformGrid
    $uGrid.Columns = $Columns
    foreach ($gKey in $groups.Keys) {
        $gItems = $groups[$gKey]
        $gCard = New-Object Windows.Controls.Border
        $gCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $gCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $gCard.BorderThickness = [Windows.Thickness]::new(1)
        $gCard.CornerRadius = [Windows.CornerRadius]::new(10)
        $gCard.Padding = [Windows.Thickness]::new(11,8,11,8)
        $gCard.Margin = [Windows.Thickness]::new(4)

        $gStack = New-Object Windows.Controls.StackPanel
        $gHdrGrid = New-Object Windows.Controls.Grid; $gHdrGrid.Margin = [Windows.Thickness]::new(0,0,0,5)
        $gc0 = New-Object Windows.Controls.ColumnDefinition; $gc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $gc1 = New-Object Windows.Controls.ColumnDefinition; $gc1.Width = [Windows.GridLength]::Auto
        $gHdrGrid.ColumnDefinitions.Add($gc0)|Out-Null; $gHdrGrid.ColumnDefinitions.Add($gc1)|Out-Null
        $gTitle = New-Object Windows.Controls.TextBlock
        $gTitle.Text = $gKey.ToUpper(); $gTitle.FontSize = 10; $gTitle.FontWeight = 'Bold'
        $gTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $gCnt = New-Object Windows.Controls.TextBlock
        $gCnt.Text = ([string]$gItems.Count + ' items'); $gCnt.FontSize = 9.5
        $gCnt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $gCnt.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
        $gHdrGrid.Children.Add($gTitle)|Out-Null; $gHdrGrid.Children.Add($gCnt)|Out-Null
        $gStack.Children.Add($gHdrGrid)|Out-Null

        foreach ($m in $gItems) {
            $isItemApplied = ($null -ne $script:BROptAppliedItems -and $script:BROptAppliedItems.ContainsKey($m.id) -and [bool]$script:BROptAppliedItems[$m.id])
            $cb = New-Object Windows.Controls.CheckBox
            $cb.Content = $(if ($isItemApplied) { ([char]0x2713 + ' ' + $m.label + ' [Done]') } else { $m.label })
            $cb.Tag = $m.id
            $cb.IsChecked = [bool]$script:BRChecks[$m.id]
            $cb.FontSize = 11.2
            $cb.Margin = [Windows.Thickness]::new(0,2,0,2)
            if ($isItemApplied) {
                $cb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'SLTStatusOk')
                $cb.FontWeight = 'SemiBold'
            } else {
                $cb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'TextPrimary')
            }
            if ($m.ContainsKey('tip') -and -not [string]::IsNullOrWhiteSpace($m.tip)) {
                $cb.ToolTip = $m.tip
            } else {
                $cb.ToolTip = ('Enable or skip: ' + $m.label + ' (Selected by default; uncheck to skip).')
            }
            $cb.Add_Checked({
                param($s,$e)
                $script:BRChecks[[string]$s.Tag] = $true
                try {
                    if ($null -ne $script:BROptSelectedCountLbl) {
                        $tItems = @(Get-SLTBROptItemsForTier $script:BROptSubTab)
                        $cNow = @($tItems | Where-Object { $script:BRChecks[$_.id] }).Count
                        $script:BROptSelectedCountLbl.Text = ("$cNow selected / $($tItems.Count) total  |  All selected by default (uncheck to keep)")
                    }
                } catch {}
            })
            $cb.Add_Unchecked({
                param($s,$e)
                $script:BRChecks[[string]$s.Tag] = $false
                try {
                    if ($null -ne $script:BROptSelectedCountLbl) {
                        $tItems = @(Get-SLTBROptItemsForTier $script:BROptSubTab)
                        $cNow = @($tItems | Where-Object { $script:BRChecks[$_.id] }).Count
                        $script:BROptSelectedCountLbl.Text = ("$cNow selected / $($tItems.Count) total  |  All selected by default (uncheck to keep)")
                    }
                } catch {}
            })
            $gStack.Children.Add($cb)|Out-Null
        }
        $gCard.Child = $gStack
        $uGrid.Children.Add($gCard)|Out-Null
    }
    return $uGrid
}

function Render-SLTBRDetail {
    if ($null -eq $script:BRDetailHost) { return }
    $stages = if ($script:BRMode -eq 'BACKUP') { $script:BRBackupStages } else { $script:BRRestoreStages }
    $activeIdx = if ($script:BRMode -eq 'BACKUP') { $script:BRBackupIndex } else { $script:BRRestoreIndex }
    $st = $stages[$activeIdx]
    $isDone = ($script:BRCompletedStages.ContainsKey($st.id) -and [bool]$script:BRCompletedStages[$st.id])
    $chkSym = [char]0x2713

    if ($null -ne $script:BRFooterStageLbl) {
        $script:BRFooterStageLbl.Text = ($st.no + ' ' + $st.title)
    }

    $mainStack = New-Object Windows.Controls.StackPanel

    # 1. Stage Header Row (Number Badge + Title + Instruction + Prev/Next/Mark Done)
    $hdrGrid = New-Object Windows.Controls.Grid
    $hdrGrid.Margin = [Windows.Thickness]::new(0,0,0,10)
    $hc0 = New-Object Windows.Controls.ColumnDefinition; $hc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $hc1 = New-Object Windows.Controls.ColumnDefinition; $hc1.Width = [Windows.GridLength]::Auto
    $hdrGrid.ColumnDefinitions.Add($hc0)|Out-Null; $hdrGrid.ColumnDefinitions.Add($hc1)|Out-Null

    $hdrLeft = New-Object Windows.Controls.StackPanel; $hdrLeft.Orientation = 'Horizontal'; $hdrLeft.VerticalAlignment = 'Center'
    $noBox = New-Object Windows.Controls.Border
    $noBox.Width = 36; $noBox.Height = 36; $noBox.CornerRadius = [Windows.CornerRadius]::new(10); $noBox.Margin = [Windows.Thickness]::new(0,0,12,0)
    $noBox.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
    $noBoxTxt = New-Object Windows.Controls.TextBlock
    $noBoxTxt.Text = $st.no; $noBoxTxt.FontSize = 14; $noBoxTxt.FontWeight = 'Bold'
    $noBoxTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
    $noBoxTxt.HorizontalAlignment = 'Center'; $noBoxTxt.VerticalAlignment = 'Center'
    $noBox.Child = $noBoxTxt

    $hdrTextStack = New-Object Windows.Controls.StackPanel; $hdrTextStack.VerticalAlignment = 'Center'
    $stTitleTb = New-Object Windows.Controls.TextBlock
    $stTitleTb.Text = ($st.title + '   [Stage ' + $st.no + ']')
    $stTitleTb.FontSize = 16; $stTitleTb.FontWeight = 'Bold'
    $stTitleTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
    $stInstTb = New-Object Windows.Controls.TextBlock
    $stInstTb.Text = $st.instruction
    $stInstTb.FontSize = 11.5; $stInstTb.TextWrapping = 'Wrap'; $stInstTb.Margin = [Windows.Thickness]::new(0,2,0,0)
    $stInstTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $hdrTextStack.Children.Add($stTitleTb)|Out-Null; $hdrTextStack.Children.Add($stInstTb)|Out-Null
    $hdrLeft.Children.Add($noBox)|Out-Null; $hdrLeft.Children.Add($hdrTextStack)|Out-Null
    $hdrLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
    $hdrGrid.Children.Add($hdrLeft)|Out-Null

    $hdrRight = New-Object Windows.Controls.StackPanel; $hdrRight.Orientation = 'Horizontal'; $hdrRight.VerticalAlignment = 'Center'
    $btnPrev = New-Object Windows.Controls.Button
    $btnPrev.Content = '< Prev'; $btnPrev.Style = $script:Window.FindResource('OutlineButton')
    $btnPrev.MinHeight = 32; $btnPrev.Padding = [Windows.Thickness]::new(10,4,10,4)
    $btnPrev.Add_Click({
        if ($script:BRMode -eq 'BACKUP') {
            if ($script:BRBackupIndex -gt 0) { $script:BRBackupIndex-- }
        } else {
            if ($script:BRRestoreIndex -gt 0) { $script:BRRestoreIndex-- }
        }
        Update-SLTBRVisuals
    })
    $btnNext = New-Object Windows.Controls.Button
    $btnNext.Content = 'Next >'; $btnNext.Style = $script:Window.FindResource('OutlineButton')
    $btnNext.MinHeight = 32; $btnNext.Padding = [Windows.Thickness]::new(10,4,10,4)
    $btnNext.Add_Click({
        if ($script:BRMode -eq 'BACKUP') {
            if ($script:BRBackupIndex -lt ($script:BRBackupStages.Count - 1)) { $script:BRBackupIndex++ }
        } else {
            if ($script:BRRestoreIndex -lt ($script:BRRestoreStages.Count - 1)) { $script:BRRestoreIndex++ }
        }
        Update-SLTBRVisuals
    })
    $btnMark = New-Object Windows.Controls.Button
    $btnMark.Content = $(if ($isDone) { "Completed $chkSym" } else { 'Mark Done' })
    $btnMark.Tag = $st.id
    $btnMark.Style = $script:Window.FindResource('ActionButton')
    $btnMark.MinHeight = 32; $btnMark.Padding = [Windows.Thickness]::new(14,4,14,4)
    if ($isDone) {
        $btnMark.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnMark.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
    }
    $btnMark.Add_Click({
        param($s,$e)
        Toggle-SLTBRStageDone ([string]$s.Tag)
    })
    $hdrRight.Children.Add($btnPrev)|Out-Null; $hdrRight.Children.Add($btnNext)|Out-Null; $hdrRight.Children.Add($btnMark)|Out-Null
    $hdrRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $hdrGrid.Children.Add($hdrRight)|Out-Null
    $mainStack.Children.Add($hdrGrid)|Out-Null

    # 2. Main Stage Card (Same Window, No Scroll)
    $card = New-Object Windows.Controls.Border
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $card.BorderThickness = [Windows.Thickness]::new(1)
    $card.CornerRadius = [Windows.CornerRadius]::new(14)
    $card.Padding = [Windows.Thickness]::new(16,14,16,14)
    $cardStack = New-Object Windows.Controls.StackPanel

    if ($st.id -eq 'b00') {
        # --- STAGE 00: WINDOWS 11 OFFICIAL DOWNLOAD ---
        $b00Box = New-Object Windows.Controls.Border
        $b00Box.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $b00Box.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $b00Box.BorderThickness = [Windows.Thickness]::new(1); $b00Box.CornerRadius = [Windows.CornerRadius]::new(12); $b00Box.Padding = [Windows.Thickness]::new(16,14,16,14)
        $b00Sp = New-Object Windows.Controls.StackPanel
        $b00T1 = New-Object Windows.Controls.TextBlock
        $b00T1.Text = '00. Windows 11 Official ISO & Media Creation Tool'
        $b00T1.FontSize = 14.5; $b00T1.FontWeight = 'Bold'
        $b00T1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $b00T2 = New-Object Windows.Controls.TextBlock
        $b00T2.Text = "1. Download genuine Windows 11 ISO only from Microsoft official link below.`n2. Install Windows 11 cleanly on your master machine without connecting Wi-Fi.`n3. At the first OOBE region screen, press Ctrl + Shift + F3 to enter Audit Mode.`n4. Immediately proceed to Stage 01 (Store OFF) BEFORE connecting internet!"
        $b00T2.FontSize = 12; $b00T2.TextWrapping = 'Wrap'; $b00T2.Margin = [Windows.Thickness]::new(0,8,0,14)
        $b00T2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')

        $b00BtnRow = New-Object Windows.Controls.WrapPanel
        $btnOpenMs = New-Object Windows.Controls.Button
        $btnOpenMs.Content = 'Open Official Microsoft Site ->'
        $btnOpenMs.Style = $script:Window.FindResource('ActionButton')
        $btnOpenMs.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnOpenMs.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnOpenMs.Add_Click({ Invoke-SLTBRRunStage 'b00' })

        $btnCopyUrl = New-Object Windows.Controls.Button
        $btnCopyUrl.Content = 'Copy Official URL'
        $btnCopyUrl.Style = $script:Window.FindResource('OutlineButton')
        $btnCopyUrl.Add_Click({
            try { [Windows.Clipboard]::SetText('https://www.microsoft.com/en-us/software-download/windows11') } catch {}
            Set-SLTBRBanner 'Copied Microsoft Windows 11 download URL to clipboard.'
        })

        $btnDone00 = New-Object Windows.Controls.Button
        $btnDone00.Content = "I Downloaded ISO $chkSym (Go to Stage 01)"
        $btnDone00.Style = $script:Window.FindResource('OutlineButton')
        $btnDone00.Add_Click({
            Toggle-SLTBRStageDone 'b00' -ForceDone
            $script:BRBackupIndex = 1
            Set-SLTBRBanner 'Stage 00 marked Done -> Opened Stage 01 (Store OFF).'
            Update-SLTBRVisuals
        })
        $b00BtnRow.Children.Add($btnOpenMs)|Out-Null; $b00BtnRow.Children.Add($btnCopyUrl)|Out-Null; $b00BtnRow.Children.Add($btnDone00)|Out-Null
        $b00Sp.Children.Add($b00T1)|Out-Null; $b00Sp.Children.Add($b00T2)|Out-Null; $b00Sp.Children.Add($b00BtnRow)|Out-Null
        $b00Box.Child = $b00Sp
        $cardStack.Children.Add($b00Box)|Out-Null

    } elseif ($st.id -eq 'b01') {
        # --- STAGE 01: STORE OFF (BEFORE INTERNET) ---
        $warnBdr = New-Object Windows.Controls.Border
        $warnBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $warnBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SLTStatusError')
        $warnBdr.BorderThickness = [Windows.Thickness]::new(1.5); $warnBdr.CornerRadius = [Windows.CornerRadius]::new(10); $warnBdr.Padding = [Windows.Thickness]::new(12,8,12,8); $warnBdr.Margin = [Windows.Thickness]::new(0,0,0,10)
        $warnTxt = New-Object Windows.Controls.TextBlock
        $warnTxt.Text = 'CRITICAL BEFORE INTERNET: Paste this in Terminal as Administrator (or click Apply Store OFF Directly below). This is necessary for Sysprep. It blocks Microsoft Store auto-updates before connecting internet to prevent bloat restoration.'
        $warnTxt.FontSize = 11.5; $warnTxt.FontWeight = 'SemiBold'; $warnTxt.TextWrapping = 'Wrap'
        $warnTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $warnBdr.Child = $warnTxt
        $cardStack.Children.Add($warnBdr)|Out-Null

        $codeBdr = New-Object Windows.Controls.Border
        $codeBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'LogBg')
        $codeBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $codeBdr.BorderThickness = [Windows.Thickness]::new(1); $codeBdr.CornerRadius = [Windows.CornerRadius]::new(10); $codeBdr.Padding = [Windows.Thickness]::new(12,10,12,10)
        $codeStack = New-Object Windows.Controls.StackPanel
        $codeHdr = New-Object Windows.Controls.TextBlock
        $codeHdr.Text = 'PowerShell (Administrator)   |   REGISTRY + SERVICE BLOCK'
        $codeHdr.FontSize = 10; $codeHdr.FontWeight = 'Bold'; $codeHdr.Margin = [Windows.Thickness]::new(0,0,0,6)
        $codeHdr.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $codeBox = New-Object Windows.Controls.TextBox
        $codeBox.Text = $script:BRStoreGuardCode
        $codeBox.IsReadOnly = $true; $codeBox.FontFamily = 'Consolas'; $codeBox.FontSize = 11.5
        $codeBox.BorderThickness = [Windows.Thickness]::new(0)
        $codeBox.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'LogBg')
        $codeBox.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'LogFg')
        $codeStack.Children.Add($codeHdr)|Out-Null; $codeStack.Children.Add($codeBox)|Out-Null
        $codeBdr.Child = $codeStack
        $cardStack.Children.Add($codeBdr)|Out-Null

        $b01Btns = New-Object Windows.Controls.WrapPanel; $b01Btns.Margin = [Windows.Thickness]::new(0,12,0,0)
        $btnCopyCode = New-Object Windows.Controls.Button
        $btnCopyCode.Content = 'Copy Code'
        $btnCopyCode.Style = $script:Window.FindResource('OutlineButton')
        $btnCopyCode.Add_Click({
            try { [Windows.Clipboard]::SetText($script:BRStoreGuardCode) } catch {}
            Set-SLTBRBanner 'Copied Store OFF PowerShell commands to clipboard!'
        })

        $btnApplyDirect = New-Object Windows.Controls.Button
        $btnApplyDirect.Content = "Apply Store OFF Directly (1-Click Admin) $chkSym"
        $btnApplyDirect.Style = $script:Window.FindResource('ActionButton')
        $btnApplyDirect.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnApplyDirect.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnApplyDirect.Add_Click({ Invoke-SLTBRRunStage 'b01' })

        $btnOpenTerm = New-Object Windows.Controls.Button
        $btnOpenTerm.Content = 'Open Admin PowerShell'
        $btnOpenTerm.Style = $script:Window.FindResource('OutlineButton')
        $btnOpenTerm.Add_Click({
            try { Start-Process -FilePath 'powershell.exe' -Verb RunAs } catch {}
        })

        $btnMark01 = New-Object Windows.Controls.Button
        $btnMark01.Content = "Mark Applied $chkSym (Next Stage)"
        $btnMark01.Style = $script:Window.FindResource('OutlineButton')
        $btnMark01.Add_Click({
            Toggle-SLTBRStageDone 'b01' -ForceDone
            $script:BRBackupIndex = 2
            Update-SLTBRVisuals
        })
        foreach ($b in @($btnCopyCode,$btnApplyDirect,$btnOpenTerm,$btnMark01)) { $b01Btns.Children.Add($b)|Out-Null }
        $cardStack.Children.Add($b01Btns)|Out-Null

    } elseif ($st.id -eq 'b05') {
        # --- STAGE 05: OPTIMIZATION HUB (4 INNER TABS IN SAME WINDOW) ---
        $tabGrid = New-Object Windows.Controls.Primitives.UniformGrid
        $tabGrid.Columns = 4; $tabGrid.Margin = [Windows.Thickness]::new(0,0,0,8)
        foreach ($tr in $script:BROptTiers) {
            $isTabActive = ($script:BROptSubTab -eq $tr.id)
            $tBdr = New-Object Windows.Controls.Border
            $tBdr.CornerRadius = [Windows.CornerRadius]::new(10); $tBdr.Padding = [Windows.Thickness]::new(10,6,10,6); $tBdr.Margin = [Windows.Thickness]::new(3,0,3,0); $tBdr.Cursor = 'Hand'
            $tBdr.Tag = $tr.id
            if ($isTabActive) {
                $tBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
                $tBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
                $tBdr.BorderThickness = [Windows.Thickness]::new(1.5)
            } else {
                $tBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
                $tBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
                $tBdr.BorderThickness = [Windows.Thickness]::new(1)
            }
            $tSp = New-Object Windows.Controls.StackPanel
            $tL1 = New-Object Windows.Controls.TextBlock; $tL1.Text = $tr.label; $tL1.FontSize = 12; $tL1.FontWeight = 'Bold'
            $tL1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($isTabActive) { 'BtnSelectedText' } else { 'BtnText' }))
            $tL2 = New-Object Windows.Controls.TextBlock; $tL2.Text = $tr.sub; $tL2.FontSize = 9.5
            $tL2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($isTabActive) { 'BtnSelectedText' } else { 'TextSecondary' }))
            $tSp.Children.Add($tL1)|Out-Null; $tSp.Children.Add($tL2)|Out-Null
            $tBdr.Child = $tSp
            $tBdr.Add_MouseLeftButtonUp({
                param($s,$e)
                $script:BROptSubTab = [string]$s.Tag
                Set-SLTBRBanner ('Optimization Hub switched to ' + $script:BROptSubTab + ' mode.')
                Render-SLTBRDetail
            })
            $tabGrid.Children.Add($tBdr)|Out-Null
        }
        $cardStack.Children.Add($tabGrid)|Out-Null

        # Tier Info + Warning Banner for EXTREME 4GB
        $activeTierObj = $script:BROptTiers | Where-Object { $_.id -eq $script:BROptSubTab } | Select-Object -First 1
        $tierBanner = New-Object Windows.Controls.Border
        $tierBanner.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $tierBanner.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, $(if ($script:BROptSubTab -eq 'EXTREME') { 'SLTStatusError' } else { 'CardBorder' }))
        $tierBanner.BorderThickness = [Windows.Thickness]::new(1); $tierBanner.CornerRadius = [Windows.CornerRadius]::new(8); $tierBanner.Padding = [Windows.Thickness]::new(10,6,10,6); $tierBanner.Margin = [Windows.Thickness]::new(4,0,4,6)
        $tierTxt = New-Object Windows.Controls.TextBlock
        $tierTxt.Text = $(if ($script:BROptSubTab -eq 'EXTREME') { 'WARNING (4GB LOW-END LAPTOPS ONLY): ' + $activeTierObj.desc } else { $activeTierObj.label + ' MODE: ' + $activeTierObj.desc })
        $tierTxt.FontSize = 11; $tierTxt.FontWeight = 'SemiBold'; $tierTxt.TextWrapping = 'Wrap'
        $tierTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($script:BROptSubTab -eq 'EXTREME') { 'SLTStatusWarn' } else { 'TextPrimary' }))
        $tierBanner.Child = $tierTxt
        $cardStack.Children.Add($tierBanner)|Out-Null

        # Checklist Grid for Active Tier (3 columns for SMART/ULTRA/EXTREME so all items fit in 1 window, 2 columns for COMPACT)
        $tierItems = @(Get-SLTBROptItemsForTier $script:BROptSubTab)
        $cols = if ($tierItems.Count -gt 12) { 3 } else { 2 }
        $chkScroller = New-Object Windows.Controls.ScrollViewer
        $chkScroller.MaxHeight = 310; $chkScroller.VerticalScrollBarVisibility = 'Auto'; $chkScroller.HorizontalScrollBarVisibility = 'Disabled'
        $chkScroller.Content = (New-SLTBRChecklistGrid $tierItems $cols)
        $cardStack.Children.Add($chkScroller)|Out-Null

        # Bottom Action Row for Stage 05 Optimization Hub
        $selCnt = @($tierItems | Where-Object { $script:BRChecks[$_.id] }).Count
        $actBar = New-Object Windows.Controls.Grid; $actBar.Margin = [Windows.Thickness]::new(4,8,4,0)
        $ac0 = New-Object Windows.Controls.ColumnDefinition; $ac0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $ac1 = New-Object Windows.Controls.ColumnDefinition; $ac1.Width = [Windows.GridLength]::Auto
        $actBar.ColumnDefinitions.Add($ac0)|Out-Null; $actBar.ColumnDefinitions.Add($ac1)|Out-Null
        $doneInTier = @($tierItems | Where-Object { $null -ne $script:BROptAppliedItems -and $script:BROptAppliedItems.ContainsKey($_.id) }).Count
        $selLbl = New-Object Windows.Controls.TextBlock
        $selLbl.Text = $(if ($doneInTier -gt 0) { ("$selCnt selected / $($tierItems.Count) total  |  $doneInTier/$($tierItems.Count) Applied " + [char]0x2713) } else { ("$selCnt selected / $($tierItems.Count) total  |  All selected by default (uncheck to keep)") })
        $selLbl.FontSize = 11; $selLbl.VerticalAlignment = 'Center'
        $selLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($doneInTier -gt 0) { 'SLTStatusOk' } else { 'TextSecondary' }))
        $script:BROptSelectedCountLbl = $selLbl
        $actBar.Children.Add($selLbl)|Out-Null

        $actBtns = New-Object Windows.Controls.StackPanel; $actBtns.Orientation = 'Horizontal'
        $btnSelAll = New-Object Windows.Controls.Button; $btnSelAll.Content = 'Select All'; $btnSelAll.Style = $script:Window.FindResource('OutlineButton'); $btnSelAll.MinHeight = 32; $btnSelAll.Padding = [Windows.Thickness]::new(10,4,10,4)
        $btnSelAll.Add_Click({
            foreach ($it in (Get-SLTBROptItemsForTier $script:BROptSubTab)) { $script:BRChecks[$it.id] = $true }
            Render-SLTBRDetail
        })
        $btnUnselAll = New-Object Windows.Controls.Button; $btnUnselAll.Content = 'Uncheck All'; $btnUnselAll.Style = $script:Window.FindResource('OutlineButton'); $btnUnselAll.MinHeight = 32; $btnUnselAll.Padding = [Windows.Thickness]::new(10,4,10,4)
        $btnUnselAll.Add_Click({
            foreach ($it in (Get-SLTBROptItemsForTier $script:BROptSubTab)) { $script:BRChecks[$it.id] = $false }
            Render-SLTBRDetail
        })
        $btnStartOpt = New-Object Windows.Controls.Button
        $btnStartOpt.Content = ("Start " + $script:BROptSubTab + " Optimization")
        $btnStartOpt.Style = $script:Window.FindResource('ActionButton')
        $btnStartOpt.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnStartOpt.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnStartOpt.MinHeight = 34; $btnStartOpt.Padding = [Windows.Thickness]::new(16,5,16,5)
        $btnStartOpt.Add_Click({ Invoke-SLTBRRunStage 'b05' })

        $actBtns.Children.Add($btnSelAll)|Out-Null; $actBtns.Children.Add($btnUnselAll)|Out-Null; $actBtns.Children.Add($btnStartOpt)|Out-Null
        $actBtns.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
        $actBar.Children.Add($actBtns)|Out-Null
        $cardStack.Children.Add($actBar)|Out-Null

    } elseif ($st.id -eq 'r03') {
        # --- RESTORE STAGE 03: DRIVER UPDATE - OFFICIAL AUTO DETECT ---
        $hwInfo = Get-SLTHardware
        $badDrv = @(Get-SLTBadDrivers)
        $r03Grid = New-Object Windows.Controls.Primitives.UniformGrid; $r03Grid.Columns = 2

        # Left: Auto Detection Preview
        $leftCard = New-Object Windows.Controls.Border
        $leftCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $leftCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $leftCard.BorderThickness = [Windows.Thickness]::new(1); $leftCard.CornerRadius = [Windows.CornerRadius]::new(12); $leftCard.Padding = [Windows.Thickness]::new(14,12,14,12); $leftCard.Margin = [Windows.Thickness]::new(4)
        $lStack = New-Object Windows.Controls.StackPanel
        $lTitle = New-Object Windows.Controls.TextBlock; $lTitle.Text = 'WMI Auto Detection Preview'; $lTitle.FontSize = 13; $lTitle.FontWeight = 'Bold'; $lTitle.Margin = [Windows.Thickness]::new(0,0,0,8)
        $lTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $termBdr = New-Object Windows.Controls.Border
        $termBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'LogBg')
        $termBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $termBdr.BorderThickness = [Windows.Thickness]::new(1); $termBdr.CornerRadius = [Windows.CornerRadius]::new(8); $termBdr.Padding = [Windows.Thickness]::new(10,8,10,8)
        $termTxt = New-Object Windows.Controls.TextBlock
        $termTxt.FontFamily = 'Consolas'; $termTxt.FontSize = 11.2; $termTxt.TextWrapping = 'Wrap'
        $termTxt.Text = ("wmic csproduct get vendor, name`nVendor : " + $hwInfo.Maker + "`nModel  : " + $hwInfo.Model + "`nSerial : " + $hwInfo.Serial + "`nMissing/Warning Drivers: " + $badDrv.Count + "`n-> Official URL: " + (Get-SLTOEMURL $hwInfo.Maker))
        $termTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'LogFg')
        $termBdr.Child = $termTxt

        $lBtns = New-Object Windows.Controls.Primitives.UniformGrid; $lBtns.Columns = 2; $lBtns.Margin = [Windows.Thickness]::new(0,10,0,0)
        $btnDetect = New-Object Windows.Controls.Button; $btnDetect.Content = 'Auto Detect Model'; $btnDetect.Style = $script:Window.FindResource('OutlineButton')
        $btnDetect.Add_Click({
            Render-SLTBRDetail
            Set-SLTBRBanner ('Detected ' + $hwInfo.Maker + ' ' + $hwInfo.Model + ' (' + $badDrv.Count + ' driver alerts).')
        })
        $btnOpenOem = New-Object Windows.Controls.Button; $btnOpenOem.Content = 'Open Official Site ->'; $btnOpenOem.Style = $script:Window.FindResource('ActionButton')
        $btnOpenOem.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnOpenOem.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnOpenOem.Add_Click({
            $hwNow = Get-SLTHardware
            Open-SLTLink (Get-SLTOEMURL $hwNow.Maker)
            Toggle-SLTBRStageDone 'r03' -ForceDone
        })
        $lBtns.Children.Add($btnDetect)|Out-Null; $lBtns.Children.Add($btnOpenOem)|Out-Null
        $lStack.Children.Add($lTitle)|Out-Null; $lStack.Children.Add($termBdr)|Out-Null; $lStack.Children.Add($lBtns)|Out-Null
        $leftCard.Child = $lStack

        # Right: Quick Actions - Small Unified Buttons
        $rightCard = New-Object Windows.Controls.Border
        $rightCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $rightCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $rightCard.BorderThickness = [Windows.Thickness]::new(1); $rightCard.CornerRadius = [Windows.CornerRadius]::new(12); $rightCard.Padding = [Windows.Thickness]::new(14,12,14,12); $rightCard.Margin = [Windows.Thickness]::new(4)
        $rStack = New-Object Windows.Controls.StackPanel
        $rTitle = New-Object Windows.Controls.TextBlock; $rTitle.Text = 'Quick Actions - Official Driver Portals'; $rTitle.FontSize = 13; $rTitle.FontWeight = 'Bold'; $rTitle.Margin = [Windows.Thickness]::new(0,0,0,8)
        $rTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $qGrid = New-Object Windows.Controls.Primitives.UniformGrid; $qGrid.Columns = 2
        $qBtn1 = New-Object Windows.Controls.Button; $qBtn1.Content = 'Dell Support'; $qBtn1.Style = $script:Window.FindResource('OutlineButton'); $qBtn1.Add_Click({ Open-SLTLink 'https://www.dell.com/support/home' })
        $qBtn2 = New-Object Windows.Controls.Button; $qBtn2.Content = 'HP Drivers'; $qBtn2.Style = $script:Window.FindResource('OutlineButton'); $qBtn2.Add_Click({ Open-SLTLink 'https://support.hp.com/drivers' })
        $qBtn3 = New-Object Windows.Controls.Button; $qBtn3.Content = 'Lenovo Vantage'; $qBtn3.Style = $script:Window.FindResource('OutlineButton'); $qBtn3.Add_Click({ Open-SLTLink 'https://pcsupport.lenovo.com/' })
        $qBtn4 = New-Object Windows.Controls.Button; $qBtn4.Content = 'Win Update Drivers'; $qBtn4.Style = $script:Window.FindResource('OutlineButton'); $qBtn4.Add_Click({ try { Start-Process 'ms-settings:windowsupdate-optionalupdates' } catch {} })
        foreach ($qb in @($qBtn1,$qBtn2,$qBtn3,$qBtn4)) { $qGrid.Children.Add($qb)|Out-Null }

        $btnQuickAll = New-Object Windows.Controls.Button
        $btnQuickAll.Content = "Quick Install All - Official OEM Auto $chkSym"
        $btnQuickAll.Style = $script:Window.FindResource('ActionButton')
        $btnQuickAll.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnQuickAll.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnQuickAll.Margin = [Windows.Thickness]::new(4,8,4,0)
        $btnQuickAll.Add_Click({ Invoke-SLTBRRunStage 'r03' })

        $rStack.Children.Add($rTitle)|Out-Null; $rStack.Children.Add($qGrid)|Out-Null; $rStack.Children.Add($btnQuickAll)|Out-Null
        $rightCard.Child = $rStack

        $r03Grid.Children.Add($leftCard)|Out-Null; $r03Grid.Children.Add($rightCard)|Out-Null
        $cardStack.Children.Add($r03Grid)|Out-Null

    } elseif ($st.id -eq 'r06') {
        # --- RESTORE STAGE 06: HARDWARE INSPECTION LINK ---
        $r06Box = New-Object Windows.Controls.Border
        $r06Box.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $r06Box.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $r06Box.BorderThickness = [Windows.Thickness]::new(1); $r06Box.CornerRadius = [Windows.CornerRadius]::new(12); $r06Box.Padding = [Windows.Thickness]::new(16,14,16,14)
        $r06Sp = New-Object Windows.Controls.StackPanel
        $r06T1 = New-Object Windows.Controls.TextBlock
        $r06T1.Text = '06. Hardware Inspection & 1-Page A4 Reports (Linked Factory Module)'
        $r06T1.FontSize = 14.5; $r06T1.FontWeight = 'Bold'
        $r06T1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $r06T2 = New-Object Windows.Controls.TextBlock
        $r06T2.Text = 'After restoring the Master Image and drivers, verify Battery, Storage, RAM, Keyboard, Display, Speakers/Mic, Webcam, and USB Ports in the Hardware Inspection module, then generate the 1-Page A4 Customer Certificate (.html / .xlsx).'
        $r06T2.FontSize = 12; $r06T2.TextWrapping = 'Wrap'; $r06T2.Margin = [Windows.Thickness]::new(0,6,0,14)
        $r06T2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')

        $r06Btns = New-Object Windows.Controls.WrapPanel
        $btnGoAuto = New-Object Windows.Controls.Button
        $btnGoAuto.Content = 'Go to Auto Hardware Scan (8 Cabins) ->'
        $btnGoAuto.Style = $script:Window.FindResource('ActionButton')
        $btnGoAuto.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnGoAuto.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnGoAuto.Add_Click({ Invoke-SLTBRRunStage 'r06' })

        $btnGoMan = New-Object Windows.Controls.Button
        $btnGoMan.Content = 'Go to Manual QC Scan (8 Checks) ->'
        $btnGoMan.Style = $script:Window.FindResource('OutlineButton')
        $btnGoMan.Add_Click({
            Toggle-SLTBRStageDone 'r06' -ForceDone
            Switch-SLTPage 5
            if (Get-Command Switch-SLTHWTab -ErrorAction SilentlyContinue) { Switch-SLTHWTab 'Manual' }
        })

        $btnGoRep = New-Object Windows.Controls.Button
        $btnGoRep.Content = 'Go to Digital A4 Report ->'
        $btnGoRep.Style = $script:Window.FindResource('OutlineButton')
        $btnGoRep.Add_Click({
            Toggle-SLTBRStageDone 'r06' -ForceDone
            Switch-SLTPage 5
            if (Get-Command Switch-SLTHWTab -ErrorAction SilentlyContinue) { Switch-SLTHWTab 'Report' }
        })
        $r06Btns.Children.Add($btnGoAuto)|Out-Null; $r06Btns.Children.Add($btnGoMan)|Out-Null; $r06Btns.Children.Add($btnGoRep)|Out-Null
        $r06Sp.Children.Add($r06T1)|Out-Null; $r06Sp.Children.Add($r06T2)|Out-Null; $r06Sp.Children.Add($r06Btns)|Out-Null
        $r06Box.Child = $r06Sp
        $cardStack.Children.Add($r06Box)|Out-Null

    } else {
        # --- STANDARD CHECKLIST STAGES (b02, b03, b04, b06, b07, b08, b09 & r01, r02, r04, r05, r07) ---
        if ($st.id -eq 'b07') {
            # Inline Answer File Parameters Row
            $afBar = New-Object Windows.Controls.Border
            $afBar.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $afBar.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
            $afBar.BorderThickness = [Windows.Thickness]::new(1); $afBar.CornerRadius = [Windows.CornerRadius]::new(10); $afBar.Padding = [Windows.Thickness]::new(10,8,10,8); $afBar.Margin = [Windows.Thickness]::new(4,0,4,8)
            $afGrid = New-Object Windows.Controls.Primitives.UniformGrid; $afGrid.Columns = 4
            $spM = New-Object Windows.Controls.StackPanel; $spM.Margin = [Windows.Thickness]::new(4,0,4,0)
            $lM = New-Object Windows.Controls.TextBlock; $lM.Text = 'UNATTEND MODE'; $lM.FontSize = 9.5; $lM.FontWeight = 'Bold'; $lM.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $cbM = New-Object Windows.Controls.ComboBox; $cbM.Height = 30; $cbM.Margin = [Windows.Thickness]::new(0,3,0,0)
            [void]$cbM.Items.Add('Generic (All Brands)'); [void]$cbM.Items.Add('Brand (Keep Drivers)'); $cbM.SelectedIndex = 0
            $script:BRUnattendModeCombo = $cbM
            $spM.Children.Add($lM)|Out-Null; $spM.Children.Add($cbM)|Out-Null

            $spU = New-Object Windows.Controls.StackPanel; $spU.Margin = [Windows.Thickness]::new(4,0,4,0)
            $lU = New-Object Windows.Controls.TextBlock; $lU.Text = 'LOCAL USERNAME'; $lU.FontSize = 9.5; $lU.FontWeight = 'Bold'; $lU.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $tbU = New-Object Windows.Controls.TextBox; $tbU.Text = 'SLTUser'; $tbU.Height = 30; $tbU.Margin = [Windows.Thickness]::new(0,3,0,0)
            $script:BRUnattendUserBox = $tbU
            $spU.Children.Add($lU)|Out-Null; $spU.Children.Add($tbU)|Out-Null

            $spD = New-Object Windows.Controls.StackPanel; $spD.Margin = [Windows.Thickness]::new(4,0,4,0)
            $lD = New-Object Windows.Controls.TextBlock; $lD.Text = 'DISPLAY NAME'; $lD.FontSize = 9.5; $lD.FontWeight = 'Bold'; $lD.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $tbD = New-Object Windows.Controls.TextBox; $tbD.Text = 'Smart Life Teck'; $tbD.Height = 30; $tbD.Margin = [Windows.Thickness]::new(0,3,0,0)
            $script:BRUnattendDispBox = $tbD
            $spD.Children.Add($lD)|Out-Null; $spD.Children.Add($tbD)|Out-Null

            $spP = New-Object Windows.Controls.StackPanel; $spP.Margin = [Windows.Thickness]::new(4,0,4,0)
            $lP = New-Object Windows.Controls.TextBlock; $lP.Text = 'TEMP PASSWORD'; $lP.FontSize = 9.5; $lP.FontWeight = 'Bold'; $lP.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $pbP = New-Object Windows.Controls.PasswordBox; $pbP.Password = ''; $pbP.Height = 30; $pbP.Margin = [Windows.Thickness]::new(0,3,0,0)
            $pbP.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'InputBg')
            $pbP.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'TextPrimary')
            $script:BRUnattendPassBox = $pbP
            $spP.Children.Add($lP)|Out-Null; $spP.Children.Add($pbP)|Out-Null

            foreach ($el in @($spM,$spU,$spD,$spP)) { $afGrid.Children.Add($el)|Out-Null }
            $afBar.Child = $afGrid
            $cardStack.Children.Add($afBar)|Out-Null
        } elseif ($st.id -eq 'b09') {
            # Inline WIM Capture Path & LZX Command Bar
            $bkBar = New-Object Windows.Controls.Border
            $bkBar.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $bkBar.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
            $bkBar.BorderThickness = [Windows.Thickness]::new(1); $bkBar.CornerRadius = [Windows.CornerRadius]::new(10); $bkBar.Padding = [Windows.Thickness]::new(10,8,10,8); $bkBar.Margin = [Windows.Thickness]::new(4,0,4,8)
            $bkGrid = New-Object Windows.Controls.Primitives.UniformGrid; $bkGrid.Columns = 2
            $spW = New-Object Windows.Controls.StackPanel; $spW.Margin = [Windows.Thickness]::new(4,0,4,0)
            $lW = New-Object Windows.Controls.TextBlock; $lW.Text = 'TARGET WIM PATH (EXTERNAL DRIVE)'; $lW.FontSize = 9.5; $lW.FontWeight = 'Bold'; $lW.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $tbW = New-Object Windows.Controls.TextBox; $tbW.Text = 'D:\SLT_Backup.wim'; $tbW.Height = 30; $tbW.Margin = [Windows.Thickness]::new(0,3,0,0)
            $script:BRWimPathBox = $tbW
            $spW.Children.Add($lW)|Out-Null; $spW.Children.Add($tbW)|Out-Null

            $spN = New-Object Windows.Controls.StackPanel; $spN.Margin = [Windows.Thickness]::new(4,0,4,0)
            $lN = New-Object Windows.Controls.TextBlock; $lN.Text = 'MASTER IMAGE NAME'; $lN.FontSize = 9.5; $lN.FontWeight = 'Bold'; $lN.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $tbN = New-Object Windows.Controls.TextBox; $tbN.Text = 'SLT-GOLD-MASTER-W11'; $tbN.Height = 30; $tbN.Margin = [Windows.Thickness]::new(0,3,0,0)
            $script:BRImageNameBox = $tbN
            $spN.Children.Add($lN)|Out-Null; $spN.Children.Add($tbN)|Out-Null

            $bkGrid.Children.Add($spW)|Out-Null; $bkGrid.Children.Add($spN)|Out-Null
            $bkBar.Child = $bkGrid
            $cardStack.Children.Add($bkBar)|Out-Null
        } elseif ($st.id -eq 'r01') {
            # Inline Restore WIM Path Bar
            $rwBar = New-Object Windows.Controls.Border
            $rwBar.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $rwBar.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
            $rwBar.BorderThickness = [Windows.Thickness]::new(1); $rwBar.CornerRadius = [Windows.CornerRadius]::new(10); $rwBar.Padding = [Windows.Thickness]::new(10,8,10,8); $rwBar.Margin = [Windows.Thickness]::new(4,0,4,8)
            $rwSp = New-Object Windows.Controls.StackPanel
            $lRw = New-Object Windows.Controls.TextBlock; $lRw.Text = 'SOURCE MASTER WIM FILE TO APPLY'; $lRw.FontSize = 9.5; $lRw.FontWeight = 'Bold'; $lRw.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $tbRw = New-Object Windows.Controls.TextBox; $tbRw.Text = 'D:\SLT_Backup.wim'; $tbRw.Height = 30; $tbRw.Margin = [Windows.Thickness]::new(0,3,0,0)
            $script:BRRestoreWimBox = $tbRw
            $rwSp.Children.Add($lRw)|Out-Null; $rwSp.Children.Add($tbRw)|Out-Null
            $rwBar.Child = $rwSp
            $cardStack.Children.Add($rwBar)|Out-Null
        }

        # 2-Column Grouped Checklist
        $cardStack.Children.Add((New-SLTBRChecklistGrid $st.items 2))|Out-Null

        # Bottom Action Row (Selected Count + Cancel + Start Stage XX)
        $selStCnt = @($st.items | Where-Object { $script:BRChecks[$_.id] }).Count
        $stActBar = New-Object Windows.Controls.Grid; $stActBar.Margin = [Windows.Thickness]::new(4,10,4,0)
        $sac0 = New-Object Windows.Controls.ColumnDefinition; $sac0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $sac1 = New-Object Windows.Controls.ColumnDefinition; $sac1.Width = [Windows.GridLength]::Auto
        $stActBar.ColumnDefinitions.Add($sac0)|Out-Null; $stActBar.ColumnDefinitions.Add($sac1)|Out-Null

        $stSelLbl = New-Object Windows.Controls.TextBlock
        $stSelLbl.Text = ("$selStCnt / $($st.items.Count) selected  .  All selected by default (uncheck to skip)")
        $stSelLbl.FontSize = 11; $stSelLbl.VerticalAlignment = 'Center'
        $stSelLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $stActBar.Children.Add($stSelLbl)|Out-Null

        $stBtns = New-Object Windows.Controls.StackPanel; $stBtns.Orientation = 'Horizontal'
        if ($st.id -eq 'b07') {
            $btnDelXml = New-Object Windows.Controls.Button; $btnDelXml.Content = 'Delete Answer Files'; $btnDelXml.Style = $script:Window.FindResource('OutlineButton')
            $btnDelXml.MinHeight = 34; $btnDelXml.Padding = [Windows.Thickness]::new(12,5,12,5)
            $btnDelXml.Add_Click({
                $confirmDeleteXml = [Windows.MessageBox]::Show('Delete SLT-generated Unattend answer files? External Panther answer files will be preserved. The SLT file contains a readable temporary password.','Confirm Unattend Cleanup','YesNo','Warning')
                if ($confirmDeleteXml -ne 'Yes') { return }
                Get-ChildItem -LiteralPath $script:StateDir -Filter 'Unattend_*.xml' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                $pXml = Join-Path $env:WINDIR 'Panther\unattend.xml'
                if (Test-Path -LiteralPath $pXml) {
                    $isSltFile = Select-String -LiteralPath $pXml -SimpleMatch 'Generated by SLT Smart PC Boost.' -Quiet -ErrorAction SilentlyContinue
                    if ($isSltFile) { Remove-Item -LiteralPath $pXml -Force -ErrorAction SilentlyContinue }
                    else { Set-SLTBRBanner 'SLT answer files deleted. External Panther\unattend.xml was preserved.' }
                }
                $script:BRChecks['gs5'] = $false
                if (-not (Test-Path -LiteralPath $pXml)) { Set-SLTBRBanner 'SLT-generated Unattend answer files deleted.' }
            })
            $stBtns.Children.Add($btnDelXml)|Out-Null
        }
        $btnCancelSt = New-Object Windows.Controls.Button; $btnCancelSt.Content = 'Cancel'; $btnCancelSt.Style = $script:Window.FindResource('OutlineButton')
        $btnCancelSt.MinHeight = 34; $btnCancelSt.Padding = [Windows.Thickness]::new(14,5,14,5)
        $btnCancelSt.Add_Click({
            Set-SLTBRBanner ('Cancelled Stage ' + $st.no + ' changes.')
        })

        $btnStartSt = New-Object Windows.Controls.Button
        $btnStartSt.Content = ('Start Stage ' + $st.no)
        $btnStartSt.Tag = $st.id
        $btnStartSt.Style = $script:Window.FindResource('ActionButton')
        $btnStartSt.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $btnStartSt.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $btnStartSt.MinHeight = 34; $btnStartSt.Padding = [Windows.Thickness]::new(18,5,18,5)
        $btnStartSt.Add_Click({
            param($s,$e)
            Invoke-SLTBRRunStage ([string]$s.Tag)
        })
        $stBtns.Children.Add($btnCancelSt)|Out-Null; $stBtns.Children.Add($btnStartSt)|Out-Null
        $stBtns.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
        $stActBar.Children.Add($stBtns)|Out-Null
        $cardStack.Children.Add($stActBar)|Out-Null
    }

    $card.Child = $cardStack
    $mainStack.Children.Add($card)|Out-Null

    # 3. Live Info Strip Below Card
    $tipRow = New-Object Windows.Controls.StackPanel; $tipRow.Orientation = 'Horizontal'; $tipRow.Margin = [Windows.Thickness]::new(4,8,4,0)
    $tipDot = New-Object Windows.Shapes.Ellipse; $tipDot.Width = 6; $tipDot.Height = 6; $tipDot.SetResourceReference([Windows.Shapes.Shape]::FillProperty, 'TextAccent'); $tipDot.Margin = [Windows.Thickness]::new(0,0,8,0); $tipDot.VerticalAlignment = 'Center'
    $tipTxt = New-Object Windows.Controls.TextBlock
    $tipTxt.Text = 'Tip: Click any stage number (00-09 / 01-07) in the left sidebar to open its options right here in the same window - No popups, no scrolling.'
    $tipTxt.FontSize = 10.5
    $tipTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $script:BRStatusBannerTxt = $tipTxt
    $tipRow.Children.Add($tipDot)|Out-Null; $tipRow.Children.Add($tipTxt)|Out-Null
    $mainStack.Children.Add($tipRow)|Out-Null

    $script:BRDetailHost.Child = $mainStack
}

function Update-SLTBRVisuals {
    try {
        $stages = if ($script:BRMode -eq 'BACKUP') { $script:BRBackupStages } else { $script:BRRestoreStages }
        $total = $stages.Count
        $doneCnt = @($stages | Where-Object { $script:BRCompletedStages.ContainsKey($_.id) -and [bool]$script:BRCompletedStages[$_.id] }).Count
        $pct = if ($total -gt 0) { [int][Math]::Round(($doneCnt / [double]$total) * 100) } else { 0 }

        # Update Top Mode Toggle Buttons
        if ($null -ne $script:BRTopBackupBtn -and $null -ne $script:BRTopRestoreBtn) {
            if ($script:BRMode -eq 'BACKUP') {
                $script:BRTopBackupBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
                $script:BRTopBackupLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
                $script:BRTopRestoreBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
                $script:BRTopRestoreLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
            } else {
                $script:BRTopRestoreBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
                $script:BRTopRestoreLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
                $script:BRTopBackupBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
                $script:BRTopBackupLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
            }
        }

        if ($null -ne $script:BRTopDoneLbl) { $script:BRTopDoneLbl.Text = "$doneCnt/$total DONE" }
        if ($null -ne $script:BRSideCountBadge) { $script:BRSideCountBadge.Text = "$total STAGES" }
        if ($null -ne $script:BRSidePctLbl) { $script:BRSidePctLbl.Text = "$pct%" }

        $fillW = [Math]::Max(1, $doneCnt)
        $remW  = [Math]::Max(0, ($total - $doneCnt))
        if ($doneCnt -eq 0) { $fillW = 0; $remW = 1 }
        if ($null -ne $script:BRTopProgressCol0 -and $null -ne $script:BRTopProgressCol1) {
            $script:BRTopProgressCol0.Width = New-Object Windows.GridLength($fillW, [Windows.GridUnitType]::Star)
            $script:BRTopProgressCol1.Width = New-Object Windows.GridLength($remW, [Windows.GridUnitType]::Star)
        }
        if ($null -ne $script:BRSideProgressCol0 -and $null -ne $script:BRSideProgressCol1) {
            $script:BRSideProgressCol0.Width = New-Object Windows.GridLength($fillW, [Windows.GridUnitType]::Star)
            $script:BRSideProgressCol1.Width = New-Object Windows.GridLength($remW, [Windows.GridUnitType]::Star)
        }

        Render-SLTBRStageList
        Render-SLTBRDetail
    } catch {}
}

Update-SLTBRVisuals

Set-Item -Path Function:\global:Start-SLTCollection -Value ${function:Start-SLTCollection}
Set-Item -Path Function:\global:Sync-SLTBRAutoDetectedStages -Value ${function:Sync-SLTBRAutoDetectedStages}
Set-Item -Path Function:\global:Get-SLTBROptItemsForTier -Value ${function:Get-SLTBROptItemsForTier}
Set-Item -Path Function:\global:Set-SLTBRBanner -Value ${function:Set-SLTBRBanner}
Set-Item -Path Function:\global:Toggle-SLTBRStageDone -Value ${function:Toggle-SLTBRStageDone}
Set-Item -Path Function:\global:Show-SLTOptimizationLiveStatusModal -Value ${function:Show-SLTOptimizationLiveStatusModal}
Set-Item -Path Function:\global:Render-SLTBRStageList -Value ${function:Render-SLTBRStageList}
Set-Item -Path Function:\global:New-SLTBRChecklistGrid -Value ${function:New-SLTBRChecklistGrid}
Set-Item -Path Function:\global:Render-SLTBRDetail -Value ${function:Render-SLTBRDetail}
Set-Item -Path Function:\global:Update-SLTBRVisuals -Value ${function:Update-SLTBRVisuals}
