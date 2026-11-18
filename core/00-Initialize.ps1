# Root is supplied by the top-level entrypoint; never resolve from this module.
$script:Base = Join-Path $env:ProgramData 'SmartLifeTeck\PCCarePro'
$script:LogDir = Join-Path $script:Base 'Logs'
$script:StateDir = Join-Path $script:Base 'State'
foreach($d in @($script:Base,$script:LogDir,$script:StateDir)) { try { if(-not(Test-Path -LiteralPath $d)){New-Item -ItemType Directory -Force -Path $d -ErrorAction Stop | Out-Null} } catch {} }
# Protect machine-wide app state and logs: registry backups may contain startup command lines,
# while Unattend files can contain a temporary local-account password.
$script:StateAclProtected = $false
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principals = @('SYSTEM','BUILTIN\Administrators',$currentIdentity) | Select-Object -Unique
    $inheritFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    foreach ($privateDir in @($script:Base,$script:LogDir,$script:StateDir)) {
        $dirAcl = Get-Acl -LiteralPath $privateDir -ErrorAction Stop
        $dirAcl.SetAccessRuleProtection($true,$false)
        foreach ($existingRule in @($dirAcl.Access)) { $dirAcl.RemoveAccessRuleAll($existingRule) }
        foreach ($principal in $principals) {
            $dirRule = New-Object System.Security.AccessControl.FileSystemAccessRule($principal,[System.Security.AccessControl.FileSystemRights]::FullControl,$inheritFlags,[System.Security.AccessControl.PropagationFlags]::None,[System.Security.AccessControl.AccessControlType]::Allow)
            $dirAcl.AddAccessRule($dirRule)
        }
        Set-Acl -LiteralPath $privateDir -AclObject $dirAcl -ErrorAction Stop
    }
    $script:StateAclProtected = $true
} catch { $script:StateAclProtected = $false }
$script:LogFile = Join-Path $script:LogDir ('Care_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
# Detect duplicate-looking downloaded files without changing or deleting user data.
$script:StartupDuplicateFiles = @()
try {
    if ($null -ne $script:Root -and (Test-Path -LiteralPath $script:Root)) {
        foreach ($subDir in @('', 'core', 'pages', 'config', 'data', 'ui', 'tools')) {
            $targetDir = if ($subDir -eq '') { $script:Root } else { Join-Path $script:Root $subDir }
            if (-not (Test-Path -LiteralPath $targetDir)) { continue }
            $found = @(Get-ChildItem -LiteralPath $targetDir -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -match '^(.+?)\s*\((\d+)\)$' })
            foreach ($item in $found) { $script:StartupDuplicateFiles += $item.FullName }
        }
    }
} catch { $script:StartupDuplicateFiles = @() }

# StrictMode 2.0 Global Pre-Initialization for all v1.0.0 Upgrade Variables
$script:CurrentPage              = 0
$script:CurrentPageIndex         = 0
$script:CurrentPageRenderedOnce  = $false
$script:TweaksRenderedOnce       = $false
$script:AsyncScanProc            = $null
$script:AsyncScanTimer           = $null
$script:AsyncScanStartStamp      = ''
$script:SupportThemeCombo        = $null
$script:SuppressSelectAllEvent   = $false
$script:BROptAppliedItems        = @{}
$script:BROptSelectedCountLbl    = $null
$script:BROptStepIdx             = 0
$script:BROptAppliedCnt          = 0
$script:BROptAdvanceNext         = $false
$script:HWAutoScanTriggeredOnce  = $false
$script:PreviewSerialDateTxt     = $null
$script:CachedDashCpuName        = ''
$script:CachedDashHardware       = $null
$script:DashOfferPriceTxt        = $null
$script:DashOfferSubTxt          = $null
$script:DashOfferTitleTxt        = $null
$script:DashQuickActionStatus    = $null
$script:DashStatusPillBdr        = $null
$script:DashStatusPillTxt        = $null
$script:DashSysRows              = @{}
$script:SLTOfferImgUrl           = ''
$script:SLTOfferLinkUrl          = 'https://www.smartlifeteck.com'
$global:SLTLaptopInfo            = $null
$script:CachedPnpList            = $null
$script:CachedPnpTime            = [datetime]::MinValue
$script:BusyOverlayHost          = $null
$script:BusyOverlayTitle         = $null
$script:BusyOverlaySub           = $null
$script:BusyNeedleRotate         = $null
$script:BusySpinnerTimer         = $null
$script:BusyOuterRing            = $null
$script:BusyTickRing             = $null
$script:BusyNeedleLine           = $null
$script:BusyNeedleTip            = $null
$script:BusyCenterCap            = $null
$script:PrecomputedAppMatchList  = $null
$script:PrecomputedWingetMap     = $null
$script:BoostCountNormal         = 19
$script:BoostCountUltra          = 27
$script:BoostCountExtreme        = 31
$script:BoostCountTotal          = 32
$script:BoostAutoSchedDlg        = $null
$script:BoostAutoSchedStatusTxt  = $null
$script:BoostAutoSchedLastTxt    = $null
$script:HealthAutoSchedBadge     = $null

