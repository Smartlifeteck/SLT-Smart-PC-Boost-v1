# ==============================================================================
# pages/02-Install.ps1 (Index 1)
# SLT Smart PC Boost v1.0.0 - 2-Mode Smart Install & Smart Uninstall Hub
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# - Connected 52px Segmented Mode Switcher: [ Smart Install Mode ] [ Smart Uninstall Mode ]
# - Smart Install Mode (Default): 32px toolbar, 203 tools & 18 OS, real-time search,
#   Single badge "[Check] Already Installed" (greyed out, checkbox disabled, no recycle bin),
#   Main button: Install Complete Package (Only New Count)
# - Smart Uninstall Mode: Real PC Scan (Registry + WinGet + Appx), 3 in-window sections:
#   System Apps (X) | Third-Party Apps (Y) | SLT Apps (Z/203) | Total: N
#   Main button: Bulk Uninstall Selected Apps (Count), per-row Recycle Bin with Confirmation Modal,
#   instant auto-refresh after uninstall. (Merged For More Info - Installed Apps / Check Installed Apps)
# ==============================================================================

$emDash    = [char]0x2014
$bulletChr = [char]0x2022
$rocketIco = [char]::ConvertFromUtf32(0x1F680)
$pkgIco    = [char]::ConvertFromUtf32(0x1F4E6)
$searchIco = [char]::ConvertFromUtf32(0x1F50D)
$trashIco  = [char]::ConvertFromUtf32(0x1F5D1)
$warnSym   = [char]0x26A0
$chkSym    = [char]0x2713
$neArrow   = [char]0x2197

$script:SelectedApps          = @{}
$script:SelectedUninstallApps = @{}
$script:UninstallSelectedMap  = @{}
$script:UninstallRowLookup    = @{}
$script:UninstallVisibleCheckboxes = New-Object System.Collections.Generic.List[object]
$script:InstallActiveMode     = 'Install'
$script:InstallUninstallMode  = $false
$script:UninstallActiveFilter = 'ALL'
$script:UninstallFilterPills  = @{}
$script:SuppressSelectAllEvent = $false

# Shared catalog parser in core\10-System.ps1
$script:SltCatalogData  = Get-SLTAppCatalogRecords $script:Root
$script:AppRecords      = $script:SltCatalogData.AppRecords
$script:AppIndex        = $script:SltCatalogData.AppIndex
$script:WebOnlyKeys     = $script:SltCatalogData.WebOnlyKeys
$script:EssentialKeys   = $script:SltCatalogData.EssentialKeys
$script:InstallPriority = $script:SltCatalogData.InstallPriority
if (Get-Command Sync-SLTCatalogWingetIds -ErrorAction SilentlyContinue) { Sync-SLTCatalogWingetIds }
if (Get-Command Sync-SLTPackageWorkerScript -ErrorAction SilentlyContinue) { Sync-SLTPackageWorkerScript }

function Update-SLTStatusLine {
    $sltCnt  = @($script:RealScanSltApps).Count
    $custCnt = @($script:RealScanCustomerApps).Count
    $winCnt  = @($script:RealScanWindowsApps).Count
    $totPc   = $sltCnt + $custCnt + $winCnt
    $hdrTxt  = ("System Apps ({0})   |   Third-Party Apps ({1})   |   SLT Apps ({2}/203)   |   Total: {3}" -f $winCnt, $custCnt, $sltCnt, $totPc)
    if ($null -ne $script:InstallStatusLine) {
        $script:InstallStatusLine.Text = $hdrTxt
    }
    if ($null -ne $script:UninstallCountsHeader) {
        $script:UninstallCountsHeader.Text = $hdrTxt
    }
    if ($null -ne $script:ModeBtnUninstallSub) {
        $script:ModeBtnUninstallSub.Text = ("Real PC Scan $bulletChr {0} Installed Apps Found" -f $totPc)
    }
    # Update filter pill labels in Uninstall Mode
    if ($null -ne $script:UninstallFilterPills) {
        if ($script:UninstallFilterPills.ContainsKey('ALL') -and $null -ne $script:UninstallFilterPills['ALL'].Label) {
            $script:UninstallFilterPills['ALL'].Label.Text = ("All Sections ({0})" -f $totPc)
        }
        if ($script:UninstallFilterPills.ContainsKey('WINDOWS') -and $null -ne $script:UninstallFilterPills['WINDOWS'].Label) {
            $script:UninstallFilterPills['WINDOWS'].Label.Text = ("System Apps ({0})" -f $winCnt)
        }
        if ($script:UninstallFilterPills.ContainsKey('CUSTOMER') -and $null -ne $script:UninstallFilterPills['CUSTOMER'].Label) {
            $script:UninstallFilterPills['CUSTOMER'].Label.Text = ("Third-Party Apps ({0})" -f $custCnt)
        }
        if ($script:UninstallFilterPills.ContainsKey('SLT') -and $null -ne $script:UninstallFilterPills['SLT'].Label) {
            $script:UninstallFilterPills['SLT'].Label.Text = ("SLT Apps ({0}/203)" -f $sltCnt)
        }
    }
}

$page = New-SLTPage 1
$panel = New-SLTPanel 'SMART INSTALL & UNINSTALL' "Smart Installation Hub Select any software and install all at once, silently and officially. Smart Life Teck brings world's famous software in one automatic package. Smart Your Digital Life. By Smart Life Teck | Shahzad Babar"

try {
    if ($panel.Child.Children.Count -ge 2) {
        $script:InstallDescBlock = $panel.Child.Children[1]
        $script:InstallDescBlock.FontSize = 13.0
        $script:InstallDescBlock.Opacity = 1.0
    }
} catch {}

# ==============================================================================
# 1. TOP CONNECTED 52px 2-MODE SEGMENTED SWITCHER
#    [ Smart Install Mode ] [ Smart Uninstall Mode ] (52px height, 0px gap)
# ==============================================================================
$modeOuterBdr = New-Object Windows.Controls.Border
$modeOuterBdr.HorizontalAlignment = 'Center'
$modeOuterBdr.Margin = [Windows.Thickness]::new(0, 10, 0, 12)
$modeOuterBdr.CornerRadius = [Windows.CornerRadius]::new(14)
$modeOuterBdr.Padding = [Windows.Thickness]::new(3)
$modeOuterBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$modeOuterBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$modeOuterBdr.BorderThickness = [Windows.Thickness]::new(1.5)
$modeOuterBdr.Effect = New-SLTCabinShadow 16 3 0.12

$modeRowGrid = New-Object Windows.Controls.Grid
$mc0 = New-Object Windows.Controls.ColumnDefinition; $mc0.Width = New-Object Windows.GridLength(320)
$mc1 = New-Object Windows.Controls.ColumnDefinition; $mc1.Width = New-Object Windows.GridLength(320)
$modeRowGrid.ColumnDefinitions.Add($mc0)|Out-Null
$modeRowGrid.ColumnDefinitions.Add($mc1)|Out-Null

# Left Connected Button: Smart Install Mode (52px)
$script:ModeBtnInstall = New-Object Windows.Controls.Border
$script:ModeBtnInstall.Height = 52
$script:ModeBtnInstall.MinHeight = 52
$script:ModeBtnInstall.CornerRadius = [Windows.CornerRadius]::new(11, 0, 0, 11)
$script:ModeBtnInstall.Margin = [Windows.Thickness]::new(0)
$script:ModeBtnInstall.Padding = [Windows.Thickness]::new(14, 4, 14, 4)
$script:ModeBtnInstall.Cursor = [Windows.Input.Cursors]::Hand
$script:ModeBtnInstall.BorderThickness = [Windows.Thickness]::new(1)

$mInstStack = New-Object Windows.Controls.StackPanel
$mInstStack.VerticalAlignment = 'Center'; $mInstStack.HorizontalAlignment = 'Center'
$script:ModeBtnInstallLbl = New-Object Windows.Controls.TextBlock
$script:ModeBtnInstallLbl.Text = "$pkgIco  Smart Install Mode"
$script:ModeBtnInstallLbl.FontSize = 14; $script:ModeBtnInstallLbl.FontWeight = 'Bold'
$script:ModeBtnInstallLbl.HorizontalAlignment = 'Center'
$script:ModeBtnInstallSub = New-Object Windows.Controls.TextBlock
$script:ModeBtnInstallSub.Text = "203 Official Tools & 18 OS $bulletChr Safe Silent Setup"
$script:ModeBtnInstallSub.FontSize = 10.2; $script:ModeBtnInstallSub.FontWeight = 'SemiBold'
$script:ModeBtnInstallSub.HorizontalAlignment = 'Center'
$mInstStack.Children.Add($script:ModeBtnInstallLbl)|Out-Null
$mInstStack.Children.Add($script:ModeBtnInstallSub)|Out-Null
$script:ModeBtnInstall.Child = $mInstStack
$script:ModeBtnInstall.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

# Right Connected Button: Smart Uninstall Mode (52px)
$script:ModeBtnUninstall = New-Object Windows.Controls.Border
$script:ModeBtnUninstall.Height = 52
$script:ModeBtnUninstall.MinHeight = 52
$script:ModeBtnUninstall.CornerRadius = [Windows.CornerRadius]::new(0, 11, 11, 0)
$script:ModeBtnUninstall.Margin = [Windows.Thickness]::new(0)
$script:ModeBtnUninstall.Padding = [Windows.Thickness]::new(14, 4, 14, 4)
$script:ModeBtnUninstall.Cursor = [Windows.Input.Cursors]::Hand
$script:ModeBtnUninstall.BorderThickness = [Windows.Thickness]::new(1)

$mUninstStack = New-Object Windows.Controls.StackPanel
$mUninstStack.VerticalAlignment = 'Center'; $mUninstStack.HorizontalAlignment = 'Center'
$script:ModeBtnUninstallLbl = New-Object Windows.Controls.TextBlock
$script:ModeBtnUninstallLbl.Text = "$trashIco  Smart Uninstall Mode"
$script:ModeBtnUninstallLbl.FontSize = 14; $script:ModeBtnUninstallLbl.FontWeight = 'Bold'
$script:ModeBtnUninstallLbl.HorizontalAlignment = 'Center'
$script:ModeBtnUninstallSub = New-Object Windows.Controls.TextBlock
$script:ModeBtnUninstallSub.Text = "Real PC Scan $bulletChr System, Third-Party & SLT Apps"
$script:ModeBtnUninstallSub.FontSize = 10.2; $script:ModeBtnUninstallSub.FontWeight = 'SemiBold'
$script:ModeBtnUninstallSub.HorizontalAlignment = 'Center'
$mUninstStack.Children.Add($script:ModeBtnUninstallLbl)|Out-Null
$mUninstStack.Children.Add($script:ModeBtnUninstallSub)|Out-Null
$script:ModeBtnUninstall.Child = $mUninstStack
$script:ModeBtnUninstall.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

$modeRowGrid.Children.Add($script:ModeBtnInstall)|Out-Null
$modeRowGrid.Children.Add($script:ModeBtnUninstall)|Out-Null
$modeOuterBdr.Child = $modeRowGrid
$panel.Child.Children.Add($modeOuterBdr)|Out-Null

# Host containers for total mode switch (no mixed UI!)
$script:InstallModeHost   = New-Object Windows.Controls.StackPanel
$script:UninstallModeHost = New-Object Windows.Controls.StackPanel
$script:UninstallModeHost.Visibility = 'Collapsed'

# ==============================================================================
# 2. MODE 1: SMART INSTALL MODE (Default)
#    - Compact 32px Toolbar: Category [All] + Search [Search tools...] + [Search]
#      + [Reset] + [Select All] checkbox + [Clear All] + [Refresh]
#    - Main Button: [ Install Complete Package (Only New Count) ] (280x52)
#    - Already Installed: shown with single badge "[Check] Already Installed",
#      greyed out, checkbox DISABLED, NO recycle bin icon!
# ==============================================================================
$filterBarBdr = New-Object Windows.Controls.Border
$filterBarBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$filterBarBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$filterBarBdr.BorderThickness = [Windows.Thickness]::new(1)
$filterBarBdr.CornerRadius = [Windows.CornerRadius]::new(12)
$filterBarBdr.Padding = [Windows.Thickness]::new(12, 8, 12, 8)
$filterBarBdr.Margin = [Windows.Thickness]::new(0, 2, 0, 8)

$filter = New-Object Windows.Controls.WrapPanel
$filter.VerticalAlignment = 'Center'
$filter.HorizontalAlignment = 'Center'

$catLbl = New-SLTText 'Category:' 12.2 $true '#F2FAFF'
$catLbl.VerticalAlignment = 'Center'
$catLbl.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
$filter.Children.Add($catLbl)|Out-Null

$script:CategoryCombo = New-Object Windows.Controls.ComboBox
$script:CategoryCombo.Width = 195
$script:CategoryCombo.Height = 32
$script:CategoryCombo.MinHeight = 32
$script:CategoryCombo.FontSize = 12
$script:CategoryCombo.FontWeight = 'SemiBold'
$script:CategoryCombo.VerticalAlignment = 'Center'
$script:CategoryCombo.VerticalContentAlignment = 'Center'
$script:CategoryCombo.Margin = [Windows.Thickness]::new(0, 2, 8, 2)
$orderedCategories = @(
    'All',
    'SLT Essential Package',
    'Operating Systems',
    'SLT PC Tools',
    'Browsers',
    'Office/Docs',
    'Media',
    'Communication',
    'Compression',
    'Remote desktop',
    'Cloud',
    'System utilities',
    'Runtimes',
    'Security',
    'PC health',
    'Design',
    'Video editing',
    'Dev tools',
    'Recovery',
    'Gaming',
    'Open Source Essentials',
    'Manual Install'
)
foreach ($c in $orderedCategories) { $script:CategoryCombo.Items.Add($c)|Out-Null }
$script:CategoryCombo.SelectedIndex = 0
$filter.Children.Add($script:CategoryCombo)|Out-Null

$searchGrid = New-Object Windows.Controls.Grid
$searchGrid.Margin = [Windows.Thickness]::new(0, 2, 6, 2)
$searchGrid.VerticalAlignment = 'Center'
$script:SearchBox = New-Object Windows.Controls.TextBox
$script:SearchBox.Width = 230
$script:SearchBox.Height = 32
$script:SearchBox.FontSize = 12
$script:SearchBox.VerticalContentAlignment = 'Center'
$script:SearchBox.Padding = [Windows.Thickness]::new(10, 3, 10, 3)
$script:SearchBox.ToolTip = 'Search tools in real time (Chrome, LibreOffice, PDFgear, Winux, Tiny11, AnyDesk)...'

$script:SearchPlaceholder = New-Object Windows.Controls.TextBlock
$script:SearchPlaceholder.Text = 'Search tools...'
$script:SearchPlaceholder.FontSize = 12
$script:SearchPlaceholder.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$script:SearchPlaceholder.VerticalAlignment = 'Center'
$script:SearchPlaceholder.Margin = [Windows.Thickness]::new(12, 0, 8, 0)
$script:SearchPlaceholder.IsHitTestVisible = $false
$searchGrid.Children.Add($script:SearchBox)|Out-Null
$searchGrid.Children.Add($script:SearchPlaceholder)|Out-Null
$filter.Children.Add($searchGrid)|Out-Null

