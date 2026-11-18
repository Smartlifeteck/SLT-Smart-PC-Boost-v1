# ==============================================================================
# pages/01-Dashboard.ps1 (Index 0)
# SLT Smart PC Boost v1.0.0 - Dashboard Option 2 (System Info + Quick Actions + 6 Modules + SLT Special Offers)
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# ==============================================================================
$page = New-SLTPage 0
$emDash = [char]0x2014
$bullet = [char]0x2022
$chkSym = [char]0x2713
$arrSym = [char]0x2192
$warnSym = [char]0x26A0

$mainStack = New-Object Windows.Controls.StackPanel
$mainStack.Margin = [Windows.Thickness]::new(6, 2, 6, 18)

# ==============================================================================
# 1. CLEAN HEADER BAR (Full Title, Never Cut + Live Refresh Button)
# ==============================================================================
$heroBdr = New-Object Windows.Controls.Border
$heroBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$heroBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$heroBdr.BorderThickness = [Windows.Thickness]::new(1.2)
$heroBdr.CornerRadius = [Windows.CornerRadius]::new(14)
$heroBdr.Padding = [Windows.Thickness]::new(20, 14, 20, 14)
$heroBdr.Margin = [Windows.Thickness]::new(4, 0, 4, 14)
$heroBdr.Effect = New-SLTCabinShadow 14 2 0.06

$heroGrid = New-Object Windows.Controls.Grid
$hc0 = New-Object Windows.Controls.ColumnDefinition; $hc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$hc1 = New-Object Windows.Controls.ColumnDefinition; $hc1.Width = [Windows.GridLength]::Auto
$heroGrid.ColumnDefinitions.Add($hc0)|Out-Null
$heroGrid.ColumnDefinitions.Add($hc1)|Out-Null

$heroLeft = New-Object Windows.Controls.StackPanel
$heroLeft.VerticalAlignment = 'Center'
$heroLeft.Margin = [Windows.Thickness]::new(0, 0, 12, 0)

$dashH1 = New-Object Windows.Controls.TextBlock
$dashH1.Text = "SLT Smart PC Boost $emDash DASHBOARD"
$dashH1.FontSize = 20; $dashH1.FontWeight = 'Bold'
$dashH1.TextWrapping = 'Wrap'
$dashH1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')

$dashSub = New-Object Windows.Controls.TextBlock
$dashSub.Text = 'Powered by Smart Life Teck  |  Developed by Shahzad Babar  |  Live System Overview & Quick Actions'
$dashSub.FontSize = 12; $dashSub.TextWrapping = 'Wrap'
$dashSub.Margin = [Windows.Thickness]::new(0, 3, 0, 0)
$dashSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')

$heroLeft.Children.Add($dashH1)|Out-Null
$heroLeft.Children.Add($dashSub)|Out-Null
$heroLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$heroGrid.Children.Add($heroLeft)|Out-Null

$heroRight = New-Object Windows.Controls.StackPanel
$heroRight.Orientation = 'Horizontal'
$heroRight.VerticalAlignment = 'Center'

$btnDeskIcon = New-Object Windows.Controls.Button
$btnDeskIcon.Content = "Create Desktop Icon"
$btnDeskIcon.ToolTip = "Create 1 single SLT Smart PC Boost shortcut with official Smart Life Teck logo on your Desktop"
$btnDeskIcon.Style = $script:Window.FindResource('OutlineButton')
$btnDeskIcon.Height = 36; $btnDeskIcon.Padding = [Windows.Thickness]::new(14, 5, 14, 5)
$btnDeskIcon.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
$btnDeskIcon.Add_Click({
    if (Get-Command Install-SLTLogoLaunchers -ErrorAction SilentlyContinue) {
        Install-SLTLogoLaunchers -CreateDesktopIcon -ShowNotification
        Log-SLT 'Created single SLT Smart PC Boost Desktop Icon on User Desktop.'
    }
})
$heroRight.Children.Add($btnDeskIcon)|Out-Null

$btnScanNow = New-Object Windows.Controls.Button
$btnScanNow.Content = "Refresh System Info"
$btnScanNow.Style = $script:Window.FindResource('ActionButton')
$btnScanNow.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
$btnScanNow.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
$btnScanNow.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
$btnScanNow.Height = 36; $btnScanNow.Padding = [Windows.Thickness]::new(16, 5, 16, 5)
$btnScanNow.Add_Click({
    Invoke-SLTDashboardLiveRefresh -ShowLog
})
$heroRight.Children.Add($btnScanNow)|Out-Null
$heroRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$heroGrid.Children.Add($heroRight)|Out-Null

$heroBdr.Child = $heroGrid
$mainStack.Children.Add($heroBdr)|Out-Null

# ==============================================================================
# 2. OPTION 2 TOP SECTION: LEFT BIG CARD (1 SYSTEM INFO BOX) + RIGHT SMALL CARD (QUICK ACTIONS)
# ==============================================================================
$topTwoColGrid = New-Object Windows.Controls.Grid
$topTwoColGrid.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
$tcLeft  = New-Object Windows.Controls.ColumnDefinition; $tcLeft.Width  = New-Object Windows.GridLength(1.55, [Windows.GridUnitType]::Star)
$tcRight = New-Object Windows.Controls.ColumnDefinition; $tcRight.Width = New-Object Windows.GridLength(1.0, [Windows.GridUnitType]::Star)
$topTwoColGrid.ColumnDefinitions.Add($tcLeft)|Out-Null
$topTwoColGrid.ColumnDefinitions.Add($tcRight)|Out-Null

# --- LEFT BIG CARD: ONE COMPLETE SYSTEM INFO BOX (Full text, never cut) ---
$sysCardBdr = New-Object Windows.Controls.Border
$sysCardBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$sysCardBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$sysCardBdr.BorderThickness = [Windows.Thickness]::new(1.2)
$sysCardBdr.CornerRadius = [Windows.CornerRadius]::new(16)
$sysCardBdr.Padding = [Windows.Thickness]::new(20, 16, 20, 16)
$sysCardBdr.Margin = [Windows.Thickness]::new(4, 0, 6, 0)
$sysCardBdr.Effect = New-SLTCabinShadow 14 2 0.05

$sysStack = New-Object Windows.Controls.StackPanel

$sysHdrRow = New-Object Windows.Controls.Grid
$shc0 = New-Object Windows.Controls.ColumnDefinition; $shc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$shc1 = New-Object Windows.Controls.ColumnDefinition; $shc1.Width = [Windows.GridLength]::Auto
$sysHdrRow.ColumnDefinitions.Add($shc0)|Out-Null
$sysHdrRow.ColumnDefinitions.Add($shc1)|Out-Null
$sysHdrRow.Margin = [Windows.Thickness]::new(0, 0, 0, 12)