$script:Window = $null
$script:LogBox = $null
$script:Controls = @{}
$script:Actions = @{}
$script:Pages = @{}
$script:SelectedApps = @{}
$script:SelectedTweaks = @{}
$script:SelectedFeatures = @{}
$script:NavButtons = New-Object System.Collections.ArrayList
$script:SLTNavIcons = @()
$script:SLTNavLabels = @()
$script:SLTNavChevrons = @()
$script:DashCabinWidgets = @{}
$script:CachedBoostSysInfo = $null
$script:PcSummary = $null
$script:BoostHealthRestored = $false
$script:HealthIsFixing = $false
$script:HelpBox = $null
$script:ThemeSelector = $null
$script:CategoryCombo = $null
$script:SearchBox = $null
$script:SearchPlaceholder = $null
$script:AppWrap = $null
$script:CatalogInfo = $null
$script:ManagerChoice = $null
$script:SuppressCategoryEvent = $false
$script:InstallSearchHighlighted = $false
$script:InstallMainBtn = $null
$script:InstallMainBtnLbl = $null
$script:InstallMainBtnSub = $null
$script:InstallDlArrowTrans = $null
$script:InstallBtnNumTxt = $null
$script:InstallOfflineCacheCb = $null
$script:InstallAutoUpgradeCb = $null
$script:InstallAnimTimer = $null
$script:InstallAnimCurrentMb = 0.0
$script:InstallAnimTargetMb = 0.0
$script:InstallAnimCurrentCnt = 0
$script:InstallAnimTargetCnt = 0
$script:InstallAnimCurrentEta = 0.0
$script:InstallAnimTargetEta = 0.0
$script:InstallPulseTimer = $null
$script:InstallPulsePhase = $false
$script:InstallDescBlock = $null
$script:ToolsHubDescBlock = $null
$script:EssentialKeys = @{}
$script:ScannedInstalledApps = @{}
$script:ScanCompletedOnce = $false
$script:TotalPcInstalledCount = 0
$script:BtnMainUninstall = $null
$script:ScanTopBtn = $null
$script:ScanModalWin = $null
$script:RealScanAllApps = @()
$script:RealScanSltApps = @()
$script:RealScanCustomerApps = @()
$script:RealScanWindowsApps = @()
$script:RealScanActiveTab = 'ALL'
$script:RealRegRawCount = 0
$script:InstallMainBtnSub2 = $null
$script:BtnMainUninstallLbl = $null
$script:BtnMainUninstallSub = $null
$script:ScanBtnSub = $null
$script:InstallStatusLine = $null
$script:InstallUninstallMode = $false
$script:SelectedUninstallApps = @{}
$script:BtnForMoreInfo = $null
$script:ModalState = @{}
$script:MonitorState = @{}
$script:ConfirmDialogResult = $false
$global:installedApps = @{}
$script:UltimateHubSections = $null
$script:UltimateHubFilter = 'all'
$script:UltimateHubSearchBox = $null
$script:UltimateHubSectionBlocks = @{}
$script:UltimateHubPillButtons = @{}
$script:UltimateHubWebViewHost = $null
$script:UltimateHubCardList = @()
$script:UltimateHubSearchPlaceholder = $null
$script:UltimateHubSearchInfo = $null
$script:UltimateHubCountBadges = @{}
$script:SelectedActionBtn = $null
$script:SelectedBorderBtn = $null
$script:SelectedBorderLbl = $null
$script:SysProtSelected = $false
$script:AutoDetailModalWin = $null
$script:GpuStressWin = $null
$script:GpuStressTimer = $null
$script:GpuStressRunning = $false
$script:GpuStressSec = 0
$script:GpuStressMaxTemp = 42.0
$script:GpuStressStatusLbl = $null
$script:GpuStressTempLbl = $null
$script:GpuStressBar = $null
$script:SsdSpeedModalWin = $null
$script:SsdSpeedResultTxt = $null
$script:RamTestModalWin = $null
$script:RamTestResultTxt = $null
$script:SLTStartupForegroundDone = $false
$script:SLTSplashWindow = $null
$script:SLTSplashBar = $null
$script:SLTSplashPct = $null
$script:SLTSplashStage = $null
$script:SLTSplashDots = 0
$script:SLTConsoleMinimized = $false
$script:HostControl = $null
$script:TitleBlock = $null
$script:SubtitleBlock = $null
$script:ThemeKeys = @('EmeraldDark','MidnightDark','OceanCalmDark','CarbonGoldDark','ArcticBlueLight','SnowWhiteLight','WarmSandLight','SoftSageLight')
$script:DecisionDlg = $null
$script:SltCatalogData = $null
$script:AppRecords = @()
$script:AppIndex = @{}
$script:WebOnlyKeys = @{}
$script:InstallPriority = @{}
$script:InstallActiveMode = 'Install'
$script:InstallModeHost = $null
$script:UninstallModeHost = $null
$script:ModeBtnInstall = $null
$script:ModeBtnUninstall = $null
$script:ModeBtnInstallLbl = $null
$script:ModeBtnInstallSub = $null
$script:ModeBtnUninstallLbl = $null
$script:ModeBtnUninstallSub = $null
$script:InstallSelectAllCb = $null
$script:UninstallSearchBox = $null
$script:UninstallSearchPlaceholder = $null
$script:UninstallSelectAllCb = $null
$script:UninstallSectionsHost = $null
$script:UninstallCountsHeader = $null
$script:UninstallSelectedMap = @{}
$script:UninstallRowLookup = @{}
$script:UninstallVisibleCheckboxes = New-Object System.Collections.Generic.List[object]
$script:UninstallActiveFilter = 'ALL'
$script:UninstallFilterPills = @{}
$script:CurrentPageIndex = 0
$script:CurrentTheme = 'EmeraldDark'
$script:CatalogInitialized = $false
$script:BoostScannedOnce = $false
$script:DevUnlockedSession = $true
$script:HWData = @{
    PC         = $null
    CPU        = $null
    RAM        = $null
    Storage    = $null
    DiskSpeed  = $null
    Battery    = $null
    GPU        = $null
    Devices    = $null
    AutoPeripherals = $null
    Alerts     = @()
    ScanErrors = @()
    PhysicalQC = @{
        Keyboard   = 'Pending'
        Screen     = 'Pending'
        Audio      = 'Pending'
        Camera     = 'Pending'
        Ports      = 'Pending'
        Microphone = 'Pending'
        Touchpad   = 'Pending'
        Body       = 'Pending'
        Charger    = 'Pending'
        Fingerprint= 'Pending'
    }
    Customer = @{
        Name          = ''
        PurchaseDate  = ''
        Mobile        = ''
        City          = ''
        RetailPrice   = ''
        BodyCondition = 'Class A - OK'
        Charger       = 'Original Charger'
    }
    Notes = @{}
    ScanCancelled = $false
    KbdLayout = 'Laptop'
}
$script:HWToolsBin = Join-Path $script:Root 'tools-bin'
$script:HWSensorComputer = $null
$script:HWSections = @{}
$script:HWSubButtons = @{}
$script:HWCurrentSubTab = 'Auto'
$script:HWLiveTimer = $null
$script:HWPinDlg = $null
$script:HWPinBox = $null
$script:HWPinErr = $null
$script:HWPinRecord = $null
$script:HWPinAttempts = 0
$script:HWMonWin = $null
$script:HWMonHint = $null
$script:SLTWinBioReady = $false
$script:SLTMciReady = $false
$script:SLTWin32KeyMapReady = $false
$script:SLTMemBenchReady = $false
$script:SLTAudioGenReady = $false
$script:SLTMediaPlayer = $null
$script:SLTSplashWindow = $null
$script:SLTSplashBar = $null
$script:SLTSplashPct = $null
$script:SLTSplashStage = $null
$script:SLTSplashDots = 0
$script:SLTConsoleMinimized = $false
$script:SLTStartupForegroundDone = $false
$script:HWAudioDevicesCache = $null
$script:HWMonColors = @('#FFFFFF','#000000','#FF0000','#00FF00','#0000FF','#808080')
$script:HWMonIndex = 0
$script:HWKbdWin = $null
$script:HWKbdStatus = $null
$script:HWKbdMap = @{}
$script:HWScanProgressBar = $null
$script:HWScanStatusTitle = $null
$script:HWScanStatusSub = $null
$script:HWDealerAlertBorder = $null
$script:HWDealerAlertTitle = $null
$script:HWDealerAlertList = $null
$script:HWCardHost = $null
$script:HWPhysicalBadgeLabels = @{}
$script:HWManualSubLabels = @{}
$script:HWCabinWidgets = @{}
$script:HWManualCabins = @{}
$script:HWReportMode = 'Technical'
$script:HWReportPreviewControls = @{}
$script:HWAdvOpen = $false
$script:HWIncludeSpeed = $false
$script:HWBodyGrade = ''
$script:HWChargerWatts = ''
$script:HWReportQCLabels = @{}
$script:HWReportHWLabels = @{}
$script:HWNoteBoxes = @{}
$script:HWDeviceStripLabels = @{}
$script:HWCustBoxes = @{}
$script:HWKbdLayout = 'Laptop'
$script:HWSubTitleBlocks = @{}
$script:HWSubDescBlocks = @{}
$script:HWSubDots = @{}
$script:HWStartScanBtn = $null
$script:HWAdvPanel = $null
$script:HWManualCounterLbl = $null
$script:HWPassedCntTxt = $null
$script:HWIssueCntTxt = $null
$script:HWPendingCntTxt = $null
$script:BtnModeInternal = $null
$script:BtnModeCustomer = $null
$script:PreviewModeBadge = $null
$script:PreviewMainTitle = $null
$script:PreviewRemarksTxt = $null
$script:HWMasterWorkbenchOpen = $false
$script:HWMasterWorkbenchPanel = $null
$script:HWMasterImageNameBox = $null
$script:TouchEventsCount = 0
$script:TouchCountLbl = $null
$script:TpLeftPill = $null
$script:TpRightPill = $null
$script:TpScrollPill = $null
$script:TpModalWin = $null
$script:UsbPortCheckboxes = @{}
$script:UsbModalWin = $null
$script:CamModalLbl = $null
$script:CamModalWin = $null
$script:SpkModalStatus = $null
$script:SpkModalWin = $null
$script:BodyGradeButtons = @{}
$script:BodyModalWin = $null
$script:ChargerWattButtons = @{}
$script:ChgModalWin = $null
$script:HWInlineKbdMap = @{}
$script:HWInlineKbdStatus = $null
$script:HWReportSummaryBox = $null
$script:HWPortInventoryBox = $null
$script:BRMode = 'BACKUP'
$script:BRBackupIndex = 0
$script:BRRestoreIndex = 0
$script:BROptSubTab = 'SMART'
$script:BRLzxCompression = $true
$script:BRCompletedStages = @{}
$script:BRChecks = @{}
$script:BRStageButtons = @{}
$script:BRStageCircles = @{}
$script:BRStageCircleTxts = @{}
$script:BRStageTitles = @{}
$script:BRStageTicks = @{}
$script:BRStageListPanel = $null
$script:BRDetailHost = $null
$script:BRTopBackupBtn = $null
$script:BRTopBackupLbl = $null
$script:BRTopRestoreBtn = $null
$script:BRTopRestoreLbl = $null
$script:BRTopDoneLbl = $null
$script:BRTopProgressCol0 = $null
$script:BRTopProgressCol1 = $null
$script:BRSideCountBadge = $null
$script:BRSidePctLbl = $null
$script:BRSideProgressCol0 = $null
$script:BRSideProgressCol1 = $null
$script:BRFooterStatusLbl = $null
$script:BRFooterStageLbl = $null
$script:BRWimPathBox = $null
$script:BRImageNameBox = $null
$script:BRRestoreWimBox = $null
$script:BRUnattendModeCombo = $null
$script:BRUnattendUserBox = $null
$script:BRUnattendDispBox = $null
$script:BRUnattendPassBox = $null
$script:BRStatusBannerTxt = $null
$script:BROptTabButtons = @{}
$script:BROptTabLabels = @{}
$script:BRClickCount = 0
$script:Brand = Get-Content -LiteralPath (Join-Path $script:Root 'config\brand.json') -Raw | ConvertFrom-Json
$script:Themes = Get-Content -LiteralPath (Join-Path $script:Root 'config\themes.json') -Raw | ConvertFrom-Json
$script:PageNames = @('Dashboard','Smart Install & Uninstall','Smart Tools Hub','Boost Your PC','Backup & Restore','Smart Hardware Inspection','Support & Contact')
$script:PageDescriptions = @(
  'Live PC overview, hardware snapshot, quick workshop actions & module launcher - Powered by Smart Life Teck.',
  "Smart Installation Hub Select any software and install all at once, silently and officially. Smart Life Teck brings world's famous software in one automatic package. Smart Your Digital Life. By Smart Life Teck | Shahzad Babar",
  '104 Handpicked Productive, AI, Social, Career, Saudi Services & News Tools - Powered by Smart Life Teck.',
  'Boost Your PC - Smart Health Fix, Normal, Ultra, Extreme, Customize & Restore - Smarter Your Digital Life.',
  'System Restore Points, Driver Strategy, Windows 11 Audit Mode & Master Image Backup & Restore Factory.',
  'Smart Hardware Inspection: Auto Scan, Manual Scan, 1-Page A4 Digital QC Report & Master Image.',
  'Smart Life Teck official contact, WhatsApp support, stores, social channels & license.'
)