$searchBtn = New-Object Windows.Controls.Button
$searchBtn.Content = 'Search'
$searchBtn.Style = $script:Window.FindResource('ActionButton')
$searchBtn.MinHeight = 32; $searchBtn.Height = 32; $searchBtn.Padding = [Windows.Thickness]::new(12, 0, 12, 0)
$searchBtn.Margin = [Windows.Thickness]::new(2, 2, 4, 2); $searchBtn.FontSize = 11.8
$searchBtn.Add_Click({
    param($sender, $e)
    try { Select-SLTButton $sender; Invoke-SLTAppSearch -FromButton $true } catch {}
})
$filter.Children.Add($searchBtn)|Out-Null

$clearSearchBtn = New-Object Windows.Controls.Button
$clearSearchBtn.Content = 'Reset'
$clearSearchBtn.Style = $script:Window.FindResource('OutlineButton')
$clearSearchBtn.MinHeight = 32; $clearSearchBtn.Height = 32; $clearSearchBtn.Padding = [Windows.Thickness]::new(12, 0, 12, 0)
$clearSearchBtn.Margin = [Windows.Thickness]::new(2, 2, 8, 2); $clearSearchBtn.FontSize = 11.8
$clearSearchBtn.ToolTip = 'Clear search, reset category to All, and clear selection'
$clearSearchBtn.Add_Click({
    param($sender, $e)
    try {
        Select-SLTButton $sender
        $script:InstallSearchHighlighted = $false
        $script:SelectedApps.Clear()
        $script:SuppressCategoryEvent = $true
        $script:SuppressSelectAllEvent = $true
        try {
            $script:SearchBox.Text = ''
            $script:CategoryCombo.SelectedIndex = 0
            if ($null -ne $script:InstallSelectAllCb) { $script:InstallSelectAllCb.IsChecked = $false }
        } finally {
            $script:SuppressCategoryEvent = $false
            $script:SuppressSelectAllEvent = $false
        }
        if ($null -ne $script:SearchPlaceholder) { $script:SearchPlaceholder.Visibility = 'Visible' }
        Render-SLTAppCatalog
        Update-SLTInstallCounter
    } catch {}
})
$filter.Children.Add($clearSearchBtn)|Out-Null

$script:InstallSelectAllCb = New-Object Windows.Controls.CheckBox
$script:InstallSelectAllCb.VerticalAlignment = 'Center'
$script:InstallSelectAllCb.Margin = [Windows.Thickness]::new(4, 2, 8, 2)
$script:InstallSelectAllCb.ToolTip = 'Select all visible NOT-installed tools in the current view'
$selAllInstLbl = New-Object Windows.Controls.TextBlock
$selAllInstLbl.Text = 'Select All'
$selAllInstLbl.FontSize = 11.8; $selAllInstLbl.FontWeight = 'SemiBold'
$selAllInstLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$script:InstallSelectAllCb.Content = $selAllInstLbl
$script:InstallSelectAllCb.Add_Checked({
    try {
        if ($script:SuppressSelectAllEvent) { return }
        $catNow = if ($null -ne $script:CategoryCombo -and $null -ne $script:CategoryCombo.SelectedItem) { [string]$script:CategoryCombo.SelectedItem } else { 'All' }
        $qNow = if ($null -ne $script:SearchBox -and $null -ne $script:SearchBox.Text) { $script:SearchBox.Text.Trim() } else { '' }
        foreach ($it in @(Get-SLTFilteredApps -Category $catNow -Query $qNow)) {
            $kStr = [string]$it.Key
            if ($script:WebOnlyKeys.ContainsKey($kStr) -or $it.Group -eq 'OS') { continue }
            $isInst = ($null -ne $script:ScannedInstalledApps -and $script:ScannedInstalledApps.ContainsKey($kStr))
            if (-not $isInst) { $script:SelectedApps[$kStr] = $true }
        }
        Render-SLTAppCatalog
        Update-SLTInstallCounter
    } catch {}
})
$script:InstallSelectAllCb.Add_Unchecked({
    try {
        if ($script:SuppressSelectAllEvent) { return }
        $catNow = if ($null -ne $script:CategoryCombo -and $null -ne $script:CategoryCombo.SelectedItem) { [string]$script:CategoryCombo.SelectedItem } else { 'All' }
        $qNow = if ($null -ne $script:SearchBox -and $null -ne $script:SearchBox.Text) { $script:SearchBox.Text.Trim() } else { '' }
        foreach ($it in @(Get-SLTFilteredApps -Category $catNow -Query $qNow)) {
            $kStr = [string]$it.Key
            $null = $script:SelectedApps.Remove($kStr)
        }
        Render-SLTAppCatalog
        Update-SLTInstallCounter
    } catch {}
})
$filter.Children.Add($script:InstallSelectAllCb)|Out-Null

$btnEssInst = New-Object Windows.Controls.Button
$btnEssInst.Content = 'Essential 16'
$btnEssInst.Style = $script:Window.FindResource('ActionButton')
$btnEssInst.MinHeight = 32; $btnEssInst.Height = 32; $btnEssInst.Padding = [Windows.Thickness]::new(11, 0, 11, 0)
$btnEssInst.Margin = [Windows.Thickness]::new(2, 2, 4, 2); $btnEssInst.FontSize = 11.5
$btnEssInst.ToolTip = '1-Click select all non-installed SLT Essential 16 must-have applications'
$btnEssInst.Add_Click({
    param($sender, $e)
    try {
        Select-SLTButton $sender
        if (Get-Command Select-SLTEssentialNewApps -ErrorAction SilentlyContinue) {
            [void](Select-SLTEssentialNewApps)
        }
    } catch {}
})
$filter.Children.Add($btnEssInst)|Out-Null

$btnOfficeKit = New-Object Windows.Controls.Button
$btnOfficeKit.Content = 'Office & Study'
$btnOfficeKit.Style = $script:Window.FindResource('ActionButton')
$btnOfficeKit.MinHeight = 32; $btnOfficeKit.Height = 32; $btnOfficeKit.Padding = [Windows.Thickness]::new(10, 0, 10, 0)
$btnOfficeKit.Margin = [Windows.Thickness]::new(2, 2, 4, 2); $btnOfficeKit.FontSize = 11.5
$btnOfficeKit.ToolTip = '1-Click select Office, PDF, Browser, Media & Communication essentials'
$btnOfficeKit.Add_Click({
    param($sender, $e)
    try {
        Select-SLTButton $sender
        if (Get-Command Select-SLTOfficeStudyBundle -ErrorAction SilentlyContinue) {
            [void](Select-SLTOfficeStudyBundle)
        }
    } catch {}
})
$filter.Children.Add($btnOfficeKit)|Out-Null

$btnRuntimeKit = New-Object Windows.Controls.Button
$btnRuntimeKit.Content = 'Runtimes Kit'
$btnRuntimeKit.Style = $script:Window.FindResource('ActionButton')
$btnRuntimeKit.MinHeight = 32; $btnRuntimeKit.Height = 32; $btnRuntimeKit.Padding = [Windows.Thickness]::new(10, 0, 10, 0)
$btnRuntimeKit.Margin = [Windows.Thickness]::new(2, 2, 4, 2); $btnRuntimeKit.FontSize = 11.5
$btnRuntimeKit.ToolTip = '1-Click select VC++ x64/x86, .NET 8/9, DirectX, Java & Intel Driver Assistant'
$btnRuntimeKit.Add_Click({
    param($sender, $e)
    try {
        Select-SLTButton $sender
        if (Get-Command Select-SLTRuntimesDriversBundle -ErrorAction SilentlyContinue) {
            [void](Select-SLTRuntimesDriversBundle)
        }
    } catch {}
})
$filter.Children.Add($btnRuntimeKit)|Out-Null

$btnClearAllInst = New-Object Windows.Controls.Button
$btnClearAllInst.Content = 'Clear All'
$btnClearAllInst.Style = $script:Window.FindResource('OutlineButton')
$btnClearAllInst.MinHeight = 32; $btnClearAllInst.Height = 32; $btnClearAllInst.Padding = [Windows.Thickness]::new(12, 0, 12, 0)
$btnClearAllInst.Margin = [Windows.Thickness]::new(2, 2, 4, 2); $btnClearAllInst.FontSize = 11.8
$btnClearAllInst.Add_Click({
    param($sender, $e)
    try {
        Select-SLTButton $sender
        $script:SelectedApps.Clear()
        $script:SuppressSelectAllEvent = $true
        try { if ($null -ne $script:InstallSelectAllCb) { $script:InstallSelectAllCb.IsChecked = $false } } finally { $script:SuppressSelectAllEvent = $false }
        Render-SLTAppCatalog
        Update-SLTInstallCounter
    } catch {}
})
$filter.Children.Add($btnClearAllInst)|Out-Null

$btnRefreshInst = New-Object Windows.Controls.Button
$btnRefreshInst.Content = 'Refresh'
$btnRefreshInst.Style = $script:Window.FindResource('OutlineButton')
$btnRefreshInst.MinHeight = 32; $btnRefreshInst.Height = 32; $btnRefreshInst.Padding = [Windows.Thickness]::new(12, 0, 12, 0)
$btnRefreshInst.Margin = [Windows.Thickness]::new(2, 2, 2, 2); $btnRefreshInst.FontSize = 11.8
$btnRefreshInst.ToolTip = 'Re-scan this PC to refresh Already Installed badges'
$btnRefreshInst.Add_Click({
    param($sender, $e)
    try {
        Select-SLTButton $sender
        if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
            Show-SLTBusySpinner 'Scanning Installed Software...' 'Checking Registry, Windows Apps & SLT Catalog...'
        }
        try {
            if ($null -ne $script:StateDir) {
                foreach ($cn in @('SLT_StartupScanCache.json','SLT_StartupScanCache_v552.json','SLT_StartupScanCache_v553.json')) {
                    $cf = Join-Path $script:StateDir $cn
                    if (Test-Path -LiteralPath $cf -ErrorAction SilentlyContinue) { Remove-Item -LiteralPath $cf -Force -ErrorAction SilentlyContinue }
                }
            }
            $script:RealScanWindowsApps = @()
            Get-RealInstalledApps -OpenModal:$false -QuickRegistryOnly:$false
        } finally {
            if (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue) { Hide-SLTBusySpinner }
        }
    } catch {}
})
$filter.Children.Add($btnRefreshInst)|Out-Null

$filterBarBdr.Child = $filter
$script:InstallModeHost.Children.Add($filterBarBdr)|Out-Null

# Main Action Zone in Smart Install Mode
$centerInstallZone = New-Object Windows.Controls.StackPanel
$centerInstallZone.HorizontalAlignment = 'Center'
$centerInstallZone.Margin = [Windows.Thickness]::new(0, 4, 0, 6)

$primaryBtnRow = New-Object Windows.Controls.WrapPanel
$primaryBtnRow.HorizontalAlignment = 'Center'
$primaryBtnRow.VerticalAlignment = 'Center'

# Main Install Button (280x52 - Only New Count)
$script:InstallMainBtn = New-Object Windows.Controls.Border
$script:InstallMainBtn.Height = 52
$script:InstallMainBtn.Width = 280
$script:InstallMainBtn.MinHeight = 52
$script:InstallMainBtn.CornerRadius = [Windows.CornerRadius]::new(12)
$script:InstallMainBtn.Padding = [Windows.Thickness]::new(14, 4, 14, 4)
$script:InstallMainBtn.Margin = [Windows.Thickness]::new(8, 2, 8, 2)
$script:InstallMainBtn.VerticalAlignment = 'Center'
$script:InstallMainBtn.Cursor = [Windows.Input.Cursors]::Hand
$script:InstallMainBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
$script:InstallMainBtn.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'TextAccent')
$script:InstallMainBtn.BorderThickness = [Windows.Thickness]::new(1.5)
$script:InstallMainBtn.Effect = New-SLTCabinShadow 16 3 0.16
$script:InstallMainBtn.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)
$script:InstallMainBtn.ToolTip = 'Install selected new applications silently (already installed apps are never counted or re-installed).'

$installBtnStack = New-Object Windows.Controls.StackPanel
$installBtnStack.VerticalAlignment = 'Center'
$installBtnStack.IsHitTestVisible = $false

$script:InstallMainBtnLbl = New-Object Windows.Controls.TextBlock
$script:InstallMainBtnLbl.Text = "$rocketIco Install Complete Package (0)"
$script:InstallMainBtnLbl.FontSize = 13.0; $script:InstallMainBtnLbl.FontWeight = 'Bold'
$script:InstallMainBtnLbl.HorizontalAlignment = 'Center'
$script:InstallMainBtnLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')

$script:InstallMainBtnSub2 = New-Object Windows.Controls.TextBlock
$script:InstallMainBtnSub2.Text = "(Only New: 0 $bulletChr 0 MB)"
$script:InstallMainBtnSub2.FontSize = 10.5; $script:InstallMainBtnSub2.FontWeight = 'SemiBold'
$script:InstallMainBtnSub2.HorizontalAlignment = 'Center'
$script:InstallMainBtnSub2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')

$installBtnStack.Children.Add($script:InstallMainBtnLbl)|Out-Null
$installBtnStack.Children.Add($script:InstallMainBtnSub2)|Out-Null
$script:InstallMainBtn.Child = $installBtnStack

$script:InstallMainBtn.Add_MouseEnter({
    param($s, $e)
    try { $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, -2) } catch {}
})
$script:InstallMainBtn.Add_MouseLeave({
    param($s, $e)
    try { $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0) } catch {}
})
$script:InstallMainBtn.Add_MouseLeftButtonUp({
    param($s, $e)
    try { Invoke-SLTAppSelection 'Install' } catch {}
})
$primaryBtnRow.Children.Add($script:InstallMainBtn)|Out-Null

$script:InstallOfflineCacheCb = New-Object Windows.Controls.CheckBox
$script:InstallOfflineCacheCb.IsChecked = $false
$script:InstallOfflineCacheCb.VerticalAlignment = 'Center'
$script:InstallOfflineCacheCb.Margin = [Windows.Thickness]::new(10, 2, 4, 2)
$script:InstallOfflineCacheCb.ToolTip = 'Offline Workshop Cache: Downloads once into SLT_Offline_Cache and installs across multiple laptops.'
$cacheCbLbl = New-Object Windows.Controls.TextBlock
$cacheCbLbl.Text = 'Offline Cache (100 PCs)'
$cacheCbLbl.FontSize = 11.5; $cacheCbLbl.FontWeight = 'SemiBold'
$cacheCbLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$script:InstallOfflineCacheCb.Content = $cacheCbLbl
$primaryBtnRow.Children.Add($script:InstallOfflineCacheCb)|Out-Null

$centerInstallZone.Children.Add($primaryBtnRow)|Out-Null