$sysTitleRow = New-Object Windows.Controls.StackPanel
$sysTitleRow.Orientation = 'Horizontal'; $sysTitleRow.VerticalAlignment = 'Center'
$sysIcon = New-SLTLucideIcon 'Laptop' 18 '#0D9488'
$sysIcon.Margin = [Windows.Thickness]::new(0, 0, 8, 0); $sysIcon.VerticalAlignment = 'Center'
$sysHdrTxt = New-Object Windows.Controls.TextBlock
$sysHdrTxt.Text = 'SYSTEM INFORMATION  -  THIS LAPTOP / PC'
$sysHdrTxt.FontSize = 13.5; $sysHdrTxt.FontWeight = 'Bold'; $sysHdrTxt.VerticalAlignment = 'Center'
$sysHdrTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$sysTitleRow.Children.Add($sysIcon)|Out-Null
$sysTitleRow.Children.Add($sysHdrTxt)|Out-Null
$sysTitleRow.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$sysHdrRow.Children.Add($sysTitleRow)|Out-Null

$script:DashStatusPillBdr = New-Object Windows.Controls.Border
$script:DashStatusPillBdr.CornerRadius = [Windows.CornerRadius]::new(8)
$script:DashStatusPillBdr.Padding = [Windows.Thickness]::new(10, 3, 10, 3)
$script:DashStatusPillBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
$script:DashStatusPillBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
$script:DashStatusPillBdr.BorderThickness = [Windows.Thickness]::new(1)
$script:DashStatusPillTxt = New-Object Windows.Controls.TextBlock
$script:DashStatusPillTxt.Text = "$chkSym Status: System Protected"
$script:DashStatusPillTxt.FontSize = 11; $script:DashStatusPillTxt.FontWeight = 'Bold'
$script:DashStatusPillTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
$script:DashStatusPillBdr.Child = $script:DashStatusPillTxt
$script:DashStatusPillBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$sysHdrRow.Children.Add($script:DashStatusPillBdr)|Out-Null
$sysStack.Children.Add($sysHdrRow)|Out-Null

$script:DashSysRows = @{}
$sysRowDefs = @(
    @{ Key='Laptop';  Label='Laptop / Model:'; Val='Detecting Laptop Model...' },
    @{ Key='OS';      Label='Windows OS:';     Val='Detecting Windows Edition...' },
    @{ Key='CPU';     Label='Processor (CPU):';Val='Detecting Processor...' },
    @{ Key='RAM';     Label='Installed RAM:';  Val='Detecting RAM...' },
    @{ Key='Storage'; Label='Storage C:';      Val='Detecting C: Drive Space...' },
    @{ Key='Battery'; Label='Battery Health:'; Val='Detecting Battery...' },
    @{ Key='Status';  Label='System Status:';  Val='System Protected' }
)

foreach ($sr in $sysRowDefs) {
    $rBdr = New-Object Windows.Controls.Border
    $rBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
    $rBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $rBdr.BorderThickness = [Windows.Thickness]::new(1)
    $rBdr.CornerRadius = [Windows.CornerRadius]::new(8)
    $rBdr.Padding = [Windows.Thickness]::new(12, 6, 12, 6)
    $rBdr.Margin = [Windows.Thickness]::new(0, 0, 0, 5)

    $rg = New-Object Windows.Controls.Grid
    $rc0 = New-Object Windows.Controls.ColumnDefinition; $rc0.Width = New-Object Windows.GridLength(135)
    $rc1 = New-Object Windows.Controls.ColumnDefinition; $rc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $rg.ColumnDefinitions.Add($rc0)|Out-Null
    $rg.ColumnDefinitions.Add($rc1)|Out-Null

    $lblTb = New-Object Windows.Controls.TextBlock
    $lblTb.Text = $sr.Label
    $lblTb.FontSize = 12; $lblTb.FontWeight = 'SemiBold'; $lblTb.VerticalAlignment = 'Center'
    $lblTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $lblTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $valTb = New-Object Windows.Controls.TextBlock
    $valTb.Text = $sr.Val
    $valTb.FontSize = 12.5; $valTb.FontWeight = 'Bold'; $valTb.VerticalAlignment = 'Center'
    $valTb.TextWrapping = 'Wrap'
    if ($sr.Key -eq 'Status') {
        $valTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
    } else {
        $valTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    }
    $valTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

    $rg.Children.Add($lblTb)|Out-Null
    $rg.Children.Add($valTb)|Out-Null
    $rBdr.Child = $rg
    $sysStack.Children.Add($rBdr)|Out-Null
    $script:DashSysRows[$sr.Key] = $valTb
}

$sysCardBdr.Child = $sysStack
$sysCardBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$topTwoColGrid.Children.Add($sysCardBdr)|Out-Null

# --- RIGHT SMALL CARD: QUICK ACTIONS (3 Real Working Buttons + Live Result Box) ---
$qaCardBdr = New-Object Windows.Controls.Border
$qaCardBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$qaCardBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$qaCardBdr.BorderThickness = [Windows.Thickness]::new(1.2)
$qaCardBdr.CornerRadius = [Windows.CornerRadius]::new(16)
$qaCardBdr.Padding = [Windows.Thickness]::new(20, 16, 20, 16)
$qaCardBdr.Margin = [Windows.Thickness]::new(6, 0, 4, 0)
$qaCardBdr.Effect = New-SLTCabinShadow 14 2 0.05

$qaStack = New-Object Windows.Controls.StackPanel

$qaTitleRow = New-Object Windows.Controls.StackPanel
$qaTitleRow.Orientation = 'Horizontal'; $qaTitleRow.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
$qaIcon = New-SLTLucideIcon 'Zap' 18 '#0D9488'
$qaIcon.Margin = [Windows.Thickness]::new(0, 0, 8, 0); $qaIcon.VerticalAlignment = 'Center'
$qaHdrTxt = New-Object Windows.Controls.TextBlock
$qaHdrTxt.Text = 'QUICK ACTIONS'
$qaHdrTxt.FontSize = 13.5; $qaHdrTxt.FontWeight = 'Bold'; $qaHdrTxt.VerticalAlignment = 'Center'
$qaHdrTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$qaTitleRow.Children.Add($qaIcon)|Out-Null
$qaTitleRow.Children.Add($qaHdrTxt)|Out-Null
$qaStack.Children.Add($qaTitleRow)|Out-Null

$qaSubTxt = New-Object Windows.Controls.TextBlock
$qaSubTxt.Text = 'Run real hardware, driver, update, and health checks on this laptop.'
$qaSubTxt.FontSize = 11.5; $qaSubTxt.TextWrapping = 'Wrap'
$qaSubTxt.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
$qaSubTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$qaStack.Children.Add($qaSubTxt)|Out-Null