# Optional safe button-label/visibility overrides; edit JSON, not core GUI code.
$script:ActionOverrides = @{}
$overrideFile = Join-Path $script:Root 'config\button_overrides.json'
if(Test-Path -LiteralPath $overrideFile){
    $settings = Get-Content -LiteralPath $overrideFile -Raw | ConvertFrom-Json
    foreach($p in $settings.PSObject.Properties){ $script:ActionOverrides[$p.Name] = $p.Value }
}

function Invoke-SLTMinimizeConsole {
    # Minimise the black PowerShell console to the taskbar once (SW_MINIMIZE = 6)
    # without using -WindowStyle Minimized on the command line (so WPF windows
    # never inherit SW_SHOWMINIMIZED).
    if ($script:SLTConsoleMinimized) { return }
    $script:SLTConsoleMinimized = $true
    try {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; namespace SLT { public static class SLTConsoleWin32 { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); } }' -ErrorAction SilentlyContinue
    } catch {}
    try {
        $hwnd = [SLT.SLTConsoleWin32]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) { [void][SLT.SLTConsoleWin32]::ShowWindow($hwnd, 6) }
    } catch {}
}

function Add-SLTStartupStage([string]$Stage) {
    try {
        if ([string]::IsNullOrWhiteSpace($script:Root)) { return }
        $f = Join-Path $script:Root 'STARTUP_DIAGNOSTIC.txt'
        $line = (Get-Date -Format 'HH:mm:ss.fff') + '  ' + $Stage
        Add-Content -LiteralPath $f -Value $line -ErrorAction Stop
    } catch {}
}