$script:InstallMainBtnSub = New-Object Windows.Controls.TextBlock
$script:InstallMainBtnSub.Text = 'Silent Official | Skip Installed | Auto-Update Old'
$script:InstallMainBtnSub.FontSize = 10.5
$script:InstallMainBtnSub.HorizontalAlignment = 'Center'
$script:InstallMainBtnSub.Margin = [Windows.Thickness]::new(0, 3, 0, 2)
$script:InstallMainBtnSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$centerInstallZone.Children.Add($script:InstallMainBtnSub)|Out-Null

$script:InstallModeHost.Children.Add($centerInstallZone)|Out-Null

$script:CatalogInfo = New-SLTText '' 11.5 $false '#8DC9EA'
$script:InstallModeHost.Children.Add($script:CatalogInfo)|Out-Null

$script:AppWrap = New-Object Windows.Controls.Primitives.UniformGrid
$script:AppWrap.Columns = 4
$script:AppWrap.VerticalAlignment = 'Top'
$script:AppWrap.Margin = [Windows.Thickness]::new(0, 6, 0, 4)
$script:InstallModeHost.Children.Add($script:AppWrap)|Out-Null

# ==============================================================================
# 3. MODE 2: SMART UNINSTALL MODE (Full In-Window 3-Section View)
#    - Automatically runs REAL scan of THIS laptop on mode switch
#    - Header shows live counts: System Apps (X) | Third-Party Apps (Y) | SLT Apps (Z/203) | Total: N
#    - Main Button: [ Bulk Uninstall Selected Apps (Count) ] (52px)
#    - 3 Sections in same window:
#      1. System Apps (X) - Safe to remove (tagged "Safe")
#      2. Third-Party Apps (Y) - Customer software
#      3. SLT Apps (Z/203) - Installed apps from SLT catalog
#    - Per-row Recycle Bin opens Confirmation Modal ("Are you sure?" + App Name + [Cancel] [Uninstall])
#    - Instant auto-refresh after uninstall
# ==============================================================================
$uninstTopBanner = New-Object Windows.Controls.Border
$uninstTopBanner.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
$uninstTopBanner.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$uninstTopBanner.BorderThickness = [Windows.Thickness]::new(1.2)
$uninstTopBanner.CornerRadius = [Windows.CornerRadius]::new(12)
$uninstTopBanner.Padding = [Windows.Thickness]::new(16, 12, 16, 12)
$uninstTopBanner.Margin = [Windows.Thickness]::new(0, 2, 0, 10)

$uninstBannerStack = New-Object Windows.Controls.StackPanel

$script:UninstallCountsHeader = New-Object Windows.Controls.TextBlock
$script:UninstallCountsHeader.Text = 'System Apps (0)   |   Third-Party Apps (0)   |   SLT Apps (0/203)   |   Total: 0'
$script:UninstallCountsHeader.FontSize = 14.2; $script:UninstallCountsHeader.FontWeight = 'Bold'
$script:UninstallCountsHeader.HorizontalAlignment = 'Center'
$script:UninstallCountsHeader.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
$script:UninstallCountsHeader.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$uninstBannerStack.Children.Add($script:UninstallCountsHeader)|Out-Null

# 32px Uninstall Toolbar
$uninstToolbar = New-Object Windows.Controls.WrapPanel
$uninstToolbar.HorizontalAlignment = 'Center'
$uninstToolbar.VerticalAlignment = 'Center'
$uninstToolbar.Margin = [Windows.Thickness]::new(0, 0, 0, 10)

$pillDefs = @(
    @{ Key='ALL';      Text='All Sections (0)' },
    @{ Key='WINDOWS';  Text='System Apps (0)' },
    @{ Key='CUSTOMER'; Text='Third-Party Apps (0)' },
    @{ Key='SLT';      Text='SLT Apps (0/203)' }
)
foreach ($pd in $pillDefs) {
    $pBdr = New-Object Windows.Controls.Border
    $pBdr.Height = 32; $pBdr.MinHeight = 32
    $pBdr.CornerRadius = [Windows.CornerRadius]::new(8)
    $pBdr.Padding = [Windows.Thickness]::new(11, 0, 11, 0)
    $pBdr.Margin = [Windows.Thickness]::new(2, 2, 4, 2)
    $pBdr.Cursor = [Windows.Input.Cursors]::Hand
    $pBdr.BorderThickness = [Windows.Thickness]::new(1.2)
    $pBdr.Tag = [string]$pd.Key
    $pLbl = New-Object Windows.Controls.TextBlock
    $pLbl.Text = $pd.Text; $pLbl.FontSize = 11.5; $pLbl.FontWeight = 'Bold'; $pLbl.VerticalAlignment = 'Center'
    $pBdr.Child = $pLbl
    $script:UninstallFilterPills[[string]$pd.Key] = @{ Border = $pBdr; Label = $pLbl }
    $pBdr.Add_MouseLeftButtonUp({
        param($s, $e)
        try {
            $script:UninstallActiveFilter = [string]$s.Tag
            $script:SuppressSelectAllEvent = $true
            try { if ($null -ne $script:UninstallSelectAllCb) { $script:UninstallSelectAllCb.IsChecked = $false } } finally { $script:SuppressSelectAllEvent = $false }
            Render-SLTUninstallModeView
        } catch {}
    })
    $uninstToolbar.Children.Add($pBdr)|Out-Null
}

$uSearchGrid = New-Object Windows.Controls.Grid
$uSearchGrid.Margin = [Windows.Thickness]::new(6, 2, 6, 2)
$uSearchGrid.VerticalAlignment = 'Center'
$script:UninstallSearchBox = New-Object Windows.Controls.TextBox
$script:UninstallSearchBox.Width = 210
$script:UninstallSearchBox.Height = 32
$script:UninstallSearchBox.FontSize = 12
$script:UninstallSearchBox.VerticalContentAlignment = 'Center'
$script:UninstallSearchBox.Padding = [Windows.Thickness]::new(10, 3, 10, 3)

$script:UninstallSearchPlaceholder = New-Object Windows.Controls.TextBlock
$script:UninstallSearchPlaceholder.Text = 'Search installed apps...'
$script:UninstallSearchPlaceholder.FontSize = 11.8
$script:UninstallSearchPlaceholder.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$script:UninstallSearchPlaceholder.VerticalAlignment = 'Center'
$script:UninstallSearchPlaceholder.Margin = [Windows.Thickness]::new(12, 0, 8, 0)
$script:UninstallSearchPlaceholder.IsHitTestVisible = $false
$uSearchGrid.Children.Add($script:UninstallSearchBox)|Out-Null
$uSearchGrid.Children.Add($script:UninstallSearchPlaceholder)|Out-Null
$uninstToolbar.Children.Add($uSearchGrid)|Out-Null

$btnResetUninst = New-Object Windows.Controls.Button
$btnResetUninst.Content = 'Reset'
$btnResetUninst.Style = $script:Window.FindResource('OutlineButton')
$btnResetUninst.MinHeight = 32; $btnResetUninst.Height = 32; $btnResetUninst.Padding = [Windows.Thickness]::new(11, 0, 11, 0)
$btnResetUninst.Margin = [Windows.Thickness]::new(2, 2, 6, 2); $btnResetUninst.FontSize = 11.5
$btnResetUninst.Add_Click({
    try {
        $script:UninstallActiveFilter = 'ALL'
        $script:UninstallSelectedMap.Clear()
        $script:SuppressSelectAllEvent = $true
        try {
            $script:UninstallSearchBox.Text = ''
            if ($null -ne $script:UninstallSelectAllCb) { $script:UninstallSelectAllCb.IsChecked = $false }
        } finally {
            $script:SuppressSelectAllEvent = $false
        }
        Render-SLTUninstallModeView
        Update-SLTUninstallCounter
    } catch {}
})
$uninstToolbar.Children.Add($btnResetUninst)|Out-Null

$script:UninstallSelectAllCb = New-Object Windows.Controls.CheckBox
$script:UninstallSelectAllCb.VerticalAlignment = 'Center'
$script:UninstallSelectAllCb.Margin = [Windows.Thickness]::new(4, 2, 6, 2)
$uSelAllLbl = New-Object Windows.Controls.TextBlock
$uSelAllLbl.Text = 'Select All'
$uSelAllLbl.FontSize = 11.8; $uSelAllLbl.FontWeight = 'SemiBold'
$uSelAllLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$script:UninstallSelectAllCb.Content = $uSelAllLbl
$script:UninstallSelectAllCb.Add_Checked({
    try {
        if ($script:SuppressSelectAllEvent) { return }
        foreach ($cb in $script:UninstallVisibleCheckboxes) {
            $cb.IsChecked = $true
        }
        Update-SLTUninstallCounter
    } catch {}
})
$script:UninstallSelectAllCb.Add_Unchecked({
    try {
        if ($script:SuppressSelectAllEvent) { return }
        foreach ($cb in $script:UninstallVisibleCheckboxes) {
            $cb.IsChecked = $false
        }
        Update-SLTUninstallCounter
    } catch {}
})
$uninstToolbar.Children.Add($script:UninstallSelectAllCb)|Out-Null

$btnClearUninst = New-Object Windows.Controls.Button
$btnClearUninst.Content = 'Clear All'
$btnClearUninst.Style = $script:Window.FindResource('OutlineButton')
$btnClearUninst.MinHeight = 32; $btnClearUninst.Height = 32; $btnClearUninst.Padding = [Windows.Thickness]::new(11, 0, 11, 0)
$btnClearUninst.Margin = [Windows.Thickness]::new(2, 2, 4, 2); $btnClearUninst.FontSize = 11.5
$btnClearUninst.Add_Click({
    try {
        $script:UninstallSelectedMap.Clear()
        $script:SuppressSelectAllEvent = $true
        try { if ($null -ne $script:UninstallSelectAllCb) { $script:UninstallSelectAllCb.IsChecked = $false } } finally { $script:SuppressSelectAllEvent = $false }
        Render-SLTUninstallModeView
        Update-SLTUninstallCounter
    } catch {}
})
$uninstToolbar.Children.Add($btnClearUninst)|Out-Null

$btnRescanUninst = New-Object Windows.Controls.Button
$btnRescanUninst.Content = 'Refresh Scan'
$btnRescanUninst.Style = $script:Window.FindResource('ActionButton')
$btnRescanUninst.MinHeight = 32; $btnRescanUninst.Height = 32; $btnRescanUninst.Padding = [Windows.Thickness]::new(12, 0, 12, 0)
$btnRescanUninst.Margin = [Windows.Thickness]::new(2, 2, 2, 2); $btnRescanUninst.FontSize = 11.5
$btnRescanUninst.ToolTip = 'Run fresh scan of Registry, WinGet & Windows Store Apps on this PC'
$btnRescanUninst.Add_Click({
    try {
        if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
            Show-SLTBusySpinner 'Rescanning Installed Software...' 'Reading System Apps, Third-Party Apps & SLT Catalog...'
        }
        try {
            if ($null -ne $script:StateDir) {
                foreach ($cn in @('SLT_StartupScanCache.json','SLT_StartupScanCache_v552.json','SLT_StartupScanCache_v553.json')) {
                    $cf = Join-Path $script:StateDir $cn
                    if (Test-Path -LiteralPath $cf -ErrorAction SilentlyContinue) { Remove-Item -LiteralPath $cf -Force -ErrorAction SilentlyContinue }
                }
            }
            $script:RealScanWindowsApps = @()
            Get-RealInstalledApps -OpenModal:$false -QuickRegistryOnly:$false
            Render-SLTUninstallModeView
            Update-SLTUninstallCounter
        } finally {
            if (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue) { Hide-SLTBusySpinner }
        }
    } catch {}
})
$uninstToolbar.Children.Add($btnRescanUninst)|Out-Null

$uninstBannerStack.Children.Add($uninstToolbar)|Out-Null

# Main 52px Bulk Uninstall Button (Genuine WPF Button so click always fires anywhere on icon/text/border)
$script:BtnMainUninstall = New-Object Windows.Controls.Button
$script:BtnMainUninstall.Style = $script:Window.FindResource('ActionButton')
$script:BtnMainUninstall.Width = 340
$script:BtnMainUninstall.Height = 52
$script:BtnMainUninstall.MinHeight = 52
$script:BtnMainUninstall.Padding = [Windows.Thickness]::new(14, 4, 14, 4)
$script:BtnMainUninstall.Margin = [Windows.Thickness]::new(0, 2, 0, 2)
$script:BtnMainUninstall.HorizontalAlignment = 'Center'
$script:BtnMainUninstall.HorizontalContentAlignment = 'Center'
$script:BtnMainUninstall.VerticalContentAlignment = 'Center'
$script:BtnMainUninstall.Cursor = [Windows.Input.Cursors]::Hand
$script:BtnMainUninstall.Background = (New-SLTBrush '#991B1B')
$script:BtnMainUninstall.BorderBrush = (New-SLTBrush '#EF4444')
$script:BtnMainUninstall.BorderThickness = [Windows.Thickness]::new(1.5)
$script:BtnMainUninstall.Effect = New-SLTCabinShadow 14 3 0.16
$script:BtnMainUninstall.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)

$uninstBtnStack = New-Object Windows.Controls.StackPanel
$uninstBtnStack.VerticalAlignment = 'Center'
$uninstBtnStack.HorizontalAlignment = 'Center'
$uninstBtnStack.IsHitTestVisible = $false

$script:BtnMainUninstallLbl = New-Object Windows.Controls.TextBlock
$script:BtnMainUninstallLbl.Text = "$trashIco Bulk Uninstall Selected Apps (0)"
$script:BtnMainUninstallLbl.FontSize = 13.2; $script:BtnMainUninstallLbl.FontWeight = 'Bold'
$script:BtnMainUninstallLbl.HorizontalAlignment = 'Center'
$script:BtnMainUninstallLbl.Foreground = (New-SLTBrush '#FFFFFF')

$script:BtnMainUninstallSub = New-Object Windows.Controls.TextBlock
$script:BtnMainUninstallSub.Text = '(0 Selected - Check Installed Apps Below)'
$script:BtnMainUninstallSub.FontSize = 10.5; $script:BtnMainUninstallSub.FontWeight = 'SemiBold'
$script:BtnMainUninstallSub.HorizontalAlignment = 'Center'
$script:BtnMainUninstallSub.Foreground = (New-SLTBrush '#FECACA')

$uninstBtnStack.Children.Add($script:BtnMainUninstallLbl)|Out-Null
$uninstBtnStack.Children.Add($script:BtnMainUninstallSub)|Out-Null
$script:BtnMainUninstall.Content = $uninstBtnStack

$script:BtnMainUninstall.Add_MouseEnter({
    param($s, $e)
    try { $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, -2); $s.Background = (New-SLTBrush '#B91C1C') } catch {}
})
$script:BtnMainUninstall.Add_MouseLeave({
    param($s, $e)
    try { $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0); $s.Background = (New-SLTBrush '#991B1B') } catch {}
})
$script:BtnMainUninstall.Add_Click({
    param($s, $e)
    try { Invoke-SLTBulkUninstallSelected } catch { Log-SLT ("BulkUninstall click error: " + $_.Exception.Message) }
})
$uninstBannerStack.Children.Add($script:BtnMainUninstall)|Out-Null