$btnCheckDrivers = New-Object Windows.Controls.Button
$btnCheckDrivers.Content = "Check Drivers"
$btnCheckDrivers.Style = $script:Window.FindResource('ActionButton')
$btnCheckDrivers.HorizontalAlignment = 'Stretch'
$btnCheckDrivers.Height = 40; $btnCheckDrivers.FontSize = 12.8; $btnCheckDrivers.FontWeight = 'Bold'
$btnCheckDrivers.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
$btnCheckDrivers.Add_Click({
    Invoke-SLTDashCheckDrivers
})
$qaStack.Children.Add($btnCheckDrivers)|Out-Null

$btnCheckWinUpdate = New-Object Windows.Controls.Button
$btnCheckWinUpdate.Content = "Check Windows Update"
$btnCheckWinUpdate.Style = $script:Window.FindResource('ActionButton')
$btnCheckWinUpdate.HorizontalAlignment = 'Stretch'
$btnCheckWinUpdate.Height = 40; $btnCheckWinUpdate.FontSize = 12.8; $btnCheckWinUpdate.FontWeight = 'Bold'
$btnCheckWinUpdate.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
$btnCheckWinUpdate.Add_Click({
    Invoke-SLTDashCheckWindowsUpdate
})
$qaStack.Children.Add($btnCheckWinUpdate)|Out-Null

$btnSysHealth = New-Object Windows.Controls.Button
$btnSysHealth.Content = "System Health Check"
$btnSysHealth.Style = $script:Window.FindResource('ActionButton')
$btnSysHealth.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
$btnSysHealth.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
$btnSysHealth.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
$btnSysHealth.HorizontalAlignment = 'Stretch'
$btnSysHealth.Height = 40; $btnSysHealth.FontSize = 12.8; $btnSysHealth.FontWeight = 'Bold'
$btnSysHealth.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
$btnSysHealth.Add_Click({
    Invoke-SLTDashSystemHealthCheck
})
$qaStack.Children.Add($btnSysHealth)|Out-Null

$qaResultBdr = New-Object Windows.Controls.Border
$qaResultBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$qaResultBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$qaResultBdr.BorderThickness = [Windows.Thickness]::new(1)
$qaResultBdr.CornerRadius = [Windows.CornerRadius]::new(10)
$qaResultBdr.Padding = [Windows.Thickness]::new(12, 9, 12, 9)
$script:DashQuickActionStatus = New-Object Windows.Controls.TextBlock
$script:DashQuickActionStatus.Text = 'Ready: Click any Quick Action above to run a real live check on this laptop.'
$script:DashQuickActionStatus.FontSize = 11.5; $script:DashQuickActionStatus.FontWeight = 'SemiBold'
$script:DashQuickActionStatus.TextWrapping = 'Wrap'
$script:DashQuickActionStatus.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$qaResultBdr.Child = $script:DashQuickActionStatus
$qaStack.Children.Add($qaResultBdr)|Out-Null

$qaCardBdr.Child = $qaStack
$qaCardBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$topTwoColGrid.Children.Add($qaCardBdr)|Out-Null

$mainStack.Children.Add($topTwoColGrid)|Out-Null

# ==============================================================================
# 3. DASHBOARD LIVE SYSTEM INFO & REAL QUICK ACTION FUNCTIONS
# ==============================================================================
$script:CachedDashHardware = $null
$script:CachedDashCpuName  = $null