function Install-SLTLogoLaunchers([switch]$CreateDesktopIcon=$true, [switch]$ShowNotification=$false) {
    # Creates SMART PC BOOST.lnk with the official Smart Life Teck Logo Icon
    # inside the main app folder, and (only when explicitly requested) ONE single icon on User Desktop.
    try {
        $srcIco = Join-Path $script:Root 'assets\SLT_PC_CARE_PRO.ico'
        $bestIco = $srcIco
        try {
            $iconDir = Join-Path $script:Base 'Icons'
            New-Item -ItemType Directory -Path $iconDir -Force -ErrorAction SilentlyContinue | Out-Null
            $destIco = Join-Path $iconDir 'SLT_PC_CARE_PRO.ico'
            if (Test-Path -LiteralPath $srcIco) {
                Copy-Item -LiteralPath $srcIco -Destination $destIco -Force -ErrorAction Stop
                $bestIco = $destIco
            }
        } catch {}

        # Preserve any existing Public Desktop shortcut. Startup must never delete user/admin shortcuts.
        try {
            $pubDesk = [Environment]::GetFolderPath('CommonDesktopDirectory')
            if (-not [string]::IsNullOrWhiteSpace($pubDesk)) {
                $pubLnk = Join-Path $pubDesk 'SMART PC BOOST.lnk'
                if (Test-Path -LiteralPath $pubLnk) { Log-SLT 'Existing Public Desktop shortcut detected and left untouched.' }
            }
        } catch {}

        $diagScript = Join-Path $script:Root 'START_SLT_DIAGNOSTIC.ps1'
        $wsh = New-Object -ComObject WScript.Shell
        $userDesk = [Environment]::GetFolderPath('DesktopDirectory')
        $targets = @($script:Root)
        if ($CreateDesktopIcon -and (-not [string]::IsNullOrWhiteSpace($userDesk))) {
            $targets += $userDesk
        }
        foreach ($dir in $targets) {
            if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
                try {
                    $lnkPath = Join-Path $dir 'SMART PC BOOST.lnk'
                    if (Test-Path -LiteralPath $lnkPath) { Log-SLT ("Existing SLT Smart PC Boost shortcut preserved in $dir"); continue }
                    $sc = $wsh.CreateShortcut($lnkPath)
                    $sc.TargetPath = 'powershell.exe'
                    $sc.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $diagScript + '"'
                    $sc.WorkingDirectory = $script:Root
                    if (Test-Path -LiteralPath $bestIco) {
                        $sc.IconLocation = ($bestIco + ',0')
                    }
                    $sc.Description = 'SLT Smart PC Boost - Powered by Smart Life Teck | Developed by Shahzad Babar'
                    $sc.Save()
                } catch {}
            }
        }
        if ($ShowNotification) {
            [Windows.MessageBox]::Show("Desktop shortcut setup completed. Existing shortcuts were preserved.`n`nLocation: $userDesk\SMART PC BOOST.lnk", 'Desktop Shortcut Setup', 'OK', 'Information') | Out-Null
        }
    } catch {}
}