$uninstTopBanner.Child = $uninstBannerStack
$script:UninstallModeHost.Children.Add($uninstTopBanner)|Out-Null

# 3 Sections Container inside Smart Uninstall Mode
$script:UninstallSectionsHost = New-Object Windows.Controls.StackPanel
$script:UninstallModeHost.Children.Add($script:UninstallSectionsHost)|Out-Null

$panel.Child.Children.Add($script:InstallModeHost)|Out-Null
$panel.Child.Children.Add($script:UninstallModeHost)|Out-Null
Add-SLTPanel $page $panel

# ==============================================================================
# 4. MODE SWITCHING & HELPER FUNCTIONS
# ==============================================================================
function Update-SLTModeSwitchVisuals {
    $isInst = ($script:InstallActiveMode -eq 'Install')
    if ($isInst) {
        $script:ModeBtnInstall.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
        $script:ModeBtnInstall.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
        $script:ModeBtnInstallLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
        $script:ModeBtnInstallSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')

        $script:ModeBtnUninstall.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
        $script:ModeBtnUninstall.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
        $script:ModeBtnUninstallLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $script:ModeBtnUninstallSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')

        $script:InstallModeHost.Visibility   = 'Visible'
        $script:UninstallModeHost.Visibility = 'Collapsed'
    } else {
        $script:ModeBtnUninstall.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
        $script:ModeBtnUninstall.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
        $script:ModeBtnUninstallLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
        $script:ModeBtnUninstallSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')

        $script:ModeBtnInstall.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
        $script:ModeBtnInstall.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
        $script:ModeBtnInstallLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $script:ModeBtnInstallSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')

        $script:InstallModeHost.Visibility   = 'Collapsed'
        $script:UninstallModeHost.Visibility = 'Visible'
    }
}

function Switch-SLTInstallTabMode([ValidateSet('Install','Uninstall')][string]$TargetMode) {
    $script:InstallActiveMode = $TargetMode
    $script:InstallUninstallMode = ($TargetMode -eq 'Uninstall')
    Update-SLTModeSwitchVisuals
    if ($TargetMode -eq 'Uninstall') {
        if ($null -eq $script:RealScanAllApps -or @($script:RealScanAllApps).Count -eq 0 -or (@($script:RealScanWindowsApps).Count -eq 0 -and @($script:RealScanCustomerApps).Count -eq 0)) {
            if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
                Show-SLTBusySpinner 'Scanning Installed Software...' 'Reading System Apps, Third-Party Apps & SLT Catalog...'
            }
            try {
                Get-RealInstalledApps -OpenModal:$false -QuickRegistryOnly:$false
            } finally {
                if (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue) { Hide-SLTBusySpinner }
            }
        }
        Render-SLTUninstallModeView
        Update-SLTUninstallCounter
    } else {
        Render-SLTAppCatalog
        Update-SLTInstallCounter
    }
}
Set-Item -Path Function:\global:Switch-SLTInstallTabMode -Value ${function:Switch-SLTInstallTabMode}

$script:ModeBtnInstall.Add_MouseLeftButtonUp({
    try { Switch-SLTInstallTabMode 'Install' } catch {}
})
$script:ModeBtnUninstall.Add_MouseLeftButtonUp({
    try { Switch-SLTInstallTabMode 'Uninstall' } catch {}
})

function Convert-SLTScanRowToPackage([object]$RowItem) {
    return @{
        row_id           = [string]$RowItem.RowId
        key              = [string]$RowItem.SltKey
        name             = [string]$RowItem.Name
        winget           = [string]$RowItem.WingetId
        choco            = 'na'
        url              = ''
        slt_action       = [string]$RowItem.SltAction
        app_category     = [string]$RowItem.AppCategory
        uninstall_string = [string]$RowItem.UninstallString
        quiet_uninstall  = [string]$RowItem.QuietUninstall
        appx_name        = [string]$RowItem.AppxName
        child_name       = [string]$RowItem.ChildName
        size_mb          = [int]$RowItem.SizeMb
        eta_min          = [double]$RowItem.EtaMin
        match_keywords   = @($RowItem.MatchKeywords)
        timeout_sec      = 100
    }
}

function Invoke-SLTSingleAppUninstall([string]$RowOrAppKey) {
    # Opens mandatory Confirmation Modal ("Are you sure?" + App Name + [Cancel] [Uninstall])
    try {
        if (Get-Command Sync-SLTPackageWorkerScript -ErrorAction SilentlyContinue) { Sync-SLTPackageWorkerScript }
        $rObj = $null
        if ($script:UninstallRowLookup.ContainsKey($RowOrAppKey)) {
            $rObj = $script:UninstallRowLookup[$RowOrAppKey]
        } else {
            foreach ($ri in @($script:RealScanAllApps)) {
                if ($null -ne $ri -and [string]$ri.RowId -eq $RowOrAppKey) { $rObj = $ri; break }
            }
        }
        if ($null -ne $rObj) {
            $confirmed = Confirm-SLTUninstallModal -TitleText ("Are you sure? - Uninstall " + $rObj.Name) -MessageText ("Are you sure you want to uninstall `"$($rObj.Name)`" ($($rObj.Version)) from this PC?")
            if (-not $confirmed) { return }
            $singlePkg = Convert-SLTScanRowToPackage $rObj
            Start-SLTQueue -Packages @($singlePkg) -Verb 'Uninstall' -Manager 'WinGet' -OfflineCache $false -AutoUpgrade $false
            return
        }
        if ($script:AppIndex.ContainsKey($RowOrAppKey)) {
            $ap = $script:AppIndex[$RowOrAppKey]
            $confirmed = Confirm-SLTUninstallModal -TitleText ("Are you sure? - Uninstall " + $ap.Name) -MessageText ("Are you sure you want to uninstall `"$($ap.Name)`" from this PC?")
            if (-not $confirmed) { return }
            $pkg = @{
                key            = $ap.Key
                name           = $ap.Name
                winget         = $ap.Winget
                choco          = 'na'
                url            = $ap.Url
                slt_action     = $ap.SltAction
                app_category   = 'SLT'
                size_mb        = $ap.SizeMb
                eta_min        = $ap.EtaMin
                match_keywords = $ap.MatchKeywords
                timeout_sec    = 100
            }
            Start-SLTQueue -Packages @($pkg) -Verb 'Uninstall' -Manager 'WinGet' -OfflineCache $false -AutoUpgrade $false
        }
    } catch {}
}
Set-Item -Path Function:\global:Invoke-SLTSingleAppUninstall -Value ${function:Invoke-SLTSingleAppUninstall}

function Get-SLTCheckedUninstallRowIds {
    $checkedIds = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    if ($null -ne $script:UninstallVisibleCheckboxes) {
        foreach ($cb in $script:UninstallVisibleCheckboxes) {
            if ($null -ne $cb -and $null -ne $cb.Tag) {
                $rid = [string]$cb.Tag
                $isChk = ($cb.IsChecked -eq $true)
                $script:UninstallSelectedMap[$rid] = $isChk
                if ($isChk -and (-not $seen.ContainsKey($rid))) {
                    $seen[$rid] = $true
                    $checkedIds.Add($rid)
                }
            }
        }
    }
    if ($null -ne $script:UninstallSelectedMap) {
        foreach ($k in @($script:UninstallSelectedMap.Keys)) {
            $ks = [string]$k
            if ($script:UninstallSelectedMap[$ks] -eq $true -and (-not $seen.ContainsKey($ks))) {
                $seen[$ks] = $true
                $checkedIds.Add($ks)
            }
        }
    }
    return $checkedIds.ToArray()
}
Set-Item -Path Function:\global:Get-SLTCheckedUninstallRowIds -Value ${function:Get-SLTCheckedUninstallRowIds}

function Update-SLTUninstallCounter {
    $selIds = @(Get-SLTCheckedUninstallRowIds)
    $cnt = $selIds.Count
    if ($null -ne $script:BtnMainUninstallLbl) {
        $script:BtnMainUninstallLbl.Text = ("$trashIco Bulk Uninstall Selected Apps ({0})" -f $cnt)
    }
    if ($null -ne $script:BtnMainUninstallSub) {
        if ($cnt -gt 0) {
            $script:BtnMainUninstallSub.Text = ("({0} Selected $bulletChr Click to Uninstall)" -f $cnt)
        } else {
            $script:BtnMainUninstallSub.Text = '(0 Selected - Check Installed Apps Below)'
        }
    }
}
Set-Item -Path Function:\global:Update-SLTUninstallCounter -Value ${function:Update-SLTUninstallCounter}

function Render-SLTUninstallModeView {
    if ($null -eq $script:UninstallSectionsHost) { return }
    $script:UninstallSectionsHost.Children.Clear()
    $script:UninstallVisibleCheckboxes.Clear()
    $script:UninstallRowLookup = @{}

    foreach ($ri in @($script:RealScanAllApps)) {
        if ($null -ne $ri) {
            $script:UninstallRowLookup[[string]$ri.RowId] = $ri
        }
    }

    Update-SLTStatusLine

    # Highlight active filter pill
    foreach ($pk in $script:UninstallFilterPills.Keys) {
        $pObj = $script:UninstallFilterPills[$pk]
        if ($pk -eq $script:UninstallActiveFilter) {
            $pObj.Border.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
            $pObj.Border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            $pObj.Label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
        } else {
            $pObj.Border.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
            $pObj.Border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            $pObj.Label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        }
    }

    $qUn = if ($null -ne $script:UninstallSearchBox -and $null -ne $script:UninstallSearchBox.Text) { $script:UninstallSearchBox.Text.Trim().ToLowerInvariant() } else { '' }
    if ($null -ne $script:UninstallSearchPlaceholder) {
        $hasFocus = ($null -ne $script:UninstallSearchBox -and $script:UninstallSearchBox.IsKeyboardFocused)
        $script:UninstallSearchPlaceholder.Visibility = $(if ([string]::IsNullOrEmpty($qUn) -and (-not $hasFocus)) { 'Visible' } else { 'Collapsed' })
    }

    $winCnt  = @($script:RealScanWindowsApps).Count
    $custCnt = @($script:RealScanCustomerApps).Count
    $sltCnt  = @($script:RealScanSltApps).Count

    $sectionsToRender = @(
        @{ Key='WINDOWS';  Title="1. SYSTEM APPS $emDash SAFE TO UNINSTALL ($winCnt)";        Sub='Pre-installed Windows bloatware apps (Clipchamp, Xbox, Solitaire, etc.) that are 100% safe to remove. Critical Windows components are hidden.'; Items=@($script:RealScanWindowsApps);  BadgeBg='#064E3B'; BadgeBorder='#10B981'; BadgeFg='#6EE7B7' },
        @{ Key='CUSTOMER'; Title="2. THIRD-PARTY APPS $emDash INSTALLED ON THIS PC ($custCnt)"; Sub='Customer and third-party software currently installed on this laptop.';                                                                  Items=@($script:RealScanCustomerApps); BadgeBg='#0C4A6E'; BadgeBorder='#38BDF8'; BadgeFg='#7DD3FC' },
        @{ Key='SLT';      Title="3. SLT APPS $emDash SMART LIFE TECK CATALOG ($sltCnt/203)";   Sub='Applications from the official 203-app Smart Life Teck catalog currently installed on this laptop.';                                    Items=@($script:RealScanSltApps);      BadgeBg='#78350F'; BadgeBorder='#F59E0B'; BadgeFg='#FDE68A' }
    )

    $conv = [Windows.Media.BrushConverter]::new()

    foreach ($sec in $sectionsToRender) {
        if ($script:UninstallActiveFilter -ne 'ALL' -and $script:UninstallActiveFilter -ne $sec.Key) { continue }

        $filteredItems = New-Object System.Collections.Generic.List[object]
        foreach ($it in $sec.Items) {
            if ($null -eq $it) { continue }
            if ($qUn -eq '' -or ([string]$it.Name).ToLowerInvariant().Contains($qUn) -or ([string]$it.Publisher).ToLowerInvariant().Contains($qUn)) {
                $filteredItems.Add($it)
            }
        }

        $secBdr = New-Object Windows.Controls.Border
        $secBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
        $secBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $secBdr.BorderThickness = [Windows.Thickness]::new(1.2)
        $secBdr.CornerRadius = [Windows.CornerRadius]::new(14)
        $secBdr.Padding = [Windows.Thickness]::new(16, 12, 16, 12)
        $secBdr.Margin = [Windows.Thickness]::new(0, 0, 0, 12)

        $secStack = New-Object Windows.Controls.StackPanel

        $sHdr = New-Object Windows.Controls.TextBlock
        $sHdr.Text = $sec.Title
        $sHdr.FontSize = 14.5; $sHdr.FontWeight = 'Bold'
        $sHdr.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $secStack.Children.Add($sHdr)|Out-Null

        $sSub = New-Object Windows.Controls.TextBlock
        $sSub.Text = $sec.Sub
        $sSub.FontSize = 11.5; $sSub.Margin = [Windows.Thickness]::new(0, 2, 0, 10)
        $sSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $secStack.Children.Add($sSub)|Out-Null

        if ($filteredItems.Count -eq 0) {
            $emptyTxt = New-SLTText 'No installed applications found in this section.' 12 $false '#94A3B8'
            $secStack.Children.Add($emptyTxt)|Out-Null
        } else {
            $secGrid = New-Object Windows.Controls.Primitives.UniformGrid
            $secGrid.Columns = 2
            foreach ($appRow in $filteredItems) {
                $isRowChecked = ($script:UninstallSelectedMap.ContainsKey([string]$appRow.RowId) -and [bool]$script:UninstallSelectedMap[[string]$appRow.RowId])
                $rowCard = New-Object Windows.Controls.Border
                $rowCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
                if ($isRowChecked) {
                    $rowCard.BorderBrush = $conv.ConvertFromString('#EF4444')
                    $rowCard.BorderThickness = [Windows.Thickness]::new(1.6)
                } else {
                    $rowCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
                    $rowCard.BorderThickness = [Windows.Thickness]::new(1)
                }
                $rowCard.CornerRadius = [Windows.CornerRadius]::new(10)
                $rowCard.Padding = [Windows.Thickness]::new(12, 8, 12, 8)
                $rowCard.Margin = [Windows.Thickness]::new(4)
                $rowCard.Cursor = [Windows.Input.Cursors]::Hand

                $rGrid = New-Object Windows.Controls.Grid
                $rc0 = New-Object Windows.Controls.ColumnDefinition; $rc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
                $rc1 = New-Object Windows.Controls.ColumnDefinition; $rc1.Width = [Windows.GridLength]::Auto
                $rGrid.ColumnDefinitions.Add($rc0)|Out-Null
                $rGrid.ColumnDefinitions.Add($rc1)|Out-Null

                $cb = New-Object Windows.Controls.CheckBox
                $cb.Tag = [string]$appRow.RowId
                $cb.IsEnabled = $true
                $cb.IsChecked = $isRowChecked
                $cb.VerticalAlignment = 'Center'
                $cb.Margin = [Windows.Thickness]::new(2, 0, 8, 0)
                $rowCard.Tag = $cb

                $cbStack = New-Object Windows.Controls.StackPanel
                $nmTb = New-Object Windows.Controls.TextBlock
                $nmTb.Text = [string]$appRow.Name
                $nmTb.FontSize = 12.6; $nmTb.FontWeight = 'Bold'; $nmTb.TextTrimming = 'CharacterEllipsis'
                $nmTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
                $subTb = New-Object Windows.Controls.TextBlock
                $subTb.Text = ("Publisher: {0}   |   Version: {1}" -f $appRow.Publisher, $appRow.Version)
                $subTb.FontSize = 10.2; $subTb.TextTrimming = 'CharacterEllipsis'
                $subTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
                $cbStack.Children.Add($nmTb)|Out-Null
                $cbStack.Children.Add($subTb)|Out-Null
                $cb.Content = $cbStack

                $cb.Add_Checked({
                    param($s, $e)
                    try {
                        $script:UninstallSelectedMap[[string]$s.Tag] = $true
                        if ($null -ne $s.Parent -and $null -ne $s.Parent.Parent -and $s.Parent.Parent -is [Windows.Controls.Border]) {
                            $s.Parent.Parent.BorderBrush = (New-SLTBrush '#EF4444')
                            $s.Parent.Parent.BorderThickness = [Windows.Thickness]::new(1.6)
                        }
                        Update-SLTUninstallCounter
                    } catch {}
                })
                $cb.Add_Unchecked({
                    param($s, $e)
                    try {
                        $script:UninstallSelectedMap[[string]$s.Tag] = $false
                        if ($null -ne $s.Parent -and $null -ne $s.Parent.Parent -and $s.Parent.Parent -is [Windows.Controls.Border]) {
                            $s.Parent.Parent.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
                            $s.Parent.Parent.BorderThickness = [Windows.Thickness]::new(1)
                        }
                        Update-SLTUninstallCounter
                    } catch {}
                })
                $cb.Add_Click({
                    param($s, $e)
                    try {
                        $script:UninstallSelectedMap[[string]$s.Tag] = ($s.IsChecked -eq $true)
                        Update-SLTUninstallCounter
                    } catch {}
                })
                $rowCard.Add_MouseLeftButtonUp({
                    param($s, $e)
                    try {
                        $src = $e.OriginalSource
                        while ($null -ne $src -and $src -ne $s) {
                            if ($src -is [Windows.Controls.Primitives.ButtonBase]) { return }
                            $src = try { [Windows.Media.VisualTreeHelper]::GetParent($src) } catch { $null }
                        }
                        if ($null -ne $s.Tag -and $s.Tag -is [Windows.Controls.CheckBox]) {
                            $s.Tag.IsChecked = (-not [bool]$s.Tag.IsChecked)
                        }
                    } catch {}
                })

                $script:UninstallVisibleCheckboxes.Add($cb)|Out-Null
                $cb.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
                $rGrid.Children.Add($cb)|Out-Null

                # Right side: Single Badge ("Safe" / "Third-Party" / "SLT App") + Recycle Bin Button
                $rightPanel = New-Object Windows.Controls.StackPanel
                $rightPanel.Orientation = 'Horizontal'
                $rightPanel.VerticalAlignment = 'Center'

                $catBadge = New-Object Windows.Controls.Border
                $catBadge.Background = $conv.ConvertFromString($sec.BadgeBg)
                $catBadge.BorderBrush = $conv.ConvertFromString($sec.BadgeBorder)
                $catBadge.BorderThickness = [Windows.Thickness]::new(1)
                $catBadge.CornerRadius = [Windows.CornerRadius]::new(6)
                $catBadge.Padding = [Windows.Thickness]::new(8, 2, 8, 2)
                $catBadge.Margin = [Windows.Thickness]::new(4, 0, 6, 0)
                $catBadge.VerticalAlignment = 'Center'
                $catBadgeTxt = New-Object Windows.Controls.TextBlock
                $catBadgeTxt.Text = [string]$appRow.BadgeText
                $catBadgeTxt.FontSize = 9.5; $catBadgeTxt.FontWeight = 'Bold'
                $catBadgeTxt.Foreground = $conv.ConvertFromString($sec.BadgeFg)
                $catBadge.Child = $catBadgeTxt
                $rightPanel.Children.Add($catBadge)|Out-Null

                $rowTrashBtn = New-Object Windows.Controls.Button
                $rowTrashBtn.Content = $trashIco
                $rowTrashBtn.Tag = [string]$appRow.RowId
                $rowTrashBtn.ToolTip = ('Uninstall ' + [string]$appRow.Name + ' (asks confirmation first)')
                $rowTrashBtn.Style = $script:Window.FindResource('OutlineButton')
                $rowTrashBtn.MinHeight = 28; $rowTrashBtn.Height = 28; $rowTrashBtn.Width = 32
                $rowTrashBtn.Padding = [Windows.Thickness]::new(2, 0, 2, 0)
                $rowTrashBtn.Margin = [Windows.Thickness]::new(0)
                $rowTrashBtn.Foreground = $conv.ConvertFromString('#EF4444')
                $rowTrashBtn.BorderBrush = $conv.ConvertFromString('#DC2626')
                $rowTrashBtn.Add_Click({
                    param($s, $e)
                    try { Invoke-SLTSingleAppUninstall ([string]$s.Tag) } catch {}
                })
                $rightPanel.Children.Add($rowTrashBtn)|Out-Null

                $rightPanel.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
                $rGrid.Children.Add($rightPanel)|Out-Null

                $rowCard.Child = $rGrid
                $secGrid.Children.Add($rowCard)|Out-Null
            }
            $secStack.Children.Add($secGrid)|Out-Null
        }

        $secBdr.Child = $secStack
        $script:UninstallSectionsHost.Children.Add($secBdr)|Out-Null
    }
}
Set-Item -Path Function:\global:Render-SLTUninstallModeView -Value ${function:Render-SLTUninstallModeView}

# Backward-compatible aliases (Installed Apps - For More Info - Installed Apps / Check Installed Apps merged into Smart Uninstall Mode)
function Show-InstalledAppsModal {
    Switch-SLTInstallTabMode 'Uninstall'
}
Set-Item -Path Function:\global:Show-InstalledAppsModal -Value ${function:Show-InstalledAppsModal}

function Show-SLTScanInstalledWindow {
    Switch-SLTInstallTabMode 'Uninstall'
}
Set-Item -Path Function:\global:Show-SLTScanInstalledWindow -Value ${function:Show-SLTScanInstalledWindow}

$script:UninstallSearchBox.Add_GotFocus({
    try {
        if ($null -ne $script:UninstallSearchPlaceholder) { $script:UninstallSearchPlaceholder.Visibility = 'Collapsed' }
        $script:UninstallSearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
    } catch {}
})
$script:UninstallSearchBox.Add_LostFocus({
    try {
        if ($null -ne $script:UninstallSearchPlaceholder -and [string]::IsNullOrEmpty($script:UninstallSearchBox.Text)) {
            $script:UninstallSearchPlaceholder.Visibility = 'Visible'
        }
        $script:UninstallSearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'InputBorder')
    } catch {}
})
$script:UninstallSearchBox.Add_TextChanged({
    try { Render-SLTUninstallModeView } catch {}
})
$script:UninstallSearchBox.Add_KeyDown({
    param($s, $e)
    try {
        if ($e.Key -eq 'Escape') {
            $e.Handled = $true
            $script:UninstallSearchBox.Text = ''
            Render-SLTUninstallModeView
        } elseif ($e.Key -eq 'Return' -or $e.Key -eq 'Enter') {
            $e.Handled = $true
            Render-SLTUninstallModeView
        }
    } catch {}
})