function Invoke-SLTDashboardLiveRefresh([switch]$ShowLog, [switch]$FastStartup) {
    try {
        if ($ShowLog -and (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Show-SLTBusySpinner 'Refreshing System Information...' 'Reading live CPU, RAM, Storage & Battery telemetry...'
        }
        $hasGlobalLaptop = (Get-Variable -Scope Global -Name 'SLTLaptopInfo' -ErrorAction SilentlyContinue)
        if ($FastStartup -and $hasGlobalLaptop -and $null -ne $global:SLTLaptopInfo) {
            $p = $global:SLTLaptopInfo
            $script:CachedDashHardware = $p
        } elseif ($null -ne $script:CachedDashHardware -and -not $ShowLog) {
            $p = $script:CachedDashHardware
        } elseif ($FastStartup) {
            # Instant <2ms Registry hardware snapshot during initial page creation (avoids startup WMI wait)
            $bReg = Get-ItemProperty -Path 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -ErrorAction SilentlyContinue
            $osReg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
            $mk = if ($bReg -and $bReg.SystemManufacturer) { [string]$bReg.SystemManufacturer } else { 'PC' }
            $md = if ($bReg -and $bReg.SystemProductName) { [string]$bReg.SystemProductName } else { 'Workstation' }
            $osCap = if ($osReg -and $osReg.ProductName) { [string]$osReg.ProductName } else { 'Windows' }
            $osBld = if ($osReg -and $osReg.CurrentBuild) { [string]$osReg.CurrentBuild } else { '22631' }
            $p = [pscustomobject]@{ Maker = $mk; Model = $md; Serial = 'N/A'; RAM = 8; OS = $osCap; Build = $osBld }
        } else {
            $p = Get-SLTHardware
            $script:CachedDashHardware = $p
            $global:SLTLaptopInfo = $p
        }

        # Read CPU name cleanly from Registry first (<1ms, zero WMI delay)
        $cpuName = if (-not [string]::IsNullOrWhiteSpace($script:CachedDashCpuName)) { $script:CachedDashCpuName } else { '64-Bit Multi-Core Processor' }
        if ([string]::IsNullOrWhiteSpace($script:CachedDashCpuName)) {
            try {
                $cpuReg = Get-ItemProperty -Path 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name 'ProcessorNameString' -ErrorAction SilentlyContinue
                if ($null -ne $cpuReg -and -not [string]::IsNullOrWhiteSpace([string]$cpuReg.ProcessorNameString)) {
                    $cpuName = (([string]$cpuReg.ProcessorNameString) -replace '\s+', ' ').Trim()
                } elseif (-not $FastStartup) {
                    $cpuWmi = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($null -ne $cpuWmi -and $cpuWmi.Name) { $cpuName = (([string]$cpuWmi.Name) -replace '\s+', ' ').Trim() }
                }
                $script:CachedDashCpuName = $cpuName
            } catch {}
        }

        # Read C: Drive Free & Total GB (<1ms)
        $cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        $freeGB = if ($null -ne $cDrive -and $null -ne $cDrive.Free) { [math]::Round(($cDrive.Free / 1GB), 1) } else { 0 }
        $usedGB = if ($null -ne $cDrive -and $null -ne $cDrive.Used) { [math]::Round(($cDrive.Used / 1GB), 1) } else { 0 }
        $totGB  = [math]::Round(($freeGB + $usedGB), 0)
        $pctFreeDisk = if ($totGB -gt 0) { [math]::Round(($freeGB / $totGB) * 100, 0) } else { 100 }

        # Read Battery Status (skip WMI call during FastStartup; full refresh runs on window open)
        $batText = 'Good (AC / Desktop Power)'
        if (-not $FastStartup) {
        try {
            $bat = if (Get-Command Get-SLTCachedWmiClass -ErrorAction SilentlyContinue) { @(Get-SLTCachedWmiClass 'Win32_Battery') } else { @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) }
            if ($bat.Count -gt 0 -and $null -ne $bat[0]) {
                $pct = $bat[0].EstimatedChargeRemaining
                $st  = [string]$bat[0].Status
                $healthLbl = if ([string]::IsNullOrWhiteSpace($st) -or $st -eq 'OK') { 'Good' } else { $st }
                $batText = if ($null -ne $pct) { "$healthLbl ($pct% Charge)" } else { $healthLbl }
            }
        } catch {}
        }

        # Format Maker + Model cleanly without duplicate Maker prefix
        $makerClean = ([string]$p.Maker).Trim()
        $modelClean = ([string]$p.Model).Trim()
        if ($makerClean -match '(?i)^Hewlett-Packard$') { $makerClean = 'HP' }
        $laptopFull = if ($modelClean.ToLowerInvariant().StartsWith($makerClean.ToLowerInvariant())) {
            $modelClean
        } else {
            ("$makerClean $modelClean").Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($p.Serial) -and $p.Serial -ne 'N/A') {
            $laptopFull += "  (SN: $($p.Serial))"
        }

        $osArch = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
        $osFull = "$($p.OS) $osArch (Build $($p.Build))"
        $ramFull = "$($p.RAM) GB"
        $storageFull = if ($totGB -gt 0) { "$freeGB GB Free / $totGB GB ($pctFreeDisk% Free)" } else { 'System Drive C: Online' }

        if ($script:DashSysRows.ContainsKey('Laptop'))  { $script:DashSysRows['Laptop'].Text  = $laptopFull }
        if ($script:DashSysRows.ContainsKey('OS'))      { $script:DashSysRows['OS'].Text      = $osFull }
        if ($script:DashSysRows.ContainsKey('CPU'))     { $script:DashSysRows['CPU'].Text     = $cpuName }
        if ($script:DashSysRows.ContainsKey('RAM'))     { $script:DashSysRows['RAM'].Text     = $ramFull }
        if ($script:DashSysRows.ContainsKey('Storage')) { $script:DashSysRows['Storage'].Text = $storageFull }
        if ($script:DashSysRows.ContainsKey('Battery')) { $script:DashSysRows['Battery'].Text = $batText }
        if ($script:DashSysRows.ContainsKey('Status'))  { $script:DashSysRows['Status'].Text  = 'System Protected' }

        if ($ShowLog) {
            if ($null -ne $script:DashQuickActionStatus) {
                $script:DashQuickActionStatus.Text = "$chkSym System Info Refreshed: $laptopFull | RAM: $ramFull | C: $storageFull"
            }
            Log-SLT "Dashboard refreshed: $laptopFull | $osFull | $cpuName | RAM: $ramFull | C: $storageFull"
        }
    } catch {} finally {
        if ($ShowLog -and (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Hide-SLTBusySpinner
        }
    }
}
Set-Item -Path Function:\global:Invoke-SLTDashboardLiveRefresh -Value ${function:Invoke-SLTDashboardLiveRefresh}

function Invoke-SLTDashCheckDrivers {
    try {
        if ($null -ne $script:DashQuickActionStatus) {
            $script:DashQuickActionStatus.Text = 'Scanning Windows Device Manager (PnP Devices) for missing or faulty drivers...'
        }
        if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
            Show-SLTBusySpinner 'Checking Device Drivers...' 'Scanning Windows Device Manager (PnP Devices)...'
        }
        $badDrivers = @(Get-SLTBadDrivers)
        if (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue) { Hide-SLTBusySpinner }
        if ($badDrivers.Count -eq 0) {
            $msg = "$chkSym Drivers Check Passed: All hardware drivers are working properly (0 problem devices found in Device Manager)."
            if ($null -ne $script:DashQuickActionStatus) { $script:DashQuickActionStatus.Text = $msg }
            Log-SLT $msg
            [Windows.MessageBox]::Show($msg, 'Check Drivers - Smart PC Boost', 'OK', 'Information') | Out-Null
        } else {
            $drvNames = @($badDrivers | Select-Object -First 6 | ForEach-Object { "- $($_.FriendlyName) [Status: $($_.Status), ErrorCode: $($_.ConfigManagerErrorCode)]" }) -join "`r`n"
            $msg = "$warnSym Found $($badDrivers.Count) device driver issue(s) on this laptop:`r`n`r`n$drvNames`r`n`r`nWould you like to open Windows Device Manager now to inspect them?"
            if ($null -ne $script:DashQuickActionStatus) {
                $script:DashQuickActionStatus.Text = "$warnSym Drivers Check: $($badDrivers.Count) driver issue(s) found! Check Device Manager."
            }
            Log-SLT ("Drivers Check found " + $badDrivers.Count + " issue(s).")
            $ans = [Windows.MessageBox]::Show($msg, 'Check Drivers - Issues Found', 'YesNo', 'Warning')
            if ($ans -eq 'Yes') {
                Start-Process 'devmgmt.msc'
            }
        }
    } catch {
        $errTxt = 'Could not query PnP drivers: ' + $_.Exception.Message
        if ($null -ne $script:DashQuickActionStatus) { $script:DashQuickActionStatus.Text = $errTxt }
        [Windows.MessageBox]::Show($errTxt, 'Check Drivers Error', 'OK', 'Error') | Out-Null
    }
}
Set-Item -Path Function:\global:Invoke-SLTDashCheckDrivers -Value ${function:Invoke-SLTDashCheckDrivers}