function Install-SLTSmartToolsShortcut([switch]$ShowMessage) {
    # Creates "SLT Smart Tools Hub.url" on User Desktop + Public Desktop with SLT_PC_CARE_PRO.ico
    # opening https://smartlifeteck.com/tools (100% reliable Windows Internet Shortcut).
    try {
        $srcIco = Join-Path $script:Root 'assets\SLT_PC_CARE_PRO.ico'
        $bestIco = $srcIco
        try {
            $iconDir = Join-Path $script:Base 'Icons'
            New-Item -ItemType Directory -Path $iconDir -Force -ErrorAction SilentlyContinue | Out-Null
            $destIco = Join-Path $iconDir 'SLT_PC_CARE_PRO.ico'
            if (Test-Path -LiteralPath $srcIco) {
                Copy-Item -LiteralPath $srcIco -Destination $destIco -Force -ErrorAction Stop
                $bestIco = $destIco
            }
        } catch {}

        $urlContent = @(
            '[InternetShortcut]',
            'URL=https://smartlifeteck.com/tools',
            ('IconFile=' + $bestIco),
            'IconIndex=0',
            'HotKey=0',
            'IDList='
        ) -join "`r`n"

        $createdPaths = New-Object System.Collections.Generic.List[string]
        $targets = @(
            [Environment]::GetFolderPath('DesktopDirectory'),
            [Environment]::GetFolderPath('CommonDesktopDirectory')
        )
        foreach ($dir in $targets) {
            if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
                try {
                    # Never overwrite or delete an existing desktop shortcut, even if it looks duplicated.
                    $oldLnk = Join-Path $dir 'SLT Smart Tools Hub.lnk'
                    $urlPath = Join-Path $dir 'SLT Smart Tools Hub.url'
                    if ((Test-Path -LiteralPath $oldLnk) -or (Test-Path -LiteralPath $urlPath)) {
                        Log-SLT ("Existing SLT Tools Hub shortcut found in $dir; preserved without changes.")
                        continue
                    }
                    [IO.File]::WriteAllText($urlPath, ($urlContent + "`r`n"), [Text.Encoding]::ASCII)
                    if (Test-Path -LiteralPath $urlPath) { $createdPaths.Add($urlPath) }
                } catch {}
            }
        }
        Log-SLT 'Pinned SLT Smart Tools Hub.url desktop shortcut (https://smartlifeteck.com/tools) with SLT_PC_CARE_PRO.ico.'
        if ($ShowMessage) {
            $locTxt = if ($createdPaths.Count -gt 0) { $createdPaths[0] } else { 'Desktop\SLT Smart Tools Hub.url' }
            [Windows.MessageBox]::Show("SLT Smart Tools Hub shortcut has been created on your Desktop!`n`nFile: $locTxt`nOpens: https://smartlifeteck.com/tools`nIcon: SLT_PC_CARE_PRO.ico", 'SLT Smart Tools Hub Pinned', 'OK', 'Information') | Out-Null
        }
        return $true
    } catch {
        Log-SLT ('Smart Tools .url shortcut warning: ' + $_.Exception.Message)
        return $false
    }
}