# ==============================================================================
# 5. INSTALL MODE CATALOG RENDERING & REAL-TIME SEARCH
# ==============================================================================
$script:InstallPulseTimer = New-Object Windows.Threading.DispatcherTimer
$script:InstallPulseTimer.Interval = [TimeSpan]::FromMilliseconds(450)
$script:InstallPulseTimer.Add_Tick({
    try {
        if ($null -eq $script:InstallMainBtn) { return }
        if ($script:CurrentPageIndex -ne 1 -or $script:InstallActiveMode -ne 'Install') { return }
        $script:InstallPulsePhase = (-not $script:InstallPulsePhase)
        if ($script:SelectedApps.Count -gt 0) {
            $script:InstallMainBtn.BorderThickness = if ($script:InstallPulsePhase) { [Windows.Thickness]::new(2.2) } else { [Windows.Thickness]::new(1.4) }
        } else {
            $script:InstallMainBtn.BorderThickness = [Windows.Thickness]::new(1.5)
        }
    } catch {}
})
$script:InstallPulseTimer.Start()

$script:InstallAnimTimer = New-Object Windows.Threading.DispatcherTimer
$script:InstallAnimTimer.Interval = [TimeSpan]::FromMilliseconds(28)
$script:InstallAnimTimer.Add_Tick({
    try {
        $diffMb  = $script:InstallAnimTargetMb - $script:InstallAnimCurrentMb
        $diffEta = $script:InstallAnimTargetEta - $script:InstallAnimCurrentEta
        if ([Math]::Abs($diffMb) -lt 4.0 -and [Math]::Abs($diffEta) -lt 0.15) {
            $script:InstallAnimCurrentMb  = $script:InstallAnimTargetMb
            $script:InstallAnimCurrentEta = $script:InstallAnimTargetEta
            $script:InstallAnimCurrentCnt = $script:InstallAnimTargetCnt
            $script:InstallAnimTimer.Stop()
        } else {
            $script:InstallAnimCurrentMb  += ($diffMb * 0.38)
            $script:InstallAnimCurrentEta += ($diffEta * 0.38)
            $script:InstallAnimCurrentCnt  = $script:InstallAnimTargetCnt
        }
        Update-SLTInstallButtonText -Count $script:InstallAnimCurrentCnt -SizeMb $script:InstallAnimCurrentMb -EtaMin $script:InstallAnimCurrentEta
    } catch {}
})

function Format-SLTSizeText([double]$Mb) {
    if ($Mb -ge 1000.0) {
        return ('{0:N1} GB' -f ($Mb / 1024.0))
    }
    return ('{0:N0} MB' -f [Math]::Max(1, [Math]::Round($Mb)))
}

function Update-SLTInstallButtonText([int]$Count, [double]$SizeMb, [double]$EtaMin) {
    if ($null -eq $script:InstallMainBtnLbl) { return }
    $newKeys = New-Object System.Collections.Generic.List[string]
    $newMb = 0.0
    foreach ($sk in @($script:SelectedApps.Keys)) {
        if (-not $script:WebOnlyKeys.ContainsKey([string]$sk)) {
            if ($null -eq $script:ScannedInstalledApps -or -not $script:ScannedInstalledApps.ContainsKey([string]$sk)) {
                $newKeys.Add([string]$sk)
                if ($script:AppIndex.ContainsKey([string]$sk)) {
                    $newMb += [double]$script:AppIndex[[string]$sk].SizeMb
                }
            }
        }
    }
    $newCnt = $newKeys.Count
    if ($newCnt -le 0) {
        $script:InstallMainBtnLbl.Text = "$rocketIco Install Complete Package (0)"
        if ($null -ne $script:InstallMainBtnSub2) {
            $script:InstallMainBtnSub2.Text = "(Only New: 0 $bulletChr 0 MB)"
        }
    } else {
        $szStr = Format-SLTSizeText $newMb
        $script:InstallMainBtnLbl.Text = ("$rocketIco Install Complete Package ({0})" -f $newCnt)
        if ($null -ne $script:InstallMainBtnSub2) {
            $script:InstallMainBtnSub2.Text = ("(Only New: {0} {1} {2})" -f $newCnt, $bulletChr, $szStr)
        }
    }
}