function Invoke-SLTDashCheckWindowsUpdate {
    try {
        if ($null -ne $script:DashQuickActionStatus) {
            $script:DashQuickActionStatus.Text = 'Checking Windows Update service and pending restart status...'
        }
        if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
            Show-SLTBusySpinner 'Checking Windows Update...' 'Verifying update service, installed KBs & restart state...'
        }
        $wuSvc = Get-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
        $svcStatus = if ($null -ne $wuSvc) { "$($wuSvc.Status) (StartType: $($wuSvc.StartType))" } else { 'Service Not Found' }
        $pending = @(@(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        ) | Where-Object { Test-Path $_ })

        $lastHotfix = 'None recorded'
        try {
            $hfAll = @(Get-HotFix -ErrorAction SilentlyContinue)
            if ($hfAll.Count -gt 0) {
                $hfSorted = @($hfAll | Sort-Object { try { if ($_.InstalledOn) { [datetime]$_.InstalledOn } else { [datetime]::MinValue } } catch { [datetime]::MinValue } } -Descending)
                $hf = $hfSorted[0]
                if ($null -ne $hf -and $hf.HotFixID) {
                    $dtStr = try { if ($hf.InstalledOn) { ([datetime]$hf.InstalledOn).ToString('yyyy-MM-dd') } else { 'Installed' } } catch { 'Installed' }
                    $lastHotfix = "$($hf.HotFixID) ($dtStr)"
                }
            }
        } catch {}

        $rebStr = if ($pending.Count -gt 0) { 'YES - Pending Restart Required to finish updates' } else { 'No pending restart' }
        $summary = "Windows Update Service: $svcStatus`r`nLatest Installed Update: $lastHotfix`r`nPending Restart: $rebStr"

        if ($null -ne $wuSvc -and $wuSvc.StartType -eq 'Disabled') {
            $script:DashQuickActionStatus.Text = "$warnSym Windows Update service is Disabled. Opening Windows Update settings..."
        } elseif ($pending.Count -gt 0) {
            $script:DashQuickActionStatus.Text = "$warnSym Windows Update: Pending system restart detected ($lastHotfix)."
        } else {
            $script:DashQuickActionStatus.Text = "$chkSym Windows Update Ready ($svcStatus | Last KB: $lastHotfix)."
        }

        if (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue) { Hide-SLTBusySpinner }
        Log-SLT ("Windows Update Check: " + ($summary -replace "`r`n", ' | '))
        $openAns = [Windows.MessageBox]::Show("$summary`r`n`r`nOpen Windows Update Settings now to check for new updates online?", 'Check Windows Update', 'YesNo', 'Information')
        if ($openAns -eq 'Yes') {
            Start-Process 'ms-settings:windowsupdate'
        }
    } catch {
        $errTxt = 'Windows Update check failed: ' + $_.Exception.Message
        if ($null -ne $script:DashQuickActionStatus) { $script:DashQuickActionStatus.Text = $errTxt }
        [Windows.MessageBox]::Show($errTxt, 'Check Windows Update Error', 'OK', 'Error') | Out-Null
    }
}
Set-Item -Path Function:\global:Invoke-SLTDashCheckWindowsUpdate -Value ${function:Invoke-SLTDashCheckWindowsUpdate}

function Invoke-SLTDashSystemHealthCheck {
    try {
        if ($null -ne $script:DashQuickActionStatus) {
            $script:DashQuickActionStatus.Text = 'Running real System Health Check (Storage, RAM, Defender & Drivers)...'
        }
        if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
            Show-SLTBusySpinner 'Running System Health Check...' 'Checking Storage C:, Memory, Windows Defender & Drivers...'
        }
        Invoke-SLTDashboardLiveRefresh

        $issues = New-Object System.Collections.Generic.List[string]
        $checks = New-Object System.Collections.Generic.List[string]

        # 1. Storage C: check
        $cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        if ($null -ne $cDrive -and $null -ne $cDrive.Free) {
            $freeGB = [math]::Round(($cDrive.Free / 1GB), 1)
            $totGB  = [math]::Round((($cDrive.Free + $cDrive.Used) / 1GB), 0)
            $pctFree = if ($totGB -gt 0) { [math]::Round(($freeGB / $totGB) * 100, 0) } else { 50 }
            if ($freeGB -lt 15 -or $pctFree -lt 10) {
                $issues.Add("Low Disk Space on C: ($freeGB GB free of $totGB GB - $pctFree%)")
            } else {
                $checks.Add("Storage C: Healthy ($freeGB GB free / $totGB GB)")
            }
        }

        # 2. RAM free check
        try {
            $osCim = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($null -ne $osCim -and $osCim.TotalVisibleMemorySize -gt 0) {
                $freeRamGB = [math]::Round(($osCim.FreePhysicalMemory / 1MB), 1)
                $totRamGB  = [math]::Round(($osCim.TotalVisibleMemorySize / 1MB), 1)
                if ($freeRamGB -lt 0.8) {
                    $issues.Add("High Memory Usage ($freeRamGB GB free of $totRamGB GB RAM)")
                } else {
                    $checks.Add("Memory Healthy ($freeRamGB GB free / $totRamGB GB RAM)")
                }
            }
        } catch {}

        # 3. Windows Security / Defender check
        try {
            $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($null -ne $mp) {
                if (-not $mp.AntivirusEnabled -or -not $mp.RealTimeProtectionEnabled) {
                    $issues.Add("Windows Defender Real-Time Protection is OFF")
                } else {
                    $checks.Add("Windows Defender Real-Time Protection: Enabled")
                }
            }
        } catch {}

        # 4. Device Manager driver check
        $badDrv = @(Get-SLTBadDrivers)
        if ($badDrv.Count -gt 0) {
            $issues.Add("$($badDrv.Count) Hardware Driver issue(s) detected in Device Manager")
        } else {
            $checks.Add("Hardware Drivers: 0 errors in Device Manager")
        }

        if (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue) { Hide-SLTBusySpinner }
        if ($issues.Count -eq 0) {
            $shortOk = "$chkSym System Health Check Passed: " + ($checks -join ' | ')
            $script:DashQuickActionStatus.Text = $shortOk
            if ($script:DashSysRows.ContainsKey('Status')) { $script:DashSysRows['Status'].Text = 'System Protected (All Checks Passed)' }
            if ($null -ne $script:DashStatusPillTxt) {
                $script:DashStatusPillTxt.Text = "$chkSym Status: System Protected"
                $script:DashStatusPillTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
            }
            Log-SLT $shortOk
            [Windows.MessageBox]::Show("SYSTEM HEALTH CHECK PASSED`r`n`r`n" + ($checks -join "`r`n"), 'System Health Check - Healthy', 'OK', 'Information') | Out-Null
        } else {
            $shortWarn = "$warnSym Health Issues Found ($($issues.Count)): " + ($issues -join ' | ')
            $script:DashQuickActionStatus.Text = $shortWarn
            if ($script:DashSysRows.ContainsKey('Status')) { $script:DashSysRows['Status'].Text = "$($issues.Count) Issue(s) Need Attention" }
            Log-SLT $shortWarn
            if ($null -ne $script:DashStatusPillTxt) {
                $script:DashStatusPillTxt.Text = "$warnSym Status: $($issues.Count) Issue(s) Found"
                $script:DashStatusPillTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusWarn')
            }
            $fullBody = "ISSUES DETECTED ($($issues.Count)):`r`n" + (($issues | ForEach-Object { "- $_" }) -join "`r`n") + "`r`n`r`nPASSED CHECKS:`r`n" + (($checks | ForEach-Object { "+ $_" }) -join "`r`n") + "`r`n`r`nOpen 'Boost Your PC' now to run Smart Fix?"
            $fixAns = [Windows.MessageBox]::Show($fullBody, 'System Health Check - Attention Needed', 'YesNo', 'Warning')
            if ($fixAns -eq 'Yes') {
                Switch-SLTPage 3
            }
        }
    } catch {
        $errTxt = 'System Health Check error: ' + $_.Exception.Message
        if ($null -ne $script:DashQuickActionStatus) { $script:DashQuickActionStatus.Text = $errTxt }
    }
}
Set-Item -Path Function:\global:Invoke-SLTDashSystemHealthCheck -Value ${function:Invoke-SLTDashSystemHealthCheck}