function New-SLTBrush([string]$Hex) {
    return [Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
}

function New-SLTSplashFeatureCard([string]$BadgeTitle, [string]$DescText) {
    $bdr = New-Object Windows.Controls.Border
    $bdr.Background = (New-SLTBrush '#15463A')
    $bdr.BorderBrush = (New-SLTBrush '#2A6350')
    $bdr.BorderThickness = [Windows.Thickness]::new(1)
    $bdr.CornerRadius = [Windows.CornerRadius]::new(10)
    $bdr.Padding = [Windows.Thickness]::new(12,9,12,9)
    $bdr.Margin = [Windows.Thickness]::new(4)
    $sp = New-Object Windows.Controls.StackPanel
    $t1 = New-Object Windows.Controls.TextBlock
    $t1.Text = $BadgeTitle
    $t1.FontSize = 12
    $t1.FontWeight = 'Bold'
    $t1.Foreground = (New-SLTBrush '#E4C158')
    $t1.TextWrapping = 'Wrap'
    $t2 = New-Object Windows.Controls.TextBlock
    $t2.Text = $DescText
    $t2.FontSize = 10.8
    $t2.Foreground = (New-SLTBrush '#F4EAD7')
    $t2.TextWrapping = 'Wrap'
    $t2.Margin = [Windows.Thickness]::new(0,3,0,0)
    $sp.Children.Add($t1)|Out-Null
    $sp.Children.Add($t2)|Out-Null
    $bdr.Child = $sp
    return $bdr
}

function New-SLTSplashWindow {
    # Smart Life Teck Emerald Dark & Gold Marketing & Branding Splash Screen
    try {
        if ($null -ne $script:SLTSplashWindow) { return $script:SLTSplashWindow }
        Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction SilentlyContinue
        $win = New-Object Windows.Window
        $win.Title = 'SLT Smart PC Boost - Powered by Smart Life Teck'
        $win.Width = 750; $win.Height = 510
        $win.WindowStyle = 'None'; $win.ResizeMode = 'NoResize'
        $win.WindowStartupLocation = 'CenterScreen'
        $win.WindowState = 'Normal'
        $win.Topmost = $true; $win.ShowInTaskbar = $true
        $win.Background = (New-SLTBrush '#0E2A22')
        $win.BorderBrush = (New-SLTBrush '#C9A227')
        $win.BorderThickness = [Windows.Thickness]::new(2)
        $win.FontFamily = 'Segoe UI'
        try {
            $icoUri = [Uri]::new((Join-Path $script:Root 'assets\SLT_PC_CARE_PRO.ico'))
            $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($icoUri)
        } catch {}

        $outer = New-Object Windows.Controls.StackPanel
        $outer.Margin = [Windows.Thickness]::new(28,22,28,18)

        $hdrGrid = New-Object Windows.Controls.Grid
        $hc0 = New-Object Windows.Controls.ColumnDefinition; $hc0.Width = [Windows.GridLength]::Auto
        $hc1 = New-Object Windows.Controls.ColumnDefinition; $hc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $hdrGrid.ColumnDefinitions.Add($hc0)|Out-Null
        $hdrGrid.ColumnDefinitions.Add($hc1)|Out-Null

        $logoBdr = New-Object Windows.Controls.Border
        $logoBdr.Width = 68; $logoBdr.Height = 68
        $logoBdr.CornerRadius = [Windows.CornerRadius]::new(16)
        $logoBdr.Background = (New-SLTBrush '#15463A')
        $logoBdr.BorderBrush = (New-SLTBrush '#C9A227')
        $logoBdr.BorderThickness = [Windows.Thickness]::new(1.5)
        $logoBdr.Margin = [Windows.Thickness]::new(0,0,16,0)
        $logoBdr.VerticalAlignment = 'Center'
        $logoLoaded = $false
        try {
            $emblemPath = Join-Path $script:Root 'assets\SLT_Emblem.png'
            if (Test-Path -LiteralPath $emblemPath) {
                $bmp = [Windows.Media.Imaging.BitmapImage]::new()
                $bmp.BeginInit(); $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.UriSource = [Uri]::new($emblemPath); $bmp.EndInit()
                $img = New-Object Windows.Controls.Image
                $img.Source = $bmp; $img.Width = 50; $img.Height = 50; $img.Stretch = 'Uniform'
                $img.HorizontalAlignment = 'Center'; $img.VerticalAlignment = 'Center'
                $logoBdr.Child = $img
                $logoLoaded = $true
            }
        } catch {}
        if (-not $logoLoaded) {
            $logoTxt = New-Object Windows.Controls.TextBlock
            $logoTxt.Text = 'S'; $logoTxt.FontSize = 32; $logoTxt.FontWeight = 'Bold'
            $logoTxt.Foreground = (New-SLTBrush '#E4C158')
            $logoTxt.HorizontalAlignment = 'Center'; $logoTxt.VerticalAlignment = 'Center'
            $logoBdr.Child = $logoTxt
        }
        $logoBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
        $hdrGrid.Children.Add($logoBdr)|Out-Null

        $titleStack = New-Object Windows.Controls.StackPanel
        $titleStack.VerticalAlignment = 'Center'
        $brandPill = New-Object Windows.Controls.Border
        $brandPill.Background = (New-SLTBrush '#15463A')
        $brandPill.BorderBrush = (New-SLTBrush '#C9A227')
        $brandPill.BorderThickness = [Windows.Thickness]::new(1)
        $brandPill.CornerRadius = [Windows.CornerRadius]::new(6)
        $brandPill.Padding = [Windows.Thickness]::new(10,3,10,3)
        $brandPill.HorizontalAlignment = 'Left'
        $brandPill.Margin = [Windows.Thickness]::new(0,0,0,4)
        $brandTb = New-Object Windows.Controls.TextBlock
        $brandTb.Text = 'SMART LIFE TECK  |  OFFICIAL PC & LAPTOP SUITE  |  SAUDI ARABIA'
        $brandTb.FontSize = 10.5; $brandTb.FontWeight = 'Bold'
        $brandTb.Foreground = (New-SLTBrush '#E4C158')
        $brandPill.Child = $brandTb

        $titleRow = New-Object Windows.Controls.StackPanel
        $titleRow.Orientation = 'Horizontal'
        $titleTb = New-Object Windows.Controls.TextBlock
        $titleTb.Text = 'SLT Smart PC Boost'
        $titleTb.FontSize = 28; $titleTb.FontWeight = 'Bold'
        $titleTb.Foreground = (New-SLTBrush '#F4EAD7')
        $verTb = New-Object Windows.Controls.TextBlock
        $verTb.Text = '  v1.0.0'
        $verTb.FontSize = 16; $verTb.FontWeight = 'Bold'
        $verTb.Foreground = (New-SLTBrush '#E4C158')
        $verTb.VerticalAlignment = 'Bottom'
        $verTb.Margin = [Windows.Thickness]::new(0,0,0,4)
        $titleRow.Children.Add($titleTb)|Out-Null
        $titleRow.Children.Add($verTb)|Out-Null

        $subTb = New-Object Windows.Controls.TextBlock
        $subTb.Text = 'Smarter Your Digital Life  -  Laptop QC, PC Optimization & 104 Web/AI Tools'
        $subTb.FontSize = 12; $subTb.FontWeight = 'SemiBold'
        $subTb.Foreground = (New-SLTBrush '#AEC9BD')
        $subTb.Margin = [Windows.Thickness]::new(0,2,0,0)

        $titleStack.Children.Add($brandPill)|Out-Null
        $titleStack.Children.Add($titleRow)|Out-Null
        $titleStack.Children.Add($subTb)|Out-Null
        $titleStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
        $hdrGrid.Children.Add($titleStack)|Out-Null
        $outer.Children.Add($hdrGrid)|Out-Null

        $sep = New-Object Windows.Controls.Border
        $sep.Height = 1; $sep.Background = (New-SLTBrush '#2A6350')
        $sep.Margin = [Windows.Thickness]::new(0,14,0,10)
        $outer.Children.Add($sep)|Out-Null

        $secTitle = New-Object Windows.Controls.TextBlock
        $secTitle.Text = 'ALL-IN-ONE PROFESSIONAL FEATURES INCLUDED IN THIS SUITE:'
        $secTitle.FontSize = 10.5; $secTitle.FontWeight = 'Bold'
        $secTitle.Foreground = (New-SLTBrush '#E4C158')
        $secTitle.Margin = [Windows.Thickness]::new(4,0,0,6)
        $outer.Children.Add($secTitle)|Out-Null

        $featGrid = New-Object Windows.Controls.Primitives.UniformGrid
        $featGrid.Rows = 2; $featGrid.Columns = 2
        $featGrid.Children.Add((New-SLTSplashFeatureCard '1. Smart Hardware Inspection & A4 Reports' 'Auto & Manual QC Scan, Battery/Storage Health & 1-Page A4 Customer/Internal Certificates (HTML & Excel)'))|Out-Null
        $featGrid.Children.Add((New-SLTSplashFeatureCard '2. Boost Your PC & Smart Health Fix' 'Normal, Ultra & Extreme Optimization Presets, Driver/Disk/Network Repair & 1-Click Safe Restore'))|Out-Null
        $featGrid.Children.Add((New-SLTSplashFeatureCard '3. Smart Tools Hub (104 Tools)' '35 Productive, 25 Top AI, 20 Social, 8 Career, 8 Saudi Services & 8 Live News Tools in 1 Click'))|Out-Null
        $featGrid.Children.Add((New-SLTSplashFeatureCard '4. Smart Install & Uninstall (203 Apps & 18 OS)' 'Official Software Center with Instant Search & Windows Audit / Unattend Master Image Backup'))|Out-Null
        $outer.Children.Add($featGrid)|Out-Null

        $contactBdr = New-Object Windows.Controls.Border
        $contactBdr.Background = (New-SLTBrush '#0A1F18')
        $contactBdr.BorderBrush = (New-SLTBrush '#C9A227')
        $contactBdr.BorderThickness = [Windows.Thickness]::new(1)
        $contactBdr.CornerRadius = [Windows.CornerRadius]::new(10)
        $contactBdr.Padding = [Windows.Thickness]::new(14,9,14,9)
        $contactBdr.Margin = [Windows.Thickness]::new(4,10,4,12)
        $contactSp = New-Object Windows.Controls.StackPanel
        $cLine1 = New-Object Windows.Controls.TextBlock
        $cLine1.Text = 'Website: www.smartlifeteck.com   |   WhatsApp: +966 55 376 0854   |   Email: info@smartlifeteck.com'
        $cLine1.FontSize = 11.8; $cLine1.FontWeight = 'Bold'
        $cLine1.Foreground = (New-SLTBrush '#F4EAD7')
        $cLine1.HorizontalAlignment = 'Center'
        $cLine2 = New-Object Windows.Controls.TextBlock
        $cLine2.Text = 'Follow @smartlifeteck on YouTube  .  TikTok  .  Instagram  .  Facebook  .  X   |   Developed by Shahzad Babar'
        $cLine2.FontSize = 10.8; $cLine2.FontWeight = 'SemiBold'
        $cLine2.Foreground = (New-SLTBrush '#E4C158')
        $cLine2.HorizontalAlignment = 'Center'
        $cLine2.Margin = [Windows.Thickness]::new(0,3,0,0)
        $contactSp.Children.Add($cLine1)|Out-Null
        $contactSp.Children.Add($cLine2)|Out-Null
        $contactBdr.Child = $contactSp
        $outer.Children.Add($contactBdr)|Out-Null

        $statusGrid = New-Object Windows.Controls.Grid
        $sc0 = New-Object Windows.Controls.ColumnDefinition; $sc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $sc1 = New-Object Windows.Controls.ColumnDefinition; $sc1.Width = [Windows.GridLength]::Auto
        $statusGrid.ColumnDefinitions.Add($sc0)|Out-Null
        $statusGrid.ColumnDefinitions.Add($sc1)|Out-Null
        $statusGrid.Margin = [Windows.Thickness]::new(4,0,4,6)

        $stageTb = New-Object Windows.Controls.TextBlock
        $stageTb.Text = 'Initializing Smart Life Teck Core Engine...'
        $stageTb.FontSize = 12.5; $stageTb.FontWeight = 'SemiBold'
        $stageTb.Foreground = (New-SLTBrush '#F4EAD7')
        $stageTb.VerticalAlignment = 'Center'
        $stageTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

        $pctTb = New-Object Windows.Controls.TextBlock
        $pctTb.Text = '8%'
        $pctTb.FontSize = 18; $pctTb.FontWeight = 'Bold'
        $pctTb.Foreground = (New-SLTBrush '#E4C158')
        $pctTb.VerticalAlignment = 'Center'
        $pctTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

        $statusGrid.Children.Add($stageTb)|Out-Null
        $statusGrid.Children.Add($pctTb)|Out-Null
        $outer.Children.Add($statusGrid)|Out-Null

        $bar = New-Object Windows.Controls.ProgressBar
        $bar.Minimum = 0; $bar.Maximum = 100; $bar.Value = 8; $bar.Height = 12
        $bar.Margin = [Windows.Thickness]::new(4,0,4,0)
        $bar.Foreground = (New-SLTBrush '#C9A227')
        $bar.Background = (New-SLTBrush '#0A1F18')
        $bar.BorderBrush = (New-SLTBrush '#2A6350')
        $bar.BorderThickness = [Windows.Thickness]::new(1)
        $outer.Children.Add($bar)|Out-Null

        $win.Content = $outer
        $script:SLTSplashBar = $bar; $script:SLTSplashPct = $pctTb; $script:SLTSplashStage = $stageTb; $script:SLTSplashWindow = $win
        $win.WindowState = 'Normal'
        $win.Show()
        $win.WindowState = 'Normal'
        try { $win.Activate() } catch {}
        $win.UpdateLayout()
        try { $win.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{}) } catch {}
        return $win
    } catch { $script:SLTSplashWindow = $null; return $null }
}