function Get-SLTFilteredApps([string]$Category, [string]$Query) {
    $q = if ($null -ne $Query) { $Query.Trim().ToLowerInvariant() } else { '' }
    $cat = if (-not [string]::IsNullOrWhiteSpace($Category)) { $Category } else { 'All' }

    $arPairs = @(
        @{ Ar = '\u0643\u0631\u0648\u0645'; En = 'chrome' },
        @{ Ar = '\u062C\u0648\u062C\u0644'; En = 'google' },
        @{ Ar = '\u0627\u0648\u0641\u064A\u0633'; En = 'office' },
        @{ Ar = '\u0645\u064A\u0643\u0631\u0648\u0633\u0648\u0641\u062A'; En = 'microsoft' },
        @{ Ar = '\u0628\u064A \u062F\u064A \u0627\u0641'; En = 'pdf' },
        @{ Ar = '\u0648\u0627\u062A\u0633\u0627\u0628'; En = 'whatsapp' },
        @{ Ar = '\u062A\u0644\u062C\u0631\u0627\u0645'; En = 'telegram' },
        @{ Ar = '\u0632\u0648\u0645'; En = 'zoom' },
        @{ Ar = '\u0641\u0643 \u0627\u0644\u0636\u063A\u0637'; En = '7-zip' },
        @{ Ar = '\u0636\u063A\u0637'; En = 'winrar' },
        @{ Ar = '\u0645\u064A\u062F\u064A\u0627'; En = 'vlc' },
        @{ Ar = '\u0641\u064A\u062F\u064A\u0648'; En = 'vlc' },
        @{ Ar = '\u0648\u064A\u0646\u062F\u0648\u0632'; En = 'windows' },
        @{ Ar = '\u0644\u064A\u0646\u0643\u0633'; En = 'linux' },
        @{ Ar = '\u0627\u0646\u062F\u0631\u0648\u064A\u062F'; En = 'android' },
        @{ Ar = '\u062A\u0639\u0631\u064A\u0628'; En = 'arabic' },
        @{ Ar = '\u0639\u0631\u0628\u064A'; En = 'arabic' },
        @{ Ar = '\u0627\u0646\u064A \u062F\u064A\u0633\u0643'; En = 'anydesk' },
        @{ Ar = '\u0627\u062F\u0648\u0627\u062A'; En = 'smart tools' }
    )
    foreach ($ap in $arPairs) {
        $arWord = [regex]::Unescape($ap.Ar)
        if ($q.Contains($arWord)) { $q = $ap.En; break }
    }

    if ([string]::IsNullOrEmpty($q)) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($rec in $script:AppRecords) {
            $matchCat = $false
            if ($cat -eq 'All') {
                $matchCat = ($rec.Group -ne 'OS')
            } elseif ($cat -eq 'SLT Essential Package') {
                $matchCat = ($rec.Essential -eq $true)
            } elseif ($cat -eq 'SLT PC Tools') {
                $matchCat = ($rec.Essential -eq $true -or $rec.Category -in @('System utilities','Office/Docs'))
            } else {
                $matchCat = ($rec.Category -eq $cat)
            }

            if ($matchCat) {
                $grpOrder = if ($rec.Group -eq 'OS') { 0 } elseif ($rec.Group -eq 'B' -and (-not $rec.Essential)) { 1 } else { 0 }
                $tierOrder = if ($cat -eq 'SLT Essential Package') { 0 } else { [int]$rec.Tier }
                $prioOrder = if ($cat -eq 'SLT Essential Package') { [int]$rec.EssentialRank } else { [int]$rec.Priority }
                $list.Add([pscustomobject]@{
                    Grp  = $grpOrder
                    Tier = $tierOrder
                    Prio = $prioOrder
                    Name = [string]$rec.Name
                    Item = $rec
                })
            }
        }
        $sorted = @($list | Sort-Object Grp, Tier, Prio, Name)
        $out = New-Object System.Collections.Generic.List[object]
        foreach ($entry in $sorted) { $out.Add($entry.Item) }
        return $out.ToArray()
    }

    $escaped = [regex]::Escape($q)
    $wordRegex = New-Object System.Text.RegularExpressions.Regex(('(?:^|[\s\-\(\)/\.])' + $escaped), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $skipDescWords = @('win','windows','pro','app','tool','free','setup','install')

    $scored = New-Object System.Collections.Generic.List[object]
    foreach ($rec in $script:AppRecords) {
        if ($cat -ne 'All') {
            if ($cat -eq 'SLT Essential Package' -and (-not $rec.Essential)) { continue }
            elseif ($cat -eq 'SLT PC Tools' -and (-not ($rec.Essential -or $rec.Category -in @('System utilities','Office/Docs')))) { continue }
            elseif ($cat -notin @('SLT Essential Package','SLT PC Tools') -and $rec.Category -ne $cat) { continue }
        }
        $nameL = ([string]$rec.Name).ToLowerInvariant()
        $keyL  = ([string]$rec.Key).ToLowerInvariant()
        $widL  = ([string]$rec.Winget).ToLowerInvariant()
        $catL  = ([string]$rec.Category).ToLowerInvariant()
        $descL = ([string]$rec.Description).ToLowerInvariant()
        $osBestL = ([string]$rec.OsBestFor).ToLowerInvariant()

        $score = 0
        if ($nameL -eq $q -or $widL -eq $q -or $keyL -eq $q) {
            $score = 1
        } elseif ($nameL.StartsWith($q) -or $widL.StartsWith($q)) {
            $score = 2
        } elseif ($wordRegex.IsMatch($nameL) -or $wordRegex.IsMatch($widL)) {
            $score = 3
        } elseif ($q.Length -ge 2 -and ($nameL.Contains($q) -or $widL.Contains($q) -or $osBestL.Contains($q))) {
            $score = 4
        } elseif ($wordRegex.IsMatch($catL)) {
            $score = 5
        } elseif ($q.Length -ge 3 -and ($skipDescWords -notcontains $q) -and $wordRegex.IsMatch($descL)) {
            $score = 6
        }

        if ($score -gt 0) {
            $scored.Add([pscustomobject]@{
                Score = $score
                Tier  = [int]$rec.Tier
                Prio  = [int]$rec.Priority
                Name  = [string]$rec.Name
                Item  = $rec
            })
        }
    }

    $sortedMatches = @($scored | Sort-Object Score, Tier, Prio, Name)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($m in $sortedMatches) { $out.Add($m.Item) }
    return $out.ToArray()
}

function Invoke-SLTAppSearch([bool]$FromButton=$false) {
    if ($null -eq $script:SearchBox) { return }
    $q = ([string]$script:SearchBox.Text).Trim()
    if ([string]::IsNullOrEmpty($q)) {
        $script:InstallSearchHighlighted = $false
        Render-SLTAppCatalog
        return
    }
    $script:InstallSearchHighlighted = $FromButton
    Render-SLTAppCatalog
}

function Render-SLTAppCatalog {
    if ($null -eq $script:AppWrap) { return }
    $script:AppWrap.Children.Clear()
    $cat = if ($null -ne $script:CategoryCombo -and $null -ne $script:CategoryCombo.SelectedItem) { [string]$script:CategoryCombo.SelectedItem } else { 'All' }
    $q = if ($null -ne $script:SearchBox -and $null -ne $script:SearchBox.Text) { $script:SearchBox.Text.Trim() } else { '' }
    if ($null -ne $script:SearchPlaceholder) {
        $hasFocus = ($null -ne $script:SearchBox -and $script:SearchBox.IsKeyboardFocused)
        $script:SearchPlaceholder.Visibility = $(if ([string]::IsNullOrEmpty($q) -and (-not $hasFocus)) { 'Visible' } else { 'Collapsed' })
    }
    $result = @(Get-SLTFilteredApps -Category $cat -Query $q)

    $script:AppWrap.Columns = if ($cat -eq 'Operating Systems') { 3 } else { 4 }

    $newSelCount = @(Get-SLTSelectedNewAppsList).Count
    if ($q -ne '') {
        $script:CatalogInfo.Text = ('Search Results for "{0}": {1} matching item(s)  |  {2} new selected' -f $q, $result.Count, $newSelCount)
    } elseif ($cat -eq 'SLT Essential Package') {
        $script:CatalogInfo.Text = ('SLT Essential Package (16 Must-Have Tools)  |  {0} new selected' -f $newSelCount)
    } elseif ($cat -eq 'Operating Systems') {
        $script:CatalogInfo.Text = 'Operating Systems Hub (18 Verified OS across 4 Sub-Groups): Official Windows, Lite Builders, Windows-Style Hybrid & Android/Linux Pro.'
    } else {
        $script:CatalogInfo.Text = ('{0} tools visible (4-Tier Smart Sorted)  |  {1} new selected' -f $result.Count, $newSelCount)
    }

    if ($result.Count -eq 0) {
        $emptyCard = New-Object Windows.Controls.Border
        $emptyCard.MinHeight = 88
        $emptyCard.Margin = [Windows.Thickness]::new(4)
        $emptyCard.Padding = [Windows.Thickness]::new(14, 10, 14, 10)
        $emptyCard.CornerRadius = [Windows.CornerRadius]::new(12)
        $emptyCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
        $emptyCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $emptyCard.BorderThickness = [Windows.Thickness]::new(1.2)
        $emptyTxt = New-SLTText ('No software found matching "' + $q + '". Click Reset to view all tools.') 12.5 $true '#D97706'
        $emptyCard.Child = $emptyTxt
        $script:AppWrap.Children.Add($emptyCard)|Out-Null
        return
    }

    foreach ($item in $result) {
        $isOs     = ($item.Group -eq 'OS' -or $item.Category -eq 'Operating Systems')
        $isManual = $script:WebOnlyKeys.ContainsKey([string]$item.Key)
        $isDetectedInstalled = ($null -ne $script:ScannedInstalledApps -and $script:ScannedInstalledApps.ContainsKey([string]$item.Key))
        $isCheckedInstall    = (-not $isManual) -and (-not $isDetectedInstalled) -and $script:SelectedApps.ContainsKey([string]$item.Key)

        $card = New-Object Windows.Controls.Border
        $card.MinHeight = if ($isOs) { 148 } else { 88 }
        $card.Margin = [Windows.Thickness]::new(5)
        $card.CornerRadius = [Windows.CornerRadius]::new(12)
        $card.Padding = [Windows.Thickness]::new(12, 9, 12, 9)
        $card.HorizontalAlignment = 'Stretch'
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
        $card.Effect = New-SLTCabinShadow 10 2 0.08

        if ($isDetectedInstalled) {
            # Greyed out card for Already Installed in Install Mode
            $card.Opacity = 0.65
            $card.BorderBrush = (New-SLTBrush '#10B981')
            $card.BorderThickness = [Windows.Thickness]::new(1.4)
        } elseif ($isCheckedInstall -or ($q -ne '' -and $script:InstallSearchHighlighted)) {
            $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            $card.BorderThickness = [Windows.Thickness]::new(1.8)
        } else {
            $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
            $card.BorderThickness = [Windows.Thickness]::new(1)
        }

        if ($isOs) {
            $s = New-Object Windows.Controls.StackPanel
            $s.VerticalAlignment = 'Center'
            $osSubRow = New-Object Windows.Controls.Grid
            $osc0 = New-Object Windows.Controls.ColumnDefinition; $osc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
            $osc1 = New-Object Windows.Controls.ColumnDefinition; $osc1.Width = [Windows.GridLength]::Auto
            $osSubRow.ColumnDefinitions.Add($osc0)|Out-Null; $osSubRow.ColumnDefinitions.Add($osc1)|Out-Null

            $osGrpTxt = New-Object Windows.Controls.TextBlock
            $osGrpTxt.Text = [string]$item.OsGroup
            $osGrpTxt.FontSize = 9.5; $osGrpTxt.FontWeight = 'SemiBold'
            $osGrpTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            $osSubRow.Children.Add($osGrpTxt)|Out-Null

            $osTypeBadge = New-Object Windows.Controls.Border
            $osTypeBadge.CornerRadius = [Windows.CornerRadius]::new(5)
            $osTypeBadge.Padding = [Windows.Thickness]::new(6, 1.5, 6, 1.5)
            $osTypeBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
            $osTypeBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            $osTypeBadge.BorderThickness = [Windows.Thickness]::new(1)
            $osTypeTxt = New-Object Windows.Controls.TextBlock
            $osTypeTxt.Text = [string]$item.OsBadge
            $osTypeTxt.FontSize = 8.5; $osTypeTxt.FontWeight = 'Bold'
            if (-not [string]::IsNullOrWhiteSpace($item.OsWarning)) {
                $osTypeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusWarn')
            } else {
                $osTypeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            }
            $osTypeBadge.Child = $osTypeTxt
            $osTypeBadge.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
            $osSubRow.Children.Add($osTypeBadge)|Out-Null
            $s.Children.Add($osSubRow)|Out-Null

            $osNameTb = New-Object Windows.Controls.TextBlock
            $osNameTb.Text = [string]$item.Name
            $osNameTb.FontSize = 13; $osNameTb.FontWeight = 'Bold'
            $osNameTb.TextWrapping = 'NoWrap'; $osNameTb.TextTrimming = 'CharacterEllipsis'
            $osNameTb.Margin = [Windows.Thickness]::new(0, 4, 0, 3)
            $osNameTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
            $osNameTb.ToolTip = [string]$item.Description
            $s.Children.Add($osNameTb)|Out-Null

            $specsBar = New-Object Windows.Controls.TextBlock
            $specsBar.Text = ("RAM: {0}   |   Size: {1}" -f $item.OsRam, $item.OsSize)
            $specsBar.FontSize = 10.5; $specsBar.FontWeight = 'SemiBold'
            $specsBar.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $s.Children.Add($specsBar)|Out-Null

            $bestTb = New-Object Windows.Controls.TextBlock
            $bestTb.Text = ("Best For: " + [string]$item.OsBestFor)
            $bestTb.FontSize = 10.5; $bestTb.TextWrapping = 'Wrap'
            $bestTb.Margin = [Windows.Thickness]::new(0, 2, 0, 4)
            $bestTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            $s.Children.Add($bestTb)|Out-Null

            if (-not [string]::IsNullOrWhiteSpace($item.OsWarning)) {
                $warnBdr = New-Object Windows.Controls.Border
                $warnBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
                $warnBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'SLTStatusWarn')
                $warnBdr.BorderThickness = [Windows.Thickness]::new(1)
                $warnBdr.CornerRadius = [Windows.CornerRadius]::new(6)
                $warnBdr.Padding = [Windows.Thickness]::new(7, 3, 7, 3)
                $warnBdr.Margin = [Windows.Thickness]::new(0, 2, 0, 5)
                $warnTb = New-Object Windows.Controls.TextBlock
                $warnTb.Text = ("$warnSym " + [string]$item.OsWarning)
                $warnTb.FontSize = 9.5; $warnTb.FontWeight = 'Bold'; $warnTb.TextWrapping = 'Wrap'
                $warnTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusWarn')
                $warnBdr.Child = $warnTb
                $s.Children.Add($warnBdr)|Out-Null
            }

            $osBotRow = New-Object Windows.Controls.Grid
            $osBotRow.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
            $ob0 = New-Object Windows.Controls.ColumnDefinition; $ob0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
            $ob1 = New-Object Windows.Controls.ColumnDefinition; $ob1.Width = [Windows.GridLength]::Auto
            $osBotRow.ColumnDefinitions.Add($ob0)|Out-Null; $osBotRow.ColumnDefinitions.Add($ob1)|Out-Null

            $verLbl = New-Object Windows.Controls.TextBlock
            $verLbl.Text = "$chkSym Official Verified"
            $verLbl.FontSize = 9.8; $verLbl.VerticalAlignment = 'Center'
            $verLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
            $osBotRow.Children.Add($verLbl)|Out-Null

            $osBtn = New-Object Windows.Controls.Button
            $osBtn.Content = "Official Link $neArrow"
            $osBtn.Tag = [string]$item.Url
            $osBtn.ToolTip = ('Open verified official link for ' + [string]$item.Name + ': ' + [string]$item.Url)
            $osBtn.Style = $script:Window.FindResource('ActionButton')
            $osBtn.MinHeight = 27; $osBtn.Height = 27
            $osBtn.Padding = [Windows.Thickness]::new(12, 2, 12, 2)
            $osBtn.FontSize = 10.8
            $osBtn.Add_Click({
                param($sender, $args)
                try {
                    Select-SLTButton $sender
                    Open-SLTAppOfficialLink ([string]$sender.Tag) ([string]$sender.ToolTip)
                } catch {}
            })
            $osBtn.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
            $osBotRow.Children.Add($osBtn)|Out-Null
            $s.Children.Add($osBotRow)|Out-Null
            $card.Child = $s
        } elseif ($isManual) {
            $cardGrid = New-Object Windows.Controls.Grid
            $s = New-Object Windows.Controls.StackPanel
            $s.VerticalAlignment = 'Center'

            $nameTb = New-Object Windows.Controls.TextBlock
            $nameTb.Text = [string]$item.Name
            $nameTb.FontSize = 12.6; $nameTb.FontWeight = 'Bold'
            $nameTb.TextWrapping = 'NoWrap'; $nameTb.TextTrimming = 'CharacterEllipsis'
            $nameTb.Margin = [Windows.Thickness]::new(0, 0, 95, 0)
            $nameTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
            $nameTb.ToolTip = [string]$item.Description
            $s.Children.Add($nameTb)|Out-Null

            if (-not [string]::IsNullOrWhiteSpace($item.Note)) {
                $noteTb = New-Object Windows.Controls.TextBlock
                $noteTb.Text = [string]$item.Note
                $noteTb.FontSize = 9.5; $noteTb.TextWrapping = 'NoWrap'; $noteTb.TextTrimming = 'CharacterEllipsis'
                $noteTb.Margin = [Windows.Thickness]::new(0, 3, 0, 2)
                $noteTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusWarn')
                $s.Children.Add($noteTb)|Out-Null
            }

            $botRow = New-Object Windows.Controls.Grid; $botRow.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
            $bc0 = New-Object Windows.Controls.ColumnDefinition; $bc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
            $bc1 = New-Object Windows.Controls.ColumnDefinition; $bc1.Width = [Windows.GridLength]::Auto
            $botRow.ColumnDefinitions.Add($bc0)|Out-Null; $botRow.ColumnDefinitions.Add($bc1)|Out-Null

            $catSub = New-Object Windows.Controls.TextBlock
            $catSub.Text = [string]$item.Category
            $catSub.FontSize = 10; $catSub.VerticalAlignment = 'Center'
            $catSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            $botRow.Children.Add($catSub)|Out-Null

            $dlBtn = New-Object Windows.Controls.Button
            $dlBtn.Content = if (-not [string]::IsNullOrWhiteSpace($item.BtnLabel)) { [string]$item.BtnLabel } else { 'Download' }
            $dlBtn.Tag = [string]$item.Url
            $dlBtn.ToolTip = ('Open official download page for ' + [string]$item.Name + ': ' + [string]$item.Url)
            $dlBtn.Style = $script:Window.FindResource('ActionButton')
            $dlBtn.MinHeight = 25; $dlBtn.Height = 25
            $dlBtn.Padding = [Windows.Thickness]::new(10, 1, 10, 1)
            $dlBtn.Margin = [Windows.Thickness]::new(0)
            $dlBtn.FontSize = 10.2
            $dlBtn.Add_Click({
                param($sender, $args)
                try {
                    Select-SLTButton $sender
                    Open-SLTAppOfficialLink ([string]$sender.Tag) ([string]$sender.ToolTip)
                } catch {}
            })
            $dlBtn.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
            $botRow.Children.Add($dlBtn)|Out-Null
            $s.Children.Add($botRow)|Out-Null
            $cardGrid.Children.Add($s)|Out-Null

            # Single badge ONLY
            $manBadge = New-Object Windows.Controls.Border
            $manBadge.CornerRadius = [Windows.CornerRadius]::new(8); $manBadge.Padding = [Windows.Thickness]::new(6, 2, 6, 2)
            $manBadge.HorizontalAlignment = 'Right'; $manBadge.VerticalAlignment = 'Top'
            if ($isDetectedInstalled) {
                $manBadge.Background = (New-SLTBrush '#10B981')
            } else {
                $manBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardDeep')
                $manBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
                $manBadge.BorderThickness = [Windows.Thickness]::new(1)
            }
            $manBadgeTxt = New-Object Windows.Controls.TextBlock
            $manBadgeTxt.Text = if ($isDetectedInstalled) { "$chkSym Already Installed" } elseif ($item.Key -eq 'a_microsoft_office') { 'LICENSED' } else { 'MANUAL' }
            $manBadgeTxt.FontSize = 8.5; $manBadgeTxt.FontWeight = 'Bold'
            if ($isDetectedInstalled) {
                $manBadgeTxt.Foreground = (New-SLTBrush '#FFFFFF')
            } else {
                $manBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            }
            $manBadge.Child = $manBadgeTxt
            $cardGrid.Children.Add($manBadge)|Out-Null
            $card.Child = $cardGrid
        } else {
            # ==================================================================
            # SMART INSTALL MODE CARD:
            # - Already Installed: shown in list, greyed out, checkbox DISABLED,
            #   ONE single badge only: "Already Installed"
            # - NO recycle bin icon in Install Mode at all!
            # ==================================================================
            $cardGrid = New-Object Windows.Controls.Grid

            $sContent = New-Object Windows.Controls.StackPanel
            $sContent.VerticalAlignment = 'Center'

            $cb = New-Object Windows.Controls.CheckBox
            $cb.Tag = [string]$item.Key
            $cb.Margin = [Windows.Thickness]::new(0, 2, 0, 0)

            $caption = New-Object Windows.Controls.TextBlock
            $caption.Text = [string]$item.Name
            $caption.TextWrapping = 'NoWrap'
            $caption.TextTrimming = 'CharacterEllipsis'
            $caption.MaxWidth = if ($isDetectedInstalled) { 135 } else { 190 }
            $caption.FontSize = 12.6; $caption.FontWeight = 'SemiBold'
            if ($isDetectedInstalled) {
                $caption.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            } else {
                $caption.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
            }
            $cb.Content = $caption

            if ($isDetectedInstalled) {
                $cb.IsEnabled = $false
                $cb.IsChecked = $false
                $cb.ToolTip = 'Already Installed on this PC - Switch to Smart Uninstall Mode if you wish to remove it.'
            } else {
                $cb.IsEnabled = $true
                $cb.IsChecked = $isCheckedInstall
                $cb.ToolTip = ([string]$item.Description + '  |  Size: ~' + [string]$item.SizeMb + ' MB')
                $card.Cursor = [Windows.Input.Cursors]::Hand
                $card.Tag = $cb
                $cb.Add_Checked({
                    param($sender, $args)
                    try {
                        $script:SelectedApps[[string]$sender.Tag] = $true
                        if ($null -ne $sender.Parent -and $null -ne $sender.Parent.Parent -and $null -ne $sender.Parent.Parent.Parent -and $sender.Parent.Parent.Parent -is [Windows.Controls.Border]) {
                            $sender.Parent.Parent.Parent.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
                            $sender.Parent.Parent.Parent.BorderThickness = [Windows.Thickness]::new(1.8)
                        }
                        Update-SLTInstallCounter
                    } catch {}
                })
                $cb.Add_Unchecked({
                    param($sender, $args)
                    try {
                        $null = $script:SelectedApps.Remove([string]$sender.Tag)
                        if ($null -ne $sender.Parent -and $null -ne $sender.Parent.Parent -and $null -ne $sender.Parent.Parent.Parent -and $sender.Parent.Parent.Parent -is [Windows.Controls.Border]) {
                            $sender.Parent.Parent.Parent.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
                            $sender.Parent.Parent.Parent.BorderThickness = [Windows.Thickness]::new(1)
                        }
                        Update-SLTInstallCounter
                    } catch {}
                })
                $card.Add_MouseLeftButtonUp({
                    param($s, $e)
                    try {
                        $src = $e.OriginalSource
                        while ($null -ne $src -and $src -ne $s) {
                            if ($src -is [Windows.Controls.Primitives.ButtonBase]) { return }
                            $src = try { [Windows.Media.VisualTreeHelper]::GetParent($src) } catch { $null }
                        }
                        if ($null -ne $s.Tag -and $s.Tag -is [Windows.Controls.CheckBox] -and $s.Tag.IsEnabled) {
                            $s.Tag.IsChecked = (-not [bool]$s.Tag.IsChecked)
                        }
                    } catch {}
                })
            }
            $sContent.Children.Add($cb)|Out-Null

            # Bottom row: Category + Size ONLY (No Recycle Bin in Install Mode!)
            $metaRow = New-Object Windows.Controls.Grid; $metaRow.Margin = [Windows.Thickness]::new(2, 10, 0, 0)
            $mc0 = New-Object Windows.Controls.ColumnDefinition; $mc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
            $mc1 = New-Object Windows.Controls.ColumnDefinition; $mc1.Width = [Windows.GridLength]::Auto
            $metaRow.ColumnDefinitions.Add($mc0)|Out-Null; $metaRow.ColumnDefinitions.Add($mc1)|Out-Null

            $catLbl2 = New-Object Windows.Controls.TextBlock
            $catLbl2.Text = [string]$item.Category; $catLbl2.FontSize = 10.2
            $catLbl2.VerticalAlignment = 'Center'
            $catLbl2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
            $catLbl2.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
            $metaRow.Children.Add($catLbl2)|Out-Null

            $szLbl = New-Object Windows.Controls.TextBlock
            $szLbl.Text = ("~{0} MB" -f $item.SizeMb)
            $szLbl.FontSize = 9.8
            $szLbl.VerticalAlignment = 'Center'
            $szLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            $szLbl.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
            $metaRow.Children.Add($szLbl)|Out-Null

            $sContent.Children.Add($metaRow)|Out-Null
            $cardGrid.Children.Add($sContent)|Out-Null

            # Single badge ONLY at top-right: "Already Installed"
            if ($isDetectedInstalled) {
                $instPill = New-Object Windows.Controls.Border
                $instPill.CornerRadius = [Windows.CornerRadius]::new(8)
                $instPill.Padding = [Windows.Thickness]::new(6, 2, 6, 2)
                $instPill.HorizontalAlignment = 'Right'
                $instPill.VerticalAlignment = 'Top'
                $instPill.Background = (New-SLTBrush '#10B981')
                $instPillTxt = New-Object Windows.Controls.TextBlock
                $instPillTxt.Text = "$chkSym Already Installed"
                $instPillTxt.FontSize = 8.8; $instPillTxt.FontWeight = 'Bold'
                $instPillTxt.Foreground = (New-SLTBrush '#FFFFFF')
                $instPill.Child = $instPillTxt
                $cardGrid.Children.Add($instPill)|Out-Null
            }

            $card.Child = $cardGrid
        }

        $script:AppWrap.Children.Add($card)|Out-Null
    }
}