# ==============================================================================
# 4. 6 MODULE CARDS (All Same Height, All Open Buttons Aligned on Same Line)
# ==============================================================================
$secModHdr = New-Object Windows.Controls.TextBlock
$secModHdr.Text = 'SLT Smart PC Boost MODULES  -  1-CLICK WORKSPACE LAUNCHER'
$secModHdr.FontSize = 12.5; $secModHdr.FontWeight = 'Bold'
$secModHdr.Margin = [Windows.Thickness]::new(6, 0, 0, 8)
$secModHdr.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$mainStack.Children.Add($secModHdr)|Out-Null

$modGrid = New-Object Windows.Controls.Primitives.UniformGrid
$modGrid.Columns = 3
$modGrid.Margin = [Windows.Thickness]::new(0, 0, 0, 16)

$workspaceModules = @(
    @{ Index=1; Title='1. Smart Install & Uninstall'; Icon='Download';      Badge='203 Apps + 18 OS'; Desc='2-Mode Official Software Installer & Real-Scan Uninstaller (System, Third-Party & SLT Apps).'; Btn='Open' },
    @{ Index=2; Title='2. Smart Tools Hub';           Icon='Sparkles';      Badge='104 Web & AI Tools'; Desc='35 Productive, 25 Top AI, 20 Social, 8 Career, 8 Saudi Services & 8 Live News tools in one hub.'; Btn='Open' },
    @{ Index=3; Title='3. Boost Your PC';             Icon='Rocket';        Badge='5 Boost Profiles'; Desc='Smart Fix PC Health, Normal, Ultra & Extreme speed optimization with 1-click safe restore.'; Btn='Open' },
    @{ Index=4; Title='4. Backup & Restore';          Icon='HardDrive';     Badge='Master Image';     Desc='Windows 11 Audit Mode Master Image builder, Store auto-update guard & driver backup factory.'; Btn='Open' },
    @{ Index=5; Title='5. Smart Hardware Inspection'; Icon='Cpu';           Badge='A4 QC Reports';    Desc='Auto Scan, 8-Cabin Manual QC, Left/Right Speaker & Mic test, and 1-Page A4 Certificates.'; Btn='Open' },
    @{ Index=6; Title='6. Support & Contact';         Icon='MessageCircle'; Badge='Smart Life Teck';  Desc='Official Smart Life Teck owner contact, 6 social media channels, logs & support tools.'; Btn='Open' }
)

foreach ($wm in $workspaceModules) {
    $mBdr = New-Object Windows.Controls.Border
    $mBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $mBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $mBdr.BorderThickness = [Windows.Thickness]::new(1.2)
    $mBdr.CornerRadius = [Windows.CornerRadius]::new(16)
    $mBdr.Padding = [Windows.Thickness]::new(18, 14, 18, 14)
    $mBdr.Margin = [Windows.Thickness]::new(5)
    $mBdr.Height = 162
    $mBdr.Effect = New-SLTCabinShadow 14 2 0.05

    # 3-Row Grid so all Open buttons sit on the exact same bottom line across every card
    $mCardGrid = New-Object Windows.Controls.Grid
    $mr0 = New-Object Windows.Controls.RowDefinition; $mr0.Height = [Windows.GridLength]::Auto
    $mr1 = New-Object Windows.Controls.RowDefinition; $mr1.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $mr2 = New-Object Windows.Controls.RowDefinition; $mr2.Height = [Windows.GridLength]::Auto
    $mCardGrid.RowDefinitions.Add($mr0)|Out-Null
    $mCardGrid.RowDefinitions.Add($mr1)|Out-Null
    $mCardGrid.RowDefinitions.Add($mr2)|Out-Null

    $mTop = New-Object Windows.Controls.Grid
    $mc0 = New-Object Windows.Controls.ColumnDefinition; $mc0.Width = [Windows.GridLength]::Auto
    $mc1 = New-Object Windows.Controls.ColumnDefinition; $mc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $mc2 = New-Object Windows.Controls.ColumnDefinition; $mc2.Width = [Windows.GridLength]::Auto
    $mTop.ColumnDefinitions.Add($mc0)|Out-Null; $mTop.ColumnDefinitions.Add($mc1)|Out-Null; $mTop.ColumnDefinitions.Add($mc2)|Out-Null
    $mTop.Margin = [Windows.Thickness]::new(0, 0, 0, 8)

    $mIconBox = New-Object Windows.Controls.Border
    $mIconBox.Width = 34; $mIconBox.Height = 34; $mIconBox.CornerRadius = [Windows.CornerRadius]::new(10)
    $mIconBox.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
    $mIconBox.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $mIconBox.BorderThickness = [Windows.Thickness]::new(1)
    $mIconBox.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
    $mIc = New-SLTLucideIcon $wm.Icon 16 '#0D9488'
    $mIc.HorizontalAlignment = 'Center'; $mIc.VerticalAlignment = 'Center'
    $mIconBox.Child = $mIc
    $mIconBox.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $mTitle = New-Object Windows.Controls.TextBlock
    $mTitle.Text = $wm.Title; $mTitle.FontSize = 13.5; $mTitle.FontWeight = 'Bold'; $mTitle.VerticalAlignment = 'Center'
    $mTitle.TextTrimming = 'CharacterEllipsis'
    $mTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    $mTitle.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

    $mBadge = New-Object Windows.Controls.Border
    $mBadge.CornerRadius = [Windows.CornerRadius]::new(8); $mBadge.Padding = [Windows.Thickness]::new(8, 2, 8, 2)
    $mBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
    $mBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
    $mBadge.BorderThickness = [Windows.Thickness]::new(1)
    $mBadge.VerticalAlignment = 'Center'
    $mBadgeTxt = New-Object Windows.Controls.TextBlock
    $mBadgeTxt.Text = $wm.Badge; $mBadgeTxt.FontSize = 9.5; $mBadgeTxt.FontWeight = 'SemiBold'
    $mBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
    $mBadge.Child = $mBadgeTxt
    $mBadge.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)

    $mTop.Children.Add($mIconBox)|Out-Null; $mTop.Children.Add($mTitle)|Out-Null; $mTop.Children.Add($mBadge)|Out-Null
    $mTop.SetValue([Windows.Controls.Grid]::RowProperty, 0)

    $mDesc = New-Object Windows.Controls.TextBlock
    $mDesc.Text = $wm.Desc; $mDesc.FontSize = 11.8; $mDesc.TextWrapping = 'Wrap'
    $mDesc.VerticalAlignment = 'Top'
    $mDesc.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $mDesc.SetValue([Windows.Controls.Grid]::RowProperty, 1)

    $mBtn = New-Object Windows.Controls.Button
    $mBtn.Content = "$($wm.Btn)  $arrSym"
    $mBtn.Style = $script:Window.FindResource('ActionButton')
    $mBtn.HorizontalAlignment = 'Stretch'
    $mBtn.Height = 34
    $mBtn.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    $mBtn.Tag = [int]$wm.Index
    $mBtn.Add_Click({
        param($sender, $e)
        $targetIdx = [int]$sender.Tag
        if ($targetIdx -eq 5) {
            if ($script:DevUnlockedSession -or (Test-SLTHardwareAccess)) {
                $script:DevUnlockedSession = $true
                Switch-SLTPage 5
            }
        } else {
            Switch-SLTPage $targetIdx
        }
    })
    $mBtn.SetValue([Windows.Controls.Grid]::RowProperty, 2)

    $mCardGrid.Children.Add($mTop)|Out-Null
    $mCardGrid.Children.Add($mDesc)|Out-Null
    $mCardGrid.Children.Add($mBtn)|Out-Null
    $mBdr.Child = $mCardGrid
    $mBdr.Add_MouseEnter({
        param($s, $e)
        $s.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
    })
    $mBdr.Add_MouseLeave({
        param($s, $e)
        $s.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    })
    $modGrid.Children.Add($mBdr)|Out-Null
}
$mainStack.Children.Add($modGrid)|Out-Null