function Update-SLTSplashProgress([int]$Percent,[string]$Stage) {
    try {
        if ($null -eq $script:SLTSplashWindow) { return }
        if ($Percent -lt 0) { $Percent = 0 }
        if ($Percent -gt 100) { $Percent = 100 }
        $script:SLTSplashDots = ($script:SLTSplashDots + 1) % 4
        $dots = ''
        for ($i = 0; $i -lt $script:SLTSplashDots; $i++) { $dots += '.' }
        if ($null -ne $script:SLTSplashBar) { $script:SLTSplashBar.Value = $Percent }
        if ($null -ne $script:SLTSplashPct) { $script:SLTSplashPct.Text = "$Percent%" }
        if ($null -ne $script:SLTSplashStage) { $script:SLTSplashStage.Text = $Stage + $dots }
        try {
            if ($script:SLTSplashWindow.WindowState -ne 'Normal') { $script:SLTSplashWindow.WindowState = 'Normal' }
        } catch {}
        try { $script:SLTSplashWindow.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{}) } catch {}
        try { $script:SLTSplashWindow.UpdateLayout() } catch {}
    } catch {}
}

function Close-SLTSplash {
    try {
        $win = $script:SLTSplashWindow
        $script:SLTSplashWindow = $null; $script:SLTSplashBar = $null; $script:SLTSplashPct = $null; $script:SLTSplashStage = $null
        if ($null -ne $win) { $win.Close() }
    } catch {}
}