function Update-SLTInstallCounter {
    $selKeys = @(Get-SLTSelectedNewAppsList)
    $cnt = $selKeys.Count
    $totMb = 0.0
    $totEta = 0.0
    foreach ($k in $selKeys) {
        if ($script:AppIndex.ContainsKey([string]$k)) {
            $rec = $script:AppIndex[[string]$k]
            $totMb  += [double]$rec.SizeMb
            $totEta += [double]$rec.EtaMin
        }
    }

    $script:InstallAnimTargetCnt = $cnt
    $script:InstallAnimTargetMb  = $totMb
    $script:InstallAnimTargetEta = $totEta
    if ($null -ne $script:InstallAnimTimer) {
        $script:InstallAnimTimer.Start()
    } else {
        Update-SLTInstallButtonText -Count $cnt -SizeMb $totMb -EtaMin $totEta
    }

    Update-SLTInstallButtonText -Count $cnt -SizeMb $totMb -EtaMin $totEta

    if ($null -ne $script:CatalogInfo) {
        $script:CatalogInfo.Text = [regex]::Replace($script:CatalogInfo.Text, '\d+ new selected', ([string]$cnt + ' new selected'))
    }
}

function Open-SLTAppOfficialLink([string]$url, [string]$name) {
    if ($url -notmatch '^https://') { Log-SLT ('SKIP URL (invalid HTTPS): ' + $name); return }
    try { Open-SLTLink $url; Log-SLT ('Opened official verified page: ' + $name) } catch { Log-SLT ('Cannot open ' + $name + ': ' + $_.Exception.Message) }
}

function Invoke-SLTBulkUninstallSelected {
    try {
        if (Get-Command Sync-SLTPackageWorkerScript -ErrorAction SilentlyContinue) { Sync-SLTPackageWorkerScript }
        $chosenRowIds = @(Get-SLTCheckedUninstallRowIds)
        if ($chosenRowIds.Count -eq 0) {
            [Windows.MessageBox]::Show('Please check one or more installed applications below first, then click Bulk Uninstall Selected Apps.', 'Smart Uninstall Mode', 'OK', 'Information') | Out-Null
            return
        }
        $pkgsToUninstall = New-Object System.Collections.Generic.List[object]
        foreach ($cid in $chosenRowIds) {
            $rowObj = $null
            if ($script:UninstallRowLookup.ContainsKey([string]$cid)) {
                $rowObj = $script:UninstallRowLookup[[string]$cid]
            } else {
                foreach ($ri in @($script:RealScanAllApps)) {
                    if ($null -ne $ri -and [string]$ri.RowId -eq [string]$cid) {
                        $rowObj = $ri
                        break
                    }
                }
            }
            if ($null -ne $rowObj) {
                $pkgsToUninstall.Add((Convert-SLTScanRowToPackage $rowObj))
            }
        }
        if ($pkgsToUninstall.Count -eq 0) {
            [Windows.MessageBox]::Show('Please check one or more installed applications below first, then click Bulk Uninstall Selected Apps.', 'Smart Uninstall Mode', 'OK', 'Information') | Out-Null
            return
        }
        $didStart = BulkUninstallForce -Packages @($pkgsToUninstall.ToArray())
        if ($didStart) {
            $script:UninstallSelectedMap.Clear()
            $script:SuppressSelectAllEvent = $true
            try { if ($null -ne $script:UninstallSelectAllCb) { $script:UninstallSelectAllCb.IsChecked = $false } } finally { $script:SuppressSelectAllEvent = $false }
            Render-SLTUninstallModeView
            Update-SLTUninstallCounter
        }
    } catch {
        Log-SLT ("Invoke-SLTBulkUninstallSelected error: " + $_.Exception.Message)
    }
}
Set-Item -Path Function:\global:Invoke-SLTBulkUninstallSelected -Value ${function:Invoke-SLTBulkUninstallSelected}

function Invoke-SLTAppSelection([ValidateSet('Install','Uninstall')][string]$Verb) {
    if ($Verb -eq 'Uninstall') {
        Invoke-SLTBulkUninstallSelected
        return
    }
    Install-NewAppsOnly
}
Set-Item -Path Function:\global:Invoke-SLTAppSelection -Value ${function:Invoke-SLTAppSelection}

function Show-SLTInstallCategory([string]$Category) {
    $mapped = switch ($Category) {
        'SLT PC TOOLS' { 'SLT Essential Package' }
        'SLT QC TOOLS' { 'PC health' }
        default { $Category }
    }
    Switch-SLTPage 1
    Switch-SLTInstallTabMode 'Install'
    $script:SuppressCategoryEvent = $true
    try {
        $script:CategoryCombo.SelectedItem = $mapped
        $script:SearchBox.Text = ''
    } finally {
        $script:SuppressCategoryEvent = $false
    }
    Render-SLTAppCatalog
}

$script:CategoryCombo.Add_SelectionChanged({
    try {
        if ($script:SuppressCategoryEvent) { return }
        $script:InstallSearchHighlighted = $false
        $script:SuppressSelectAllEvent = $true
        try { if ($null -ne $script:InstallSelectAllCb) { $script:InstallSelectAllCb.IsChecked = $false } } finally { $script:SuppressSelectAllEvent = $false }
        Render-SLTAppCatalog
    } catch {}
})
$script:SearchBox.Add_GotFocus({
    try {
        if ($null -ne $script:SearchPlaceholder) { $script:SearchPlaceholder.Visibility = 'Collapsed' }
        $script:SearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
    } catch {}
})
$script:SearchBox.Add_LostFocus({
    try {
        if ($null -ne $script:SearchPlaceholder -and [string]::IsNullOrEmpty($script:SearchBox.Text)) {
            $script:SearchPlaceholder.Visibility = 'Visible'
        }
        $script:SearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'InputBorder')
    } catch {}
})
$script:SearchBox.Add_TextChanged({
    try {
        if ($script:SuppressCategoryEvent) { return }
        if ($null -ne $script:SearchPlaceholder) {
            $script:SearchPlaceholder.Visibility = $(if ([string]::IsNullOrEmpty($script:SearchBox.Text) -and (-not $script:SearchBox.IsKeyboardFocused)) { 'Visible' } else { 'Collapsed' })
        }
        Invoke-SLTAppSearch -FromButton $false
    } catch {}
})
$script:SearchBox.Add_KeyDown({
    param($s, $e)
    try {
        if ($e.Key -eq 'Return' -or $e.Key -eq 'Enter') {
            $e.Handled = $true
            Invoke-SLTAppSearch -FromButton $true
        } elseif ($e.Key -eq 'Escape') {
            $e.Handled = $true
            $script:InstallSearchHighlighted = $false
            $script:SuppressCategoryEvent = $true
            try {
                $script:SearchBox.Text = ''
                $script:CategoryCombo.SelectedIndex = 0
            } finally {
                $script:SuppressCategoryEvent = $false
            }
            Render-SLTAppCatalog
        }
    } catch {}
})