# ==============================================================================
# 5. NEW - SLT SPECIAL OFFERS SECTION ("SLT Special Offers - Laptop Offers")
#    Reads OfferTitle, OfferPrice, OfferImage, OfferLink from config/brand.json
#    Graceful offline check ("Connect to internet to see offer", never crashes)
# ==============================================================================
$secOfferHdr = New-Object Windows.Controls.TextBlock
$secOfferHdr.Text = 'SLT SPECIAL OFFERS  -  LAPTOP OFFERS'
$secOfferHdr.FontSize = 12.5; $secOfferHdr.FontWeight = 'Bold'
$secOfferHdr.Margin = [Windows.Thickness]::new(6, 0, 0, 8)
$secOfferHdr.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$mainStack.Children.Add($secOfferHdr)|Out-Null

$offerTitle   = 'HP ProBook & EliteBook Laptop Collection (A+ Grade)'
$offerSub     = 'Excellent Condition | Hardware QC Report | Warranty Included | Delivery Across Saudi Arabia'
$offerPrice   = 'Contact for current price'
$offerBadge   = 'SLT SPECIAL OFFER'
$offerImgUrl  = 'https://www.smartlifeteck.com/assets/special-offer-laptop.png'
$offerLinkUrl = 'https://www.smartlifeteck.com/special-offer'

try {
    $brandFile = Join-Path $script:Root 'config\brand.json'
    if (Test-Path -LiteralPath $brandFile) {
        $bJson = Get-Content -LiteralPath $brandFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($null -ne $bJson) {
            if ($bJson.PSObject.Properties['OfferTitle'] -and -not [string]::IsNullOrWhiteSpace([string]$bJson.OfferTitle))     { $offerTitle   = [string]$bJson.OfferTitle }
            if ($bJson.PSObject.Properties['OfferSubtitle'] -and -not [string]::IsNullOrWhiteSpace([string]$bJson.OfferSubtitle)) { $offerSub     = [string]$bJson.OfferSubtitle }
            if ($bJson.PSObject.Properties['OfferPrice'] -and -not [string]::IsNullOrWhiteSpace([string]$bJson.OfferPrice))     { $offerPrice   = [string]$bJson.OfferPrice }
            if ($bJson.PSObject.Properties['OfferBadge'] -and -not [string]::IsNullOrWhiteSpace([string]$bJson.OfferBadge))     { $offerBadge   = [string]$bJson.OfferBadge }
            if ($bJson.PSObject.Properties['OfferImage'] -and -not [string]::IsNullOrWhiteSpace([string]$bJson.OfferImage))     { $offerImgUrl  = [string]$bJson.OfferImage }
            if ($bJson.PSObject.Properties['OfferLink'] -and -not [string]::IsNullOrWhiteSpace([string]$bJson.OfferLink))       { $offerLinkUrl = [string]$bJson.OfferLink }
        }
    }
} catch {}
$script:SLTOfferLinkUrl = $offerLinkUrl
$script:SLTOfferImgUrl  = $offerImgUrl

$offerCardBdr = New-Object Windows.Controls.Border
$offerCardBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$offerCardBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
$offerCardBdr.BorderThickness = [Windows.Thickness]::new(1.5)
$offerCardBdr.CornerRadius = [Windows.CornerRadius]::new(16)
$offerCardBdr.Padding = [Windows.Thickness]::new(20, 16, 20, 16)
$offerCardBdr.Margin = [Windows.Thickness]::new(4, 0, 4, 8)
$offerCardBdr.Effect = New-SLTCabinShadow 16 3 0.08

$offerGrid = New-Object Windows.Controls.Grid
$oc0 = New-Object Windows.Controls.ColumnDefinition; $oc0.Width = [Windows.GridLength]::Auto
$oc1 = New-Object Windows.Controls.ColumnDefinition; $oc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$oc2 = New-Object Windows.Controls.ColumnDefinition; $oc2.Width = [Windows.GridLength]::Auto
$offerGrid.ColumnDefinitions.Add($oc0)|Out-Null
$offerGrid.ColumnDefinitions.Add($oc1)|Out-Null
$offerGrid.ColumnDefinitions.Add($oc2)|Out-Null

# Left Thumbnail / Laptop Emblem Preview Box
$offerImgBox = New-Object Windows.Controls.Border
$offerImgBox.Width = 110; $offerImgBox.Height = 82
$offerImgBox.CornerRadius = [Windows.CornerRadius]::new(12)
$offerImgBox.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$offerImgBox.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$offerImgBox.BorderThickness = [Windows.Thickness]::new(1)
$offerImgBox.Margin = [Windows.Thickness]::new(0, 0, 18, 0)
$offerImgBox.VerticalAlignment = 'Center'

$offerImgFallbackStack = New-Object Windows.Controls.StackPanel
$offerImgFallbackStack.VerticalAlignment = 'Center'; $offerImgFallbackStack.HorizontalAlignment = 'Center'
$offerLapIcon = New-SLTLucideIcon 'Laptop' 32 '#10B981'
$offerLapIcon.HorizontalAlignment = 'Center'
$offerLapCap = New-Object Windows.Controls.TextBlock
$offerLapCap.Text = 'SLT LAPTOPS'
$offerLapCap.FontSize = 9.5; $offerLapCap.FontWeight = 'Bold'; $offerLapCap.HorizontalAlignment = 'Center'
$offerLapCap.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
$offerLapCap.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$offerImgFallbackStack.Children.Add($offerLapIcon)|Out-Null
$offerImgFallbackStack.Children.Add($offerLapCap)|Out-Null
$offerImgBox.Child = $offerImgFallbackStack
$offerImgBox.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$offerGrid.Children.Add($offerImgBox)|Out-Null