# Initial startup scan cache or quick registry scan + Default Mode = Install
if ((-not (Import-SLTStartupScanCache)) -or $null -eq $script:RealScanAllApps -or @($script:RealScanAllApps).Count -eq 0) {
    Get-RealInstalledApps -QuickRegistryOnly:$false
}
Update-SLTModeSwitchVisuals
Render-SLTAppCatalog
Update-SLTInstallCounter
Update-SLTStatusLine
$script:CatalogInitialized = $true

Set-Item -Path Function:\global:Update-SLTStatusLine -Value ${function:Update-SLTStatusLine}
Set-Item -Path Function:\global:Update-SLTModeSwitchVisuals -Value ${function:Update-SLTModeSwitchVisuals}
Set-Item -Path Function:\global:Format-SLTSizeText -Value ${function:Format-SLTSizeText}
Set-Item -Path Function:\global:Get-SLTFilteredApps -Value ${function:Get-SLTFilteredApps}
Set-Item -Path Function:\global:Invoke-SLTAppSearch -Value ${function:Invoke-SLTAppSearch}
Set-Item -Path Function:\global:Open-SLTAppOfficialLink -Value ${function:Open-SLTAppOfficialLink}
Set-Item -Path Function:\global:Show-SLTInstallCategory -Value ${function:Show-SLTInstallCategory}
Set-Item -Path Function:\global:Render-SLTAppCatalog -Value ${function:Render-SLTAppCatalog}
Set-Item -Path Function:\global:Update-SLTInstallCounter -Value ${function:Update-SLTInstallCounter}
Set-Item -Path Function:\global:Update-SLTInstallButtonText -Value ${function:Update-SLTInstallButtonText}
Set-Item -Path Function:\global:Convert-SLTScanRowToPackage -Value ${function:Convert-SLTScanRowToPackage}

# Self-contained Real + Persistent Status Banner override
function Show-WOWNotification([string]$Mode, [int]$OkCount, [int]$SkipCount, [int]$FailCount, [int]$SavedMin=1) {
    # REAL + PERSISTENT RESULT BANNER INSIDE STATUS WINDOW:
    # - Uses real counts ($OkCount, $FailCount, $SkipCount, $TotalCount)
    # - Stays visible persistently inside the Status Window (NEVER auto-hides after 1-2s!)
    # - Plays sound & blinks 3 times ONLY when $OkCount -gt 0, then stays solid (Opacity = 1.0)
    # - When $OkCount -eq 0 and $FailCount -gt 0, shows "0 Apps Installed - All Failed - Please Try Again" (NO Congratulations!)
    # - Keeps full log visible in FeedBox below
    if ($null -eq $script:MonitorState -or $null -eq $script:MonitorState.NotifCard) { return }
    $chkIcon   = [char]0x2705
    $crossIcon = [char]0x274C
    $skipIcon  = [char]0x23ED
    $sparkle   = [char]0x2728
    $conv      = [Windows.Media.BrushConverter]::new()

    $win         = $script:MonitorState.Win
    $hdrTitle    = $script:MonitorState.HdrTitle
    $notifCard   = $script:MonitorState.NotifCard
    $succMainTxt = $script:MonitorState.SuccMainTxt
    $succSubTxt  = $script:MonitorState.SuccSubTxt
    $blinkTimer  = $script:MonitorState.BlinkTimer
    $autoTimer   = $script:MonitorState.AutoHideTimer
    $hideBtn     = $script:MonitorState.HideBtn

    $totalCnt = $OkCount + $FailCount + $SkipCount

    $applyAction = {
        try {
            # Stop any auto-hide timer so notification stays persistent until user clicks Close
            if ($null -ne $autoTimer) { $autoTimer.Stop() }
            if ($null -ne $blinkTimer) { $blinkTimer.Stop() }
            if ($null -ne $hideBtn) { $hideBtn.Content = 'Close' }

            $brandFooter = 'Thanks for Smart Life Teck | Shahzad Babar | www.smartlifeteck.com'

            if ($Mode -eq 'Uninstall') {
                try {
                    if ($null -ne $script:MonitorState -and $null -ne $script:MonitorState.ProgressFile -and (Test-Path -LiteralPath $script:MonitorState.ProgressFile)) {
                        $progObj = Get-Content -LiteralPath $script:MonitorState.ProgressFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                        if ($null -ne $progObj -and $null -ne $progObj.results) {
                            $verifiedRemoved = New-Object System.Collections.Generic.List[object]
                            foreach ($resItem in @($progObj.results)) {
                                if ($null -ne $resItem -and ([string]$resItem.status) -eq 'Uninstalled Successfully') {
                                    $verifiedRemoved.Add(@{ key = [string]$resItem.key; name = [string]$resItem.name })
                                }
                            }
                            if ($verifiedRemoved.Count -gt 0) {
                                Remove-SLTUninstalledFromMemory -Packages @($verifiedRemoved.ToArray())
                            }
                        }
                    }
                } catch {}
                if ($OkCount -gt 0) {
                    $headline = if ($FailCount -eq 0) {
                        "$sparkle WOW! $OkCount Apps Successfully Uninstalled - Thanks for Smart Life Teck | Shahzad Babar www.smartlifeteck.com"
                    } else {
                        "$chkIcon $OkCount Apps Successfully Uninstalled | $crossIcon $FailCount Failed"
                    }
                    $detailLines = New-Object System.Collections.Generic.List[string]
                    $detailLines.Add("$chkIcon $OkCount Apps Successfully Uninstalled")
                    if ($FailCount -gt 0) { $detailLines.Add("$crossIcon $FailCount Apps Failed - Still Installed - Try Again") }
                    if ($SkipCount -gt 0) { $detailLines.Add("$skipIcon $SkipCount Not Installed - Skipped") }
                    $detailLines.Add("Total: $totalCnt   |   $brandFooter")

                    $win.Title = "Software Uninstallation Completed ($OkCount Uninstalled)"
                    $hdrTitle.Text = 'Software Uninstallation Successfully Completed'
                    $notifCard.Background = $conv.ConvertFromString('#064E3B')
                    $notifCard.BorderBrush = $conv.ConvertFromString('#10B981')
                    $succMainTxt.Foreground = $conv.ConvertFromString('#ECFDF5')
                    $succSubTxt.Foreground  = $conv.ConvertFromString('#A7F3D0')
                    $succMainTxt.Text = $headline
                    $succSubTxt.Text  = ($detailLines -join "`r`n")
                    $notifCard.Opacity = 1.0
                    $notifCard.Visibility = 'Visible'

                    if (-not $script:MonitorState.SoundPlayed) {
                        $script:MonitorState.SoundPlayed = $true
                        Play-SLTUninstallTone
                    }
                    # Blink 3 times (6 half-cycles) then stay solid
                    $script:MonitorState['BlinkTicks'] = 0
                    if ($null -ne $blinkTimer) { $blinkTimer.Start() }
                } else {
                    $headline = "$crossIcon 0 Apps Uninstalled - All Failed - Please Try Again"
                    $detailLines = New-Object System.Collections.Generic.List[string]
                    $detailLines.Add("$crossIcon $FailCount Apps Failed - Still Installed - Try Again")
                    if ($SkipCount -gt 0) { $detailLines.Add("$skipIcon $SkipCount Not Installed - Skipped") }
                    $detailLines.Add("Total: $totalCnt   |   $brandFooter")

                    $win.Title = '0 Apps Uninstalled - All Failed - Please Try Again'
                    $hdrTitle.Text = '0 Apps Uninstalled - All Failed - Please Try Again'
                    $notifCard.Background = $conv.ConvertFromString('#450A0A')
                    $notifCard.BorderBrush = $conv.ConvertFromString('#EF4444')
                    $succMainTxt.Foreground = $conv.ConvertFromString('#FEE2E2')
                    $succSubTxt.Foreground  = $conv.ConvertFromString('#FECACA')
                    $succMainTxt.Text = $headline
                    $succSubTxt.Text  = ($detailLines -join "`r`n")
                    $notifCard.Opacity = 1.0
                    $notifCard.Visibility = 'Visible'
                }
            } else {
                # Install Mode: Immediately mark verified installed/already-installed apps in memory and refresh catalog
                try {
                    if ($null -ne $script:MonitorState -and $null -ne $script:MonitorState.ProgressFile -and (Test-Path -LiteralPath $script:MonitorState.ProgressFile)) {
                        $progObj = Get-Content -LiteralPath $script:MonitorState.ProgressFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                        if ($null -ne $progObj -and $null -ne $progObj.results) {
                            $verifiedAdded = New-Object System.Collections.Generic.List[object]
                            foreach ($resItem in @($progObj.results)) {
                                if ($null -ne $resItem -and ([string]$resItem.status) -in @('Installed Successfully','Already Installed')) {
                                    $verifiedAdded.Add(@{ key = [string]$resItem.key; name = [string]$resItem.name })
                                }
                            }
                            if ($verifiedAdded.Count -gt 0 -and (Get-Command Add-SLTInstalledToMemory -ErrorAction SilentlyContinue)) {
                                Add-SLTInstalledToMemory -Packages @($verifiedAdded.ToArray())
                            }
                        }
                    }
                } catch {}
                if ($OkCount -gt 0) {
                    $headline = if ($FailCount -eq 0 -and $SkipCount -eq 0) {
                        "$sparkle WOW! All $OkCount Apps Successfully Installed - Thanks for Smart Life Teck | Shahzad Babar www.smartlifeteck.com"
                    } elseif ($FailCount -eq 0) {
                        "$sparkle WOW! $OkCount Apps Successfully Installed ($SkipCount Already Installed - Skipped)"
                    } else {
                        "$chkIcon $OkCount Apps Successfully Installed   |   $crossIcon $FailCount Apps Failed"
                    }
                    $detailLines = New-Object System.Collections.Generic.List[string]
                    $detailLines.Add("$chkIcon $OkCount Apps Successfully Installed")
                    if ($FailCount -gt 0) {
                        $detailLines.Add("$crossIcon $FailCount Apps Failed - Server Busy - Try Again Later")
                    }
                    if ($SkipCount -gt 0) {
                        $detailLines.Add("$skipIcon $SkipCount Already Installed - Skipped")
                    }
                    $detailLines.Add("Total: $totalCnt   |   $brandFooter")

                    $win.Title = "Software Installation Successfully ($OkCount Installed)"
                    $hdrTitle.Text = 'Software Installation Successfully'
                    $notifCard.Background = $conv.ConvertFromString('#064E3B')
                    $notifCard.BorderBrush = $conv.ConvertFromString('#10B981')
                    $succMainTxt.Foreground = $conv.ConvertFromString('#ECFDF5')
                    $succSubTxt.Foreground  = $conv.ConvertFromString('#A7F3D0')
                    $succMainTxt.Text = $headline
                    $succSubTxt.Text  = ($detailLines -join "`r`n")
                    $notifCard.Opacity = 1.0
                    $notifCard.Visibility = 'Visible'

                    if (-not $script:MonitorState.SoundPlayed) {
                        $script:MonitorState.SoundPlayed = $true
                        Play-SLTSuccessChime
                    }
                    # Blink 3 times then stay solid
                    $script:MonitorState['BlinkTicks'] = 0
                    if ($null -ne $blinkTimer) { $blinkTimer.Start() }
                } elseif ($OkCount -eq 0 -and $SkipCount -gt 0 -and $FailCount -eq 0) {
                    $headline = "$skipIcon $SkipCount Already Installed - Skipped (No Download Needed)"
                    $detailLines = New-Object System.Collections.Generic.List[string]
                    $detailLines.Add("$skipIcon $SkipCount Already Installed - Package already exists on this PC")
                    $detailLines.Add("Total: $totalCnt   |   $brandFooter")

                    $win.Title = 'Already Installed - Skipped'
                    $hdrTitle.Text = 'Already Installed - Skipped'
                    $notifCard.Background = $conv.ConvertFromString('#0C4A6E')
                    $notifCard.BorderBrush = $conv.ConvertFromString('#38BDF8')
                    $succMainTxt.Foreground = $conv.ConvertFromString('#E0F2FE')
                    $succSubTxt.Foreground  = $conv.ConvertFromString('#7DD3FC')
                    $succMainTxt.Text = $headline
                    $succSubTxt.Text  = ($detailLines -join "`r`n")
                    $notifCard.Opacity = 1.0
                    $notifCard.Visibility = 'Visible'
                } else {
                    # 0 Installed and FailCount > 0 -> NEVER show Congratulations!
                    $headline = "$crossIcon 0 Apps Installed - All Failed - Please Try Again"
                    $detailLines = New-Object System.Collections.Generic.List[string]
                    $detailLines.Add("$crossIcon $FailCount Apps Failed - Server Busy - Try Again Later")
                    if ($SkipCount -gt 0) {
                        $detailLines.Add("$skipIcon $SkipCount Already Installed - Skipped")
                    }
                    $detailLines.Add("Total: $totalCnt   |   $brandFooter")

                    $win.Title = '0 Apps Installed - All Failed - Please Try Again'
                    $hdrTitle.Text = '0 Apps Installed - All Failed - Please Try Again'
                    $notifCard.Background = $conv.ConvertFromString('#450A0A')
                    $notifCard.BorderBrush = $conv.ConvertFromString('#EF4444')
                    $succMainTxt.Foreground = $conv.ConvertFromString('#FEE2E2')
                    $succSubTxt.Foreground  = $conv.ConvertFromString('#FECACA')
                    $succMainTxt.Text = $headline
                    $succSubTxt.Text  = ($detailLines -join "`r`n")
                    $notifCard.Opacity = 1.0
                    $notifCard.Visibility = 'Visible'
                }
            }
        } catch {}
    }

    try {
        if ($null -ne $win -and $null -ne $win.Dispatcher) {
            $win.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Normal, [action]$applyAction)
        } else {
            & $applyAction
        }
    } catch {
        try { & $applyAction } catch {}
    }
}
Set-Item -Path Function:\global:Show-WOWNotification -Value ${function:Show-WOWNotification}