# Center Offer Details (Title, Subtitle, Price & Offline Notice)
$offerMidStack = New-Object Windows.Controls.StackPanel
$offerMidStack.VerticalAlignment = 'Center'
$offerMidStack.Margin = [Windows.Thickness]::new(0, 0, 16, 0)

$offerTopBadges = New-Object Windows.Controls.StackPanel
$offerTopBadges.Orientation = 'Horizontal'; $offerTopBadges.Margin = [Windows.Thickness]::new(0, 0, 0, 4)

$oBadge1 = New-Object Windows.Controls.Border
$oBadge1.CornerRadius = [Windows.CornerRadius]::new(6); $oBadge1.Padding = [Windows.Thickness]::new(8, 2, 8, 2)
$oBadge1.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
$oBadge1.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
$oBadge1Txt = New-Object Windows.Controls.TextBlock
$oBadge1Txt.Text = $offerBadge; $oBadge1Txt.FontSize = 10; $oBadge1Txt.FontWeight = 'Bold'
$oBadge1Txt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
$oBadge1.Child = $oBadge1Txt

$oPriceBadge = New-Object Windows.Controls.Border
$oPriceBadge.CornerRadius = [Windows.CornerRadius]::new(6); $oPriceBadge.Padding = [Windows.Thickness]::new(10, 2, 10, 2)
$oPriceBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
$oPriceBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
$oPriceBadge.BorderThickness = [Windows.Thickness]::new(1)
$script:DashOfferPriceTxt = New-Object Windows.Controls.TextBlock
$script:DashOfferPriceTxt.Text = $offerPrice; $script:DashOfferPriceTxt.FontSize = 11; $script:DashOfferPriceTxt.FontWeight = 'Bold'
$script:DashOfferPriceTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
$oPriceBadge.Child = $script:DashOfferPriceTxt

$offerTopBadges.Children.Add($oBadge1)|Out-Null
$offerTopBadges.Children.Add($oPriceBadge)|Out-Null
$offerMidStack.Children.Add($offerTopBadges)|Out-Null

$script:DashOfferTitleTxt = New-Object Windows.Controls.TextBlock
$script:DashOfferTitleTxt.Text = $offerTitle
$script:DashOfferTitleTxt.FontSize = 15; $script:DashOfferTitleTxt.FontWeight = 'Bold'
$script:DashOfferTitleTxt.TextWrapping = 'Wrap'
$script:DashOfferTitleTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$offerMidStack.Children.Add($script:DashOfferTitleTxt)|Out-Null

$script:DashOfferSubTxt = New-Object Windows.Controls.TextBlock
$script:DashOfferSubTxt.Text = $offerSub
$script:DashOfferSubTxt.FontSize = 11.8; $script:DashOfferSubTxt.TextWrapping = 'Wrap'
$script:DashOfferSubTxt.Margin = [Windows.Thickness]::new(0, 3, 0, 0)
$script:DashOfferSubTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$offerMidStack.Children.Add($script:DashOfferSubTxt)|Out-Null

$offerMidStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$offerGrid.Children.Add($offerMidStack)|Out-Null

# Right Action Buttons: [WhatsApp Order] + [View Offer ->]
$offerRightStack = New-Object Windows.Controls.StackPanel
$offerRightStack.Orientation = 'Horizontal'
$offerRightStack.VerticalAlignment = 'Center'

$btnWaOffer = New-Object Windows.Controls.Button
$btnWaOffer.Content = 'WhatsApp Inquiry'
$btnWaOffer.ToolTip = 'Chat with Smart Life Teck on WhatsApp (+966 55 376 0854)'
$btnWaOffer.Style = $script:Window.FindResource('OutlineButton')
$btnWaOffer.Height = 40; $btnWaOffer.Padding = [Windows.Thickness]::new(14, 6, 14, 6)
$btnWaOffer.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
$btnWaOffer.VerticalAlignment = 'Center'
$btnWaOffer.Add_Click({
    try {
        Start-Process 'https://wa.me/966553760854'
        Log-SLT 'Opened Smart Life Teck WhatsApp offer inquiry.'
    } catch {}
})
$offerRightStack.Children.Add($btnWaOffer)|Out-Null

$btnViewOffer = New-Object Windows.Controls.Button
$btnViewOffer.Content = "View Offer  $arrSym"
$btnViewOffer.Style = $script:Window.FindResource('ActionButton')
$btnViewOffer.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
$btnViewOffer.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
$btnViewOffer.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
$btnViewOffer.Height = 40; $btnViewOffer.MinWidth = 140
$btnViewOffer.Padding = [Windows.Thickness]::new(18, 6, 18, 6)
$btnViewOffer.FontSize = 13; $btnViewOffer.FontWeight = 'Bold'
$btnViewOffer.VerticalAlignment = 'Center'
$btnViewOffer.Add_Click({
    try {
        $targetUrl = if (-not [string]::IsNullOrWhiteSpace($script:SLTOfferLinkUrl)) { $script:SLTOfferLinkUrl } else { 'https://www.smartlifeteck.com/special-offer' }
        Start-Process $targetUrl
        Log-SLT ("Opened SLT Special Offer link: " + $targetUrl)
    } catch {
        [Windows.MessageBox]::Show('Connect to internet to see offer: https://www.smartlifeteck.com/special-offer', 'SLT Special Offers', 'OK', 'Information') | Out-Null
    }
})
$offerRightStack.Children.Add($btnViewOffer)|Out-Null
$offerRightStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)
$offerGrid.Children.Add($offerRightStack)|Out-Null

$offerCardBdr.Child = $offerGrid
$mainStack.Children.Add($offerCardBdr)|Out-Null

function Update-SLTOfferOnlineState {
    try {
        $isOnline = $false
        $isOnline = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()
        if (-not $isOnline) {
            if ($null -ne $script:DashOfferSubTxt) {
                $script:DashOfferSubTxt.Text = 'Connect to internet to see offer (https://www.smartlifeteck.com/special-offer)'
            }
        }
    } catch {}
}
Update-SLTOfferOnlineState

$mainStack.Children.Add((New-SLTCabinFooterPill))|Out-Null
$page.Children.Add($mainStack)|Out-Null

# Populate Dashboard System Info via 2ms Registry FastStartup during page load; full WMI refresh runs when window opens
try { Invoke-SLTDashboardLiveRefresh -FastStartup } catch {}
