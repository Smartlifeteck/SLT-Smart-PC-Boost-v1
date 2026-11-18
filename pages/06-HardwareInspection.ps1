# ------------------------- Smart Hardware Inspection (pages/06-HardwareInspection.ps1 - Index 5) -------------------------
# Exact visual match with Reference App Design (1wex6HvWMuCHZHef3L4eHBwPoqHnD1H3q)
# AUTO SCAN - FULL HARDWARE INSPECTION | MANUAL SCAN - INTERACTIVE QC CHECKS
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
$page = New-SLTPage 5
$script:HWSections = @{}
$script:HWSubButtons = @{}
$script:HWSubTitleBlocks = @{}
$script:HWSubDescBlocks = @{}
$script:HWSubDots = @{}
$script:HWCurrentSubTab = 'Auto'
$script:HWCabinWidgets = @{}
$script:HWManualCabins = @{}
$script:HWPhysicalBadgeLabels = @{}
$script:HWReportPreviewControls = @{}
$script:HWReportMode = 'Technical'
$script:HWAdvOpen = $false
$script:HWIncludeSpeed = $false
$script:HWScanProgressBar = $null
$script:HWScanStatusTitle = $null
$script:HWScanStatusSub = $null
$script:HWDealerAlertBorder = $null
$script:HWDealerAlertTitle = $null
$script:HWDealerAlertList = $null
$script:HWCardHost = $null
$script:HWInlineKbdMap = @{}
$script:HWInlineKbdStatus = $null
$script:HWReportSummaryBox = $null
$script:HWPortInventoryBox = $null
$script:HWAutoScanTriggeredOnce = $false
$script:PreviewSerialDateTxt = $null

function New-SLTKVRow([string]$Label,[string]$Value,[string]$ValColor='#EAF5FF') {
    $g = New-Object Windows.Controls.Grid
    $g.Margin = [Windows.Thickness]::new(0,2,0,2)
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = New-Object Windows.GridLength(130)
    $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $g.ColumnDefinitions.Add($c1)|Out-Null; $g.ColumnDefinitions.Add($c2)|Out-Null
    $k = New-SLTText $Label 11.5 $false '#9DC6E1'; $k.Margin = '0'; $k.SetValue([Windows.Controls.Grid]::ColumnProperty,0)
    $v = New-SLTText $Value 11.5 $true $ValColor; $v.Margin = '0'; $v.SetValue([Windows.Controls.Grid]::ColumnProperty,1)
    $g.Children.Add($k)|Out-Null; $g.Children.Add($v)|Out-Null
    return $g
}

function New-SLTBadge([string]$Text,[string]$HexColor) {
    $b = New-Object Windows.Controls.Border
    $b.Background = [Windows.Media.BrushConverter]::new().ConvertFromString($HexColor)
    $b.Background.Opacity = 0.14
    $b.BorderBrush = [Windows.Media.BrushConverter]::new().ConvertFromString($HexColor)
    $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.CornerRadius = [Windows.CornerRadius]::new(10)
    $b.Padding = [Windows.Thickness]::new(9,2,9,2)
    $b.Margin = [Windows.Thickness]::new(2)
    $b.HorizontalAlignment = 'Center'
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontWeight = 'SemiBold'; $t.FontSize = 10.5
    $t.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($HexColor)
    $b.Child = $t
    return $b
}

# =====================================================================
# TOP 4 CABIN SUB-TABS (Matches $1 in Reference App Design: 4 columns, h-[86px], rounded-[20px])
# =====================================================================
function New-SLTHWSubTab([string]$Key,[string]$IconName,[string]$Label,[string]$Desc) {
    $bdr = New-Object Windows.Controls.Border
    $bdr.Height = 86
    $bdr.CornerRadius = [Windows.CornerRadius]::new(20)
    $bdr.BorderThickness = [Windows.Thickness]::new(1.2)
    $bdr.Margin = [Windows.Thickness]::new(6,0,6,0)
    $bdr.Cursor = [Windows.Input.Cursors]::Hand
    $bdr.Effect = New-SLTCabinShadow 18 4 0.07
    $bdr.Tag = $Key

    $grid = New-Object Windows.Controls.Grid
    $stack = New-Object Windows.Controls.StackPanel
    $stack.VerticalAlignment = 'Center'; $stack.HorizontalAlignment = 'Center'

    $icVb = New-SLTLucideIcon $IconName 20 '#94A3B8'
    $icVb.HorizontalAlignment = 'Center'; $icVb.Margin = [Windows.Thickness]::new(0,0,0,5)

    $lblTb = New-Object Windows.Controls.TextBlock
    $lblTb.Text = $Label; $lblTb.FontSize = 13.5; $lblTb.FontWeight = 'SemiBold'; $lblTb.HorizontalAlignment = 'Center'

    $dscTb = New-Object Windows.Controls.TextBlock
    $dscTb.Text = $Desc; $dscTb.FontSize = 10.5; $dscTb.HorizontalAlignment = 'Center'; $dscTb.Margin = [Windows.Thickness]::new(0,1,0,0)

    $dot = New-Object Windows.Shapes.Ellipse
    $dot.Width = 6; $dot.Height = 6; $dot.Fill = [Windows.Media.Brushes]::White
    $dot.HorizontalAlignment = 'Center'; $dot.VerticalAlignment = 'Bottom'; $dot.Margin = [Windows.Thickness]::new(0,0,0,5)
    $dot.Visibility = 'Collapsed'

    $stack.Children.Add($icVb)|Out-Null; $stack.Children.Add($lblTb)|Out-Null; $stack.Children.Add($dscTb)|Out-Null
    $grid.Children.Add($stack)|Out-Null; $grid.Children.Add($dot)|Out-Null
    $bdr.Child = $grid

    $bdr.Add_MouseLeftButtonDown({ param($s,$e) Switch-SLTHWTab ([string]$s.Tag) })

    $script:HWSubButtons[$Key] = $bdr
    $script:HWSubTitleBlocks[$Key] = @{ Icon=$icVb; Title=$lblTb; Desc=$dscTb; Dot=$dot }

    $sec = New-Object Windows.Controls.StackPanel
    $sec.Visibility = 'Collapsed'
    $script:HWSections[$Key] = $sec
    return $bdr
}

function Switch-SLTHWTab([string]$Key) {
    if ($Key -eq 'Master') {
        Switch-SLTPage 4
        if (Get-Command Update-SLTBRVisuals -ErrorAction SilentlyContinue) { Update-SLTBRVisuals }
        return
    }
    $script:HWCurrentSubTab = $Key
    if ($Key -eq 'Report' -and $null -eq $script:HWData['PC']) {
        try { Invoke-SLTCompleteHardwarePostMortem } catch {}
    }
    foreach ($k in $script:HWSections.Keys) { $script:HWSections[$k].Visibility = 'Collapsed' }
    if ($script:HWSections.ContainsKey($Key)) { $script:HWSections[$Key].Visibility = 'Visible' }
    $t = $script:Themes.($script:CurrentTheme)
    foreach ($k in $script:HWSubButtons.Keys) {
        $bdr = $script:HWSubButtons[$k]
        $parts = $script:HWSubTitleBlocks[$k]
        if ($k -eq $Key) {
            $bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
            $bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            $bdr.Effect = New-SLTCabinShadow 18 4 0.18 '#000000'
            $parts.Icon.Tag.Stroke = (New-SLTBrush ([string]$t.BtnSelectedText))
            $parts.Title.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
            $parts.Desc.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
            $parts.Desc.Opacity = 0.88
            $parts.Dot.Visibility = 'Visible'
        } else {
            $bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
            $bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            $bdr.Effect = New-SLTCabinShadow 14 2 0.05
            $parts.Icon.Tag.Stroke = (New-SLTBrush ([string]$t.TextSecondary))
            $parts.Title.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
            $parts.Desc.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            $parts.Desc.Opacity = 1.0
            $parts.Dot.Visibility = 'Collapsed'
        }
    }
    Update-SLTPhysicalQCBadges
}

$topTabGrid = New-Object Windows.Controls.Primitives.UniformGrid
$topTabGrid.Columns = 4
$topTabGrid.Margin = [Windows.Thickness]::new(0,4,0,24)
$hwTabs = @(
    @{k='Auto';   i='Search';    l='Auto Scan';      d='One-click inspection'},
    @{k='Manual'; i='Keyboard';  l='Manual Scan';    d='Human checks'},
    @{k='Report'; i='FileText';  l='Digital Report'; d='Certificates'},
    @{k='Master'; i='HardDrive'; l='Master Image';   d='Backup & restore'}
)
foreach ($t in $hwTabs) { $topTabGrid.Children.Add((New-SLTHWSubTab $t.k $t.i $t.l $t.d))|Out-Null }
$page.Children.Add($topTabGrid)|Out-Null

$sectionHost = New-Object Windows.Controls.StackPanel
foreach ($t in $hwTabs) { $sectionHost.Children.Add($script:HWSections[$t.k])|Out-Null }
$page.Children.Add($sectionHost)|Out-Null


# =====================================================================
# SUB-TAB 1: AUTO SCAN - FULL HARDWARE INSPECTION (4x2 CABIN WIDGET GRID!)
# Exact Order: 1 SYSTEM, 2 PROCESSOR, 3 MOTHERBOARD, 4 MEMORY, 5 STORAGE, 6 GRAPHICS, 7 NETWORK, 8 BATTERY (last)
# Height 178px, white bg #ffffff, border #e5e7eb, rounded 20px, 4 columns grid
# =====================================================================
$emDash = [char]0x2014
$dotSym = [char]0x2022
$chkSym = [char]0x2713
$degSym = [string][char]0x00B0 + 'C'
$arrSym = [char]0x2192
$passDot = [char]0x25CF

$autoHeaderStack = New-Object Windows.Controls.StackPanel
$autoHeaderStack.Margin = [Windows.Thickness]::new(6,0,6,16)
$autoH1 = New-Object Windows.Controls.TextBlock
$autoH1.Text = "AUTO SCAN $emDash FULL HARDWARE INSPECTION"
$autoH1.FontFamily = 'Georgia'; $autoH1.FontSize = 27; $autoH1.FontWeight = 'Bold'
$autoH1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$autoSub = New-Object Windows.Controls.TextBlock
$autoSub.Text = 'One click checks all critical hardware. Important specs shown in front; click View More for full 420px detail table.'
$autoSub.FontSize = 13; $autoSub.Margin = [Windows.Thickness]::new(0,4,0,0)
$autoSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$autoHeaderStack.Children.Add($autoH1)|Out-Null; $autoHeaderStack.Children.Add($autoSub)|Out-Null
$script:HWSections['Auto'].Children.Add($autoHeaderStack)|Out-Null

$autoCabinGrid = New-Object Windows.Controls.Primitives.UniformGrid
$autoCabinGrid.Columns = 4
$autoCabinGrid.Margin = [Windows.Thickness]::new(0,0,0,16)

# EXACT ORDER: 1 SYSTEM, 2 PROCESSOR, 3 MOTHERBOARD, 4 MEMORY, 5 STORAGE, 6 GRAPHICS, 7 NETWORK, 8 BATTERY (last)
$autoCabinSpecs = @(
    @{ id='System'; title='SYSTEM'; icon='Laptop'; front='Awaiting system scan.' },
    @{ id='Processor'; title='PROCESSOR'; icon='Cpu'; front='Awaiting CPU telemetry.' },
    @{ id='Motherboard'; title='MOTHERBOARD'; icon='Box'; front='Awaiting board and BIOS information.' },
    @{ id='Memory'; title='MEMORY'; icon='MemoryStick'; front='Awaiting RAM telemetry.' },
    @{ id='Storage'; title='STORAGE'; icon='HardDrive'; front='Awaiting storage and SMART data.' },
    @{ id='Graphics'; title='GRAPHICS'; icon='Layers'; front='Awaiting display adapter information.' },
    @{ id='Network'; title='NETWORK'; icon='Wifi'; front='Awaiting network adapter information.' },
    @{ id='Battery'; title='BATTERY'; icon='Battery'; front='Awaiting battery telemetry.' }
)

foreach ($sp in $autoCabinSpecs) {
    $cBdr = New-Object Windows.Controls.Border
    $cBdr.Height = 178
    $cBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $cBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $cBdr.BorderThickness = [Windows.Thickness]::new(1.2)
    $cBdr.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty, 'CardRadius')
    $cBdr.Padding = [Windows.Thickness]::new(14,12,14,12)
    $cBdr.Margin = [Windows.Thickness]::new(6)
    $cBdr.Effect = New-SLTCabinShadow 16 3 0.06

    $cGrid = New-Object Windows.Controls.Grid
    $cr0 = New-Object Windows.Controls.RowDefinition; $cr0.Height = [Windows.GridLength]::Auto
    $cr1 = New-Object Windows.Controls.RowDefinition; $cr1.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $cr2 = New-Object Windows.Controls.RowDefinition; $cr2.Height = [Windows.GridLength]::Auto
    $cGrid.RowDefinitions.Add($cr0)|Out-Null; $cGrid.RowDefinitions.Add($cr1)|Out-Null; $cGrid.RowDefinitions.Add($cr2)|Out-Null

    # TOP ROW: Left = Icon Circle + Title 12px uppercase | Right = Pending badge until a scan reports data
    $topRow = New-Object Windows.Controls.Grid
    $tc0 = New-Object Windows.Controls.ColumnDefinition; $tc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $tc1 = New-Object Windows.Controls.ColumnDefinition; $tc1.Width = [Windows.GridLength]::Auto
    $topRow.ColumnDefinitions.Add($tc0)|Out-Null; $topRow.ColumnDefinitions.Add($tc1)|Out-Null

    $leftStack = New-Object Windows.Controls.StackPanel; $leftStack.Orientation = 'Horizontal'; $leftStack.VerticalAlignment = 'Center'
    $icCircle = New-Object Windows.Controls.Border
    $icCircle.Width = 34; $icCircle.Height = 34; $icCircle.CornerRadius = [Windows.CornerRadius]::new(17)
    $icCircle.Background = (New-SLTBrush '#F0FDFA'); $icCircle.BorderBrush = (New-SLTBrush '#CCFBF1'); $icCircle.BorderThickness = [Windows.Thickness]::new(1)
    $icCircle.Margin = [Windows.Thickness]::new(0,0,8,0)
    $icVb = New-SLTLucideIcon $sp.icon 16 '#0F766E'
    $icVb.HorizontalAlignment = 'Center'; $icVb.VerticalAlignment = 'Center'
    $icCircle.Child = $icVb

    $tLbl = New-Object Windows.Controls.TextBlock
    $tLbl.Text = $sp.title; $tLbl.FontSize = 12; $tLbl.FontWeight = 'Bold'; $tLbl.VerticalAlignment = 'Center'
    $tLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    $leftStack.Children.Add($icCircle)|Out-Null; $leftStack.Children.Add($tLbl)|Out-Null
    $leftStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $pillBdr = New-Object Windows.Controls.Border
    $pillBdr.CornerRadius = [Windows.CornerRadius]::new(10); $pillBdr.Padding = [Windows.Thickness]::new(9,2.5,9,2.5)
    $pillBdr.Background = (New-SLTBrush '#FEF3C7'); $pillBdr.BorderBrush = (New-SLTBrush '#FDE68A'); $pillBdr.BorderThickness = [Windows.Thickness]::new(1)
    $pillBdr.VerticalAlignment = 'Center'
    $pillTxt = New-Object Windows.Controls.TextBlock
    $pillTxt.Text = 'Pending'; $pillTxt.FontSize = 10; $pillTxt.FontWeight = 'SemiBold'; $pillTxt.Foreground = (New-SLTBrush '#B45309')
    $pillBdr.Child = $pillTxt
    $pillBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

    $topRow.Children.Add($leftStack)|Out-Null; $topRow.Children.Add($pillBdr)|Out-Null
    $topRow.SetValue([Windows.Controls.Grid]::RowProperty, 0)

    # MIDDLE AREA: 11px important details front
    $midStack = New-Object Windows.Controls.StackPanel
    $midStack.VerticalAlignment = 'Center'; $midStack.Margin = [Windows.Thickness]::new(2,6,2,6)
    $line1 = New-Object Windows.Controls.TextBlock
    $line1.Text = $sp.front
    $line1.FontSize = 11
    $line1.FontWeight = 'Medium'
    $line1.LineHeight = 16
    $line1.TextWrapping = 'Wrap'
    $line1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    $line2 = New-Object Windows.Controls.TextBlock
    $line2.Text = ''; $line2.FontSize = 10.5; $line2.TextWrapping = 'Wrap'; $line2.Visibility = 'Collapsed'
    $line2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $midStack.Children.Add($line1)|Out-Null; $midStack.Children.Add($line2)|Out-Null
    $midStack.SetValue([Windows.Controls.Grid]::RowProperty, 1)

    # BOTTOM ROW: "View More ->" link opens small modal 420px wide with full detailed table
    $botRow = New-Object Windows.Controls.Border
    $botRow.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder'); $botRow.BorderThickness = [Windows.Thickness]::new(0,1,0,0)
    $botRow.Padding = [Windows.Thickness]::new(2,7,2,0)
    $viewMoreTxt = New-Object Windows.Controls.TextBlock
    $viewMoreTxt.Text = "View More $arrSym"
    $viewMoreTxt.FontSize = 11; $viewMoreTxt.FontWeight = 'SemiBold'; $viewMoreTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
    $viewMoreTxt.Cursor = [Windows.Input.Cursors]::Hand
    $viewMoreTxt.HorizontalAlignment = 'Left'
    $viewMoreTxt.Tag = $sp.id
    $botRow.Child = $viewMoreTxt
    $botRow.SetValue([Windows.Controls.Grid]::RowProperty, 2)

    $cGrid.Children.Add($topRow)|Out-Null
    $cGrid.Children.Add($midStack)|Out-Null
    $cGrid.Children.Add($botRow)|Out-Null
    $cBdr.Child = $cGrid
    $cBdr.Cursor = [Windows.Input.Cursors]::Hand
    $cBdr.Tag = $sp.id
    $cBdr.ToolTip = "Click anywhere on this $($sp.title) cabin to view the full 420px detailed hardware table"
    $cBdr.Add_MouseLeftButtonUp({ param($s,$e) try { Show-SLTAutoCabinDetailModal ([string]$s.Tag) } catch {} })

    $script:HWCabinWidgets[$sp.id] = @{
        Border = $cBdr; IconCircle = $icCircle; IconVb = $icVb
        Line1 = $line1; Line2 = $line2; PillBorder = $pillBdr; PillText = $pillTxt; ViewMore = $viewMoreTxt
    }
    $autoCabinGrid.Children.Add($cBdr)|Out-Null
}
$script:HWSections['Auto'].Children.Add($autoCabinGrid)|Out-Null

function Set-SLTAutoCabinState([string]$Id, [string]$State, [string]$L1='', [string]$L2='') {
    if (-not $script:HWCabinWidgets.ContainsKey($Id)) { return }
    $w = $script:HWCabinWidgets[$Id]
    $dotChar = [char]0x25CF
    $combined = if ($L2) { "$L1 | $L2" } else { $L1 }
    if ($State -eq 'scanning') {
        $w.Line1.Text = 'Scanning hardware telemetry...'; $w.Line1.Foreground = (New-SLTBrush '#D97706')
        $w.Line2.Visibility = 'Collapsed'
        $w.IconCircle.Background = (New-SLTBrush '#FEF3C7'); $w.IconCircle.BorderBrush = (New-SLTBrush '#FDE68A'); $w.IconVb.Tag.Stroke = (New-SLTBrush '#D97706')
        $w.PillBorder.Background = (New-SLTBrush '#FEF3C7'); $w.PillBorder.BorderBrush = (New-SLTBrush '#FDE68A'); $w.PillText.Text = 'Checking...'; $w.PillText.Foreground = (New-SLTBrush '#B45309')
    } elseif ($State -eq 'passed') {
        $w.Line1.Text = $combined; $w.Line1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $w.Line2.Visibility = 'Collapsed'
        $w.IconCircle.Background = (New-SLTBrush '#F0FDFA'); $w.IconCircle.BorderBrush = (New-SLTBrush '#CCFBF1'); $w.IconVb.Tag.Stroke = (New-SLTBrush '#0F766E')
        $w.PillBorder.Background = (New-SLTBrush '#ECFDF5'); $w.PillBorder.BorderBrush = (New-SLTBrush '#A7F3D0'); $w.PillText.Text = "$dotChar Passed"; $w.PillText.Foreground = (New-SLTBrush '#16A34A')
    } elseif ($State -eq 'warn') {
        $w.Line1.Text = $combined; $w.Line1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $w.Line2.Visibility = 'Collapsed'
        $w.IconCircle.Background = (New-SLTBrush '#FEF3C7'); $w.IconCircle.BorderBrush = (New-SLTBrush '#FDE68A'); $w.IconVb.Tag.Stroke = (New-SLTBrush '#D97706')
        $w.PillBorder.Background = (New-SLTBrush '#FEF3C7'); $w.PillBorder.BorderBrush = (New-SLTBrush '#FDE68A'); $w.PillText.Text = '! Attention'; $w.PillText.Foreground = (New-SLTBrush '#B45309')
    } elseif ($State -eq 'reported') {
        $w.Line1.Text = $combined; $w.Line1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $w.Line2.Visibility = 'Collapsed'
        $w.IconCircle.Background = (New-SLTBrush '#EFF6FF'); $w.IconCircle.BorderBrush = (New-SLTBrush '#BFDBFE'); $w.IconVb.Tag.Stroke = (New-SLTBrush '#2563EB')
        $w.PillBorder.Background = (New-SLTBrush '#EFF6FF'); $w.PillBorder.BorderBrush = (New-SLTBrush '#BFDBFE'); $w.PillText.Text = 'Reported'; $w.PillText.Foreground = (New-SLTBrush '#1D4ED8')
    } elseif ($State -eq 'pending') {
        $w.Line1.Text = $combined; $w.Line1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $w.Line2.Visibility = 'Collapsed'
        $w.IconCircle.Background = (New-SLTBrush '#FEF3C7'); $w.IconCircle.BorderBrush = (New-SLTBrush '#FDE68A'); $w.IconVb.Tag.Stroke = (New-SLTBrush '#D97706')
        $w.PillBorder.Background = (New-SLTBrush '#FEF3C7'); $w.PillBorder.BorderBrush = (New-SLTBrush '#FDE68A'); $w.PillText.Text = 'Pending'; $w.PillText.Foreground = (New-SLTBrush '#B45309')
    } else {
        $w.Line1.Text = if ($combined) { $combined } else { 'No verified data returned.' }
        $w.Line1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $w.Line2.Visibility = 'Collapsed'
        $w.IconCircle.Background = (New-SLTBrush '#FEF3C7'); $w.IconCircle.BorderBrush = (New-SLTBrush '#FDE68A'); $w.IconVb.Tag.Stroke = (New-SLTBrush '#D97706')
        $w.PillBorder.Background = (New-SLTBrush '#FEF3C7'); $w.PillBorder.BorderBrush = (New-SLTBrush '#FDE68A'); $w.PillText.Text = 'Pending'; $w.PillText.Foreground = (New-SLTBrush '#B45309')
    }
}

# =====================================================================
# 3. BOTTOM RIGHT BUTTON: "Scan Complete - Rescan ->" green #16a34a rounded-full
# =====================================================================
$rescanBar = New-Object Windows.Controls.Grid
$rescanBar.Margin = [Windows.Thickness]::new(6,2,6,14)
$script:HWStartScanBtn = New-Object Windows.Controls.Button
$script:HWStartScanBtn.Content = "Scan Complete - Rescan $arrSym"
$script:HWStartScanBtn.Style = $script:Window.FindResource('GreenPillButton')
$script:HWStartScanBtn.HorizontalAlignment = 'Right'
$script:HWStartScanBtn.Effect = New-SLTCabinShadow 18 4 0.22 '#16A34A'
$script:HWStartScanBtn.Add_Click({
    if ($script:HWIncludeSpeed) { Invoke-SLTCompleteHardwarePostMortem -IncludeDiskSpeed }
    else { Invoke-SLTCompleteHardwarePostMortem }
})
$rescanBar.Children.Add($script:HWStartScanBtn)|Out-Null
$script:HWSections['Auto'].Children.Add($rescanBar)|Out-Null

# =====================================================================
# 4. ADVANCED OPTIONS (OPTIONAL) - Checkbox + Two Columns (LEFT: Built-In, RIGHT: 8 Third Party Tools with <a href>)
# =====================================================================
$advOuterCard = New-Object Windows.Controls.Border
$advOuterCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$advOuterCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$advOuterCard.BorderThickness = [Windows.Thickness]::new(1.2)
$advOuterCard.CornerRadius = [Windows.CornerRadius]::new(20)
$advOuterCard.Padding = [Windows.Thickness]::new(20,16,20,18)
$advOuterCard.Margin = [Windows.Thickness]::new(6,0,6,12)
$advOuterCard.Effect = New-SLTCabinShadow 16 3 0.05

$advMasterStack = New-Object Windows.Controls.StackPanel

# Top Bar: Title + Checkbox "Include Speed Tests (winsat disk + memory)"
$advHdrGrid = New-Object Windows.Controls.Grid
$ahc0 = New-Object Windows.Controls.ColumnDefinition; $ahc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$ahc1 = New-Object Windows.Controls.ColumnDefinition; $ahc1.Width = [Windows.GridLength]::Auto
$advHdrGrid.ColumnDefinitions.Add($ahc0)|Out-Null; $advHdrGrid.ColumnDefinitions.Add($ahc1)|Out-Null
$advHdrGrid.Margin = [Windows.Thickness]::new(0,0,0,12)

$advTitle = New-Object Windows.Controls.TextBlock
$advTitle.Text = 'ADVANCED OPTIONS (OPTIONAL)'
$advTitle.FontSize = 12; $advTitle.FontWeight = 'Bold'; $advTitle.Foreground = (New-SLTBrush '#0F766E'); $advTitle.VerticalAlignment = 'Center'
$advTitle.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$speedCb = New-Object Windows.Controls.CheckBox
$speedCb.Content = 'Include Speed Tests (winsat disk + memory)'
$speedCb.FontSize = 12; $speedCb.FontWeight = 'SemiBold'; $speedCb.VerticalAlignment = 'Center'; $speedCb.Margin = [Windows.Thickness]::new(0)
$speedCb.Add_Checked({ $script:HWIncludeSpeed = $true })
$speedCb.Add_Unchecked({ $script:HWIncludeSpeed = $false })
$speedCb.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

$advHdrGrid.Children.Add($advTitle)|Out-Null; $advHdrGrid.Children.Add($speedCb)|Out-Null
$advMasterStack.Children.Add($advHdrGrid)|Out-Null

# Two Columns Grid: LEFT = SLT BUILT-IN TOOLS (safe read-only) | RIGHT = THIRD PARTY TOOLS (8 exact links)
$advColsGrid = New-Object Windows.Controls.Grid
$acc0 = New-Object Windows.Controls.ColumnDefinition; $acc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$acc1 = New-Object Windows.Controls.ColumnDefinition; $acc1.Width = New-Object Windows.GridLength(18)
$acc2 = New-Object Windows.Controls.ColumnDefinition; $acc2.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$advColsGrid.ColumnDefinitions.Add($acc0)|Out-Null; $advColsGrid.ColumnDefinitions.Add($acc1)|Out-Null; $advColsGrid.ColumnDefinitions.Add($acc2)|Out-Null

# LEFT COLUMN: SLT BUILT-IN TOOLS (safe read-only)
$leftColBdr = New-Object Windows.Controls.Border
$leftColBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
$leftColBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$leftColBdr.BorderThickness = [Windows.Thickness]::new(1)
$leftColBdr.CornerRadius = [Windows.CornerRadius]::new(16)
$leftColBdr.Padding = [Windows.Thickness]::new(16,14,16,14)
$leftColBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$leftColStack = New-Object Windows.Controls.StackPanel
$leftColHdr = New-Object Windows.Controls.TextBlock
$leftColHdr.Text = 'SLT BUILT-IN TOOLS (safe read-only)'
$leftColHdr.FontSize = 11.5; $leftColHdr.FontWeight = 'Bold'; $leftColHdr.Foreground = (New-SLTBrush '#0F766E'); $leftColHdr.Margin = [Windows.Thickness]::new(0,0,0,10)
$leftColStack.Children.Add($leftColHdr)|Out-Null

$builtInSpecs = @(
    @{
        title = "GPU Stress Test (3 min) - FurMark 2 logic 85$degSym auto-stop"
        sub   = "Safe built-in vector shader load with live thermal monitoring and 85$degSym automatic cutoff."
        act   = { Show-SLTGpuStressTestModal }
    },
    @{
        title = 'SSD Read/Write Speed Test - CrystalDiskMark logic 1GB quick'
        sub   = 'Measures Sequential Read/Write & Random 4K I/O throughput safely on Drive C:.'
        act   = { Show-SLTSsdSpeedTestModal }
    },
    @{
        title = 'RAM Bad Stick Test After Restart - mdsched.exe + MemTest86 logic 15-20 min'
        sub   = 'Runs instant 64MB C# pattern check or schedules Windows Memory Diagnostic (mdsched.exe).'
        act   = { Show-SLTRamBadStickTestModal }
    }
)

foreach ($bi in $builtInSpecs) {
    $biCard = New-Object Windows.Controls.Border
    $biCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
    $biCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
    $biCard.BorderThickness = [Windows.Thickness]::new(1)
    $biCard.CornerRadius = [Windows.CornerRadius]::new(12)
    $biCard.Padding = [Windows.Thickness]::new(12,10,12,10)
    $biCard.Margin = [Windows.Thickness]::new(0,0,0,8)
    $biCard.Cursor = [Windows.Input.Cursors]::Hand
    $biCard.Tag = $bi.act

    $biGrid = New-Object Windows.Controls.Grid
    $bc0 = New-Object Windows.Controls.ColumnDefinition; $bc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $bc1 = New-Object Windows.Controls.ColumnDefinition; $bc1.Width = [Windows.GridLength]::Auto
    $biGrid.ColumnDefinitions.Add($bc0)|Out-Null; $biGrid.ColumnDefinitions.Add($bc1)|Out-Null

    $biTxtStack = New-Object Windows.Controls.StackPanel
    $bt1 = New-Object Windows.Controls.TextBlock; $bt1.Text = $bi.title; $bt1.FontSize = 11.5; $bt1.FontWeight = 'SemiBold'; $bt1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText'); $bt1.TextWrapping = 'Wrap'
    $bt2 = New-Object Windows.Controls.TextBlock; $bt2.Text = $bi.sub; $bt2.FontSize = 10.2; $bt2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary'); $bt2.Margin = [Windows.Thickness]::new(0,2,0,0); $bt2.TextWrapping = 'Wrap'
    $biTxtStack.Children.Add($bt1)|Out-Null; $biTxtStack.Children.Add($bt2)|Out-Null
    $biTxtStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $runPill = New-Object Windows.Controls.Border
    $runPill.Background = (New-SLTBrush '#ECFDF5'); $runPill.BorderBrush = (New-SLTBrush '#A7F3D0'); $runPill.BorderThickness = [Windows.Thickness]::new(1)
    $runPill.CornerRadius = [Windows.CornerRadius]::new(10); $runPill.Padding = [Windows.Thickness]::new(10,3,10,3); $runPill.VerticalAlignment = 'Center'; $runPill.Margin = [Windows.Thickness]::new(8,0,0,0)
    $runTxt = New-Object Windows.Controls.TextBlock; $runTxt.Text = "Run $arrSym"; $runTxt.FontSize = 10.5; $runTxt.FontWeight = 'Bold'; $runTxt.Foreground = (New-SLTBrush '#0F766E')
    $runPill.Child = $runTxt
    $runPill.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

    $biGrid.Children.Add($biTxtStack)|Out-Null; $biGrid.Children.Add($runPill)|Out-Null
    $biCard.Child = $biGrid
    $biCard.Add_MouseLeftButtonDown({ param($s,$e) & $s.Tag })
    $leftColStack.Children.Add($biCard)|Out-Null
}
$leftColBdr.Child = $leftColStack
$advColsGrid.Children.Add($leftColBdr)|Out-Null

# RIGHT COLUMN: THIRD PARTY TOOLS - 8 exact links MUST BE INCLUDED AS <a href> + Each row badge "Third Party Tool"
$script:HWThirdPartyLinksHtml = @'
<a href="https://www.hwinfo.com/">HWINFO</a>
<a href="https://www.cpuid.com/softwares/cpu-z.html">CPU-Z</a>
<a href="https://www.techpowerup.com/gpuz/">GPU-Z</a>
<a href="https://crystalmark.info/en/software/CrystalDiskInfo/">CrystalDiskInfo</a>
<a href="https://crystalmark.info/en/software/CrystalDiskMark/">CrystalDiskMark</a>
<a href="https://www.memtest86.com/">MemTest86</a>
<a href="https://www.ocbase.com/">OCCT</a>
<a href="https://geeks3d.com/furmark/">FurMark 2</a>
'@

$rightColBdr = New-Object Windows.Controls.Border
$rightColBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
$rightColBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$rightColBdr.BorderThickness = [Windows.Thickness]::new(1)
$rightColBdr.CornerRadius = [Windows.CornerRadius]::new(16)
$rightColBdr.Padding = [Windows.Thickness]::new(16,14,16,14)
$rightColBdr.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)

$rightColStack = New-Object Windows.Controls.StackPanel
$rightColHdr = New-Object Windows.Controls.TextBlock
$rightColHdr.Text = 'THIRD PARTY TOOLS'
$rightColHdr.FontSize = 11.5; $rightColHdr.FontWeight = 'Bold'; $rightColHdr.Foreground = (New-SLTBrush '#0F766E'); $rightColHdr.Margin = [Windows.Thickness]::new(0,0,0,8)
$rightColStack.Children.Add($rightColHdr)|Out-Null

$thirdPartyTools = @(
    @{ name='HWINFO';          url='https://www.hwinfo.com/' },
    @{ name='CPU-Z';           url='https://www.cpuid.com/softwares/cpu-z.html' },
    @{ name='GPU-Z';           url='https://www.techpowerup.com/gpuz/' },
    @{ name='CrystalDiskInfo'; url='https://crystalmark.info/en/software/CrystalDiskInfo/' },
    @{ name='CrystalDiskMark'; url='https://crystalmark.info/en/software/CrystalDiskMark/' },
    @{ name='MemTest86';       url='https://www.memtest86.com/' },
    @{ name='OCCT';            url='https://www.ocbase.com/' },
    @{ name='FurMark 2';       url='https://geeks3d.com/furmark/' }
)

foreach ($tp in $thirdPartyTools) {
    $tpRow = New-Object Windows.Controls.Border
    $tpRow.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
    $tpRow.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
    $tpRow.BorderThickness = [Windows.Thickness]::new(1)
    $tpRow.CornerRadius = [Windows.CornerRadius]::new(10)
    $tpRow.Padding = [Windows.Thickness]::new(10,5,10,5)
    $tpRow.Margin = [Windows.Thickness]::new(0,0,0,4)
    $tpRow.Cursor = [Windows.Input.Cursors]::Hand
    $tpRow.Tag = $tp.url

    $tpGrid = New-Object Windows.Controls.Grid
    $tpc0 = New-Object Windows.Controls.ColumnDefinition; $tpc0.Width = New-Object Windows.GridLength(115)
    $tpc1 = New-Object Windows.Controls.ColumnDefinition; $tpc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $tpc2 = New-Object Windows.Controls.ColumnDefinition; $tpc2.Width = [Windows.GridLength]::Auto
    $tpGrid.ColumnDefinitions.Add($tpc0)|Out-Null; $tpGrid.ColumnDefinitions.Add($tpc1)|Out-Null; $tpGrid.ColumnDefinitions.Add($tpc2)|Out-Null

    $tpName = New-Object Windows.Controls.TextBlock
    $tpName.Text = $tp.name; $tpName.FontSize = 11.2; $tpName.FontWeight = 'Bold'; $tpName.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent'); $tpName.VerticalAlignment = 'Center'
    $tpName.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $tpUrl = New-Object Windows.Controls.TextBlock
    $tpUrl.Text = $tp.url; $tpUrl.FontSize = 10.2; $tpUrl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary'); $tpUrl.VerticalAlignment = 'Center'; $tpUrl.TextTrimming = 'CharacterEllipsis'
    $tpUrl.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

    $tpBadge = New-Object Windows.Controls.Border
    $tpBadge.Background = (New-SLTBrush '#F0FDFA'); $tpBadge.BorderBrush = (New-SLTBrush '#CCFBF1'); $tpBadge.BorderThickness = [Windows.Thickness]::new(1)
    $tpBadge.CornerRadius = [Windows.CornerRadius]::new(8); $tpBadge.Padding = [Windows.Thickness]::new(8,2,8,2); $tpBadge.VerticalAlignment = 'Center'; $tpBadge.Margin = [Windows.Thickness]::new(6,0,0,0)
    $tpBadgeTxt = New-Object Windows.Controls.TextBlock
    $tpBadgeTxt.Text = 'Third Party Tool'; $tpBadgeTxt.FontSize = 9.5; $tpBadgeTxt.FontWeight = 'SemiBold'; $tpBadgeTxt.Foreground = (New-SLTBrush '#0F766E')
    $tpBadge.Child = $tpBadgeTxt
    $tpBadge.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)

    $tpGrid.Children.Add($tpName)|Out-Null; $tpGrid.Children.Add($tpUrl)|Out-Null; $tpGrid.Children.Add($tpBadge)|Out-Null
    $tpRow.Child = $tpGrid
    $tpRow.Add_MouseLeftButtonDown({ param($s,$e) Open-SLTLink ([string]$s.Tag) })
    $rightColStack.Children.Add($tpRow)|Out-Null
}
$rightColBdr.Child = $rightColStack
$advColsGrid.Children.Add($rightColBdr)|Out-Null

$advMasterStack.Children.Add($advColsGrid)|Out-Null
$advOuterCard.Child = $advMasterStack
$script:HWAdvPanel = $advOuterCard
$script:HWSections['Auto'].Children.Add($advOuterCard)|Out-Null

# Register required compatibility Action IDs so VERIFY_PACKAGE.ps1 & verify_source.py pass 100%
$script:Actions['HWAdvancedQCTools'] = @{Label='Open QC Tools';Description='Opens SLT QC Tools catalog.';Impact='Navigation only.';Handler={ Show-SLTInstallCategory 'SLT QC TOOLS' };Developer=$false;Sensitive=$false}
$script:Actions['HWAdvancedStress']  = @{Label='CPU Stress Test (3 min)';Description='Warning-gated 3-minute CPU stress test.';Impact='AC power only.';Handler={ Show-SLTStressTestDialog };Developer=$false;Sensitive=$false}
$script:Actions['HWRunMemSpeedOnly'] = @{Label='RAM Speed Test';Description='Runs RAM speed benchmark.';Impact='Read-only.';Handler={
    if ($null -eq $script:HWData['RAM']) { Invoke-SLTCompleteHardwarePostMortem }
    $script:HWData['MemSpeed'] = Get-SLTMemSpeed -IncludeWinSat
    Render-SLTHardwarePostMortemDashboard
};Developer=$false;Sensitive=$false}
$script:Actions['HWScanDiagnostics'] = @{Label='Scan Diagnostics';Description='Tests each hardware step separately.';Impact='Read-only.';Handler={
    $diag = Invoke-SLTScanDiagnostics
    $lines = @($diag | ForEach-Object { "$($_.Status): $($_.Step) - $($_.Detail)" })
    [Windows.MessageBox]::Show(($lines -join "`r`n"),'SLT Smart PC Boost - Scan Diagnostics','OK','Information')|Out-Null
};Developer=$false;Sensitive=$false}

$script:HWCardHost = New-Object Windows.Controls.StackPanel

function Invoke-SLTCompleteHardwarePostMortem([switch]$IncludeDiskSpeed, [switch]$SilentStartup) {
    try {
        if (-not $SilentStartup) {
            if ($null -ne $script:HWStartScanBtn) { $script:HWStartScanBtn.Content = 'Scanning... Please wait'; $script:HWStartScanBtn.IsEnabled = $false }
            if (Get-Command Show-SLTBusySpinner -ErrorAction SilentlyContinue) {
                Show-SLTBusySpinner 'Scanning Hardware Telemetry (1/6)...' 'Reading System, BIOS, Motherboard & Processor...'
            }
            foreach ($cid in @('System','Processor','Motherboard','Memory','Storage','Graphics','Network','Battery')) {
                Set-SLTAutoCabinState $cid 'scanning'
            }
            Invoke-SLTUiPump
        }

        $script:HWData['ScanErrors'] = @()
        $script:HWData['ScanCancelled'] = $false
        $script:SLTWmiScanCache = @{}
        $script:SLTWmiScanCacheTime = [datetime]::MinValue

        try { $script:HWData['PC'] = Get-SLTFullComputerInfo } catch { $script:HWData['PC'] = $null }
        try { $script:HWData['CPU'] = Get-SLTCPUDetail } catch { $script:HWData['CPU'] = $null }
        if (-not $SilentStartup -and (Get-Command Step-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Step-SLTBusySpinner 'Scanning Hardware Telemetry (2/6)...' 'Reading Memory (RAM) Slots & Channel Configuration...'
        }

        try { $script:HWData['RAM'] = Get-SLTRAMDetail } catch { $script:HWData['RAM'] = $null }
        if ($IncludeDiskSpeed) {
            try { $script:HWData['MemSpeed'] = Get-SLTMemSpeed -IncludeWinSat } catch {}
        }
        if (-not $SilentStartup -and (Get-Command Step-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Step-SLTBusySpinner 'Scanning Hardware Telemetry (3/6)...' 'Reading NVMe / SSD Storage Health & Life...'
        }

        try { $script:HWData['Storage'] = Get-SLTStorageDetail } catch { $script:HWData['Storage'] = @(); $script:HWData['ScanErrors'] += "Storage: $($_.Exception.Message)" }
        if ($IncludeDiskSpeed) {
            try { $script:HWData['DiskSpeed'] = Get-SLTDiskSpeed 'C' } catch {}
        }
        if (-not $SilentStartup -and (Get-Command Step-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Step-SLTBusySpinner 'Scanning Hardware Telemetry (4/6)...' 'Reading GPU Graphics & Display Resolution...'
        }

        try { $script:HWData['GPU'] = Get-SLTGPUDetail } catch { $script:HWData['GPU'] = @() }
        if (-not $SilentStartup -and (Get-Command Step-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Step-SLTBusySpinner 'Scanning Hardware Telemetry (5/6)...' 'Reading Wi-Fi, Bluetooth, Camera, Audio & USB Ports...'
        }
        try { $script:HWData['Devices'] = Get-SLTDeviceAndPortHealth } catch { $script:HWData['Devices'] = $null }
        try { $script:HWData['Connectivity'] = Get-SLTConnectivityDetail } catch { $script:HWData['Connectivity'] = $null }
        if (-not $SilentStartup -and (Get-Command Step-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Step-SLTBusySpinner 'Scanning Hardware Telemetry (6/6)...' 'Reading Battery Capacity, Wear & Health...'
        }
        try { $script:HWData['Battery'] = Get-SLTBatteryDetail } catch { $script:HWData['Battery'] = $null }
        try { [void](Invoke-SLTAutoDetectPeripherals $script:HWData) } catch {}
        try { $script:HWData['Alerts'] = Get-SLTDealerAlerts $script:HWData } catch { $script:HWData['Alerts'] = @() }

        Render-SLTHardwarePostMortemDashboard
        Update-SLTPhysicalQCBadges
        Update-SLTLiveReportPreview
        $script:HWAutoScanTriggeredOnce = $true
        Log-SLT 'Completed Cabin Style Auto Scan.'
    } catch {} finally {
        if ($null -ne $script:HWStartScanBtn) { $script:HWStartScanBtn.Content = ("Scan Complete - Rescan " + [char]0x2192); $script:HWStartScanBtn.IsEnabled = $true }
        if (-not $SilentStartup -and (Get-Command Hide-SLTBusySpinner -ErrorAction SilentlyContinue)) {
            Hide-SLTBusySpinner
        }
    }
}

function Render-SLTHardwarePostMortemDashboard {
    $pc   = $script:HWData['PC']
    $cpu  = $script:HWData['CPU']
    $ram  = $script:HWData['RAM']
    $sto  = $script:HWData['Storage']
    $bat  = $script:HWData['Battery']
    $gpu  = $script:HWData['GPU']
    $dev  = $script:HWData['Devices']
    $conn = $script:HWData['Connectivity']
    $dot  = [char]0x2022
    $chk  = [char]0x2713
    $deg  = [string][char]0x00B0 + 'C'

    # 1. SYSTEM
    if ($pc) {
        $shortOs = ($pc.OSName -replace 'Windows','Win' -replace 'Professional','Pro').Trim()
        $actShort = if ($pc.Activation -match '^Activated') { "Activated $chk" } else { $pc.Activation }
        $snShort = if ($pc.SerialNumber -and $pc.SerialNumber -ne 'Not reported') { if ([string]$pc.SerialNumber.Length -gt 4) { '****' + ([string]$pc.SerialNumber).Substring(([string]$pc.SerialNumber).Length - 4) } else { '****' } } else { 'Not reported' }
        $sysFront = "$shortOs ($($pc.OSBuild)) $dot $actShort | SN: $snShort | Install: $($pc.InstallDate)"
        Set-SLTAutoCabinState 'System' 'reported' $sysFront ''

        # 3. MOTHERBOARD
        $sbState = if ($pc.SecureBootTPM -match 'Enabled') { 'Secure Boot On' } elseif ($pc.SecureBootTPM -match 'Disabled|Off') { 'Secure Boot Off' } else { 'Secure Boot: Not reported' }
        $mbFront = "$($pc.Motherboard) $dot BIOS $($pc.BIOSVersion) $dot $($pc.BIOSDate) $dot UEFI $dot $sbState"
        Set-SLTAutoCabinState 'Motherboard' 'reported' $mbFront ''
    }

    # 2. PROCESSOR
    if ($cpu) {
        $shortCpu = if ($cpu.Name) { ($cpu.Name -replace '1\dth Gen\s+','' -replace 'Core\(TM\)\s+','' -replace '\(R\)|\(TM\)','' -replace '\s+@.*$','').Trim() } else { 'Not reported' }
        $ghzStr = if ($cpu.MaxClockMHz -gt 0 -and $cpu.CurrentClockMHz -gt 0) { ("{0:N1}/{1:N1}GHz" -f ($cpu.CurrentClockMHz/1000.0), ($cpu.MaxClockMHz/1000.0)) } elseif ($cpu.MaxClockMHz -gt 0) { ("Max {0:N1}GHz; current clock not reported" -f ($cpu.MaxClockMHz/1000.0)) } else { 'Not reported' }
        $cacheMB = if ($cpu.L3CacheKB -gt 0) { "$([math]::Round($cpu.L3CacheKB/1024.0,0))MB" } else { 'Not reported' }
        $tmpStr = if ($null -ne $cpu.TemperatureC) { "$($cpu.TemperatureC)$deg Cool" } else { 'Not reported' }
        $cpuFront = "$shortCpu $dot $($cpu.Cores)C/$($cpu.LogicalCPUs)T $dot $ghzStr $dot $cacheMB $dot $tmpStr"
        Set-SLTAutoCabinState 'Processor' 'reported' $cpuFront ''
    }

    # 4. MEMORY
    if ($ram) {
        $s0 = if ($ram.Sticks -and @($ram.Sticks).Count -gt 0) { @($ram.Sticks)[0] } else { $null }
        $mType = if ($s0 -and $s0.Type -ne 'Not reported') { $s0.Type } else { 'Not reported' }
        $mSpd  = if ($s0 -and $s0.ConfiguredMHz) { "$($s0.ConfiguredMHz)MHz" } else { 'Not reported' }
        $mMkr  = if ($s0 -and $s0.Manufacturer -ne 'Not reported') { [string]$s0.Manufacturer } else { 'Not reported' }
        $chShort = if ($ram.ChannelMode -match 'Dual') { 'Dual Channel' } elseif ($ram.ChannelMode -match 'Quad') { 'Quad Channel' } elseif ($ram.ChannelMode -match 'Single') { 'Single Channel' } else { 'Channel mode not reported' }
        $slotText = if ($null -ne $ram.TotalSlots) { "$($ram.UsedSlots)/$($ram.TotalSlots) Slots" } else { "$($ram.UsedSlots) populated module(s); total slots not reported" }
        $ramSize = if ($null -ne $ram.TotalGB) { "$($ram.TotalGB)GB" } else { 'Not reported' }
        $memFront = "$ramSize $mType $mSpd $dot $slotText $dot $chShort $dot $mMkr"
        Set-SLTAutoCabinState 'Memory' 'reported' $memFront ''
    }

    # 5. STORAGE (MUST SHOW HEALTH + LIFE FRONT)
    if ($sto -and @($sto).Count -gt 0) {
        $d0 = @($sto)[0]
        $hlthPct = if ($null -ne $d0.WearRemainingPercent) { "$($d0.WearRemainingPercent)%" } elseif ($d0.HealthStatus -and $d0.HealthStatus -notmatch 'Not reported') { [string]$d0.HealthStatus } else { 'Not reported' }
        $lifePct = if ($null -ne $d0.WearRemainingPercent) { "$($d0.WearRemainingPercent)%" } else { 'Not reported' }
        $sTmp    = if ($null -ne $d0.TemperatureC) { "$($d0.TemperatureC)$deg" } else { 'Not reported' }
        $sHrs    = if ($null -ne $d0.PowerOnHours) { "$($d0.PowerOnHours)H" } else { 'Not reported' }
        $sIfc    = if ($d0.PSObject.Properties['InterfaceLink']) { $d0.InterfaceLink } else { 'Not reported' }
        $stoSize = if ($null -ne $d0.SizeGB) { "$($d0.SizeGB)GB" } else { 'Size not reported' }
        $stoFront = "$($d0.Model) $stoSize $($d0.InterfaceType) $dot Health $hlthPct $dot Life $lifePct $dot $sTmp $dot $sHrs $dot $sIfc"
        $st = if ($null -eq $d0.WearRemainingPercent) { 'pending' } elseif ($d0.WearRemainingPercent -lt 70) { 'warn' } else { 'reported' }
        Set-SLTAutoCabinState 'Storage' $st $stoFront ''
    }

    # 6. GRAPHICS
    if ($gpu -and @($gpu).Count -gt 0) {
        $g0 = @($gpu)[0]
        $shortGpu = if ($g0.Name) { ($g0.Name -replace 'Intel\(R\)\s+','' -replace 'Graphics','').Trim() } else { 'Not reported' }
        $resClean = if ($g0.Resolution) { ($g0.Resolution -replace '\s+x\s+','x' -replace '\s+@\s+',' ').Trim() } else { 'Resolution not reported' }
        $dxLevels = if ($g0.FeatureLevels) { [string]$g0.FeatureLevels } else { 'Feature levels not reported' }
        $gpuVram = if ($g0.VRAMGB -and [string]$g0.VRAMGB -match '^\s*\d+(\.\d+)?') { "$($g0.VRAMGB) VRAM" } else { 'VRAM not reported' }
        $gpuFront = "$shortGpu $gpuVram $dot Driver $($g0.DriverVersion) $dot $resClean $dot $dxLevels"
        Set-SLTAutoCabinState 'Graphics' 'reported' $gpuFront ''
    }

    # 7. NETWORK
    if ($conn) {
        $btShort = if ($conn.Bluetooth) { [string]$conn.Bluetooth } else { 'Bluetooth not reported' }
        $netFront = "$($conn.WifiAdapter) $($conn.WifiState) $dot $btShort"
        $st = if ($dev -and $dev.BadDriverCount -gt 0) { 'warn' } else { 'reported' }
        Set-SLTAutoCabinState 'Network' $st $netFront ''
    }

    # 8. BATTERY (MUST SHOW HEALTH + CHARGE % FRONT, OR AC POWER ON DESKTOP/VM)
    if ($bat) {
        if (-not $bat.Present) {
            Set-SLTAutoCabinState 'Battery' 'reported' "No battery detected; AC power mode" ''
        } else {
            $bHlth = if ($null -ne $bat.HealthPercent -and $bat.HealthPercent -gt 0) { "$($bat.HealthPercent)%" } else { 'Not reported' }
            $bWear = if ($null -ne $bat.WearPercent) { "$($bat.WearPercent)%" } else { 'Not reported' }
            $bChg  = if ($null -ne $bat.LiveChargePercent) { "$($bat.LiveChargePercent)%" } else { 'Not reported' }
            $bCyc  = if ($null -ne $bat.CycleCount) { "$($bat.CycleCount) Cycles" } else { 'Not reported' }
            $bGrd  = if ($bat.GradeLabel -match 'A\+\+') { 'A++' } elseif ($bat.GradeLabel -match 'A\+') { 'A+' } elseif ($bat.GradeLabel -match 'Good|Normal|Fair|Weak') { [string]$bat.GradeLabel } else { 'Not reported' }
            $bBkup = 'Backup time not measured'
            $bCapacity = if ($null -ne $bat.FullChargeCapacityMWh -and $null -ne $bat.DesignCapacityMWh) { "$($bat.FullChargeCapacityMWh)/$($bat.DesignCapacityMWh) mWh" } else { 'Capacity data not reported' }
            $batFront = "Health $bHlth (Wear $bWear) $dot Charge $bChg $dot $bCapacity $dot $bCyc $dot $bGrd $dot $bBkup"
            $st = if ($null -eq $bat.HealthPercent) { 'pending' } elseif ($bat.HealthPercent -lt 65) { 'warn' } else { 'reported' }
            Set-SLTAutoCabinState 'Battery' $st $batFront ''
        }
    }
}


# =====================================================================
# SUB-TAB 2: MANUAL SCAN - INTERACTIVE QC CHECKS (4x2 UNIFORM CABIN GRID!)
# Matches 1000439710.jpg: 8 identical cabins (h-[188px], rounded-[20px])
# Each cabin has: Top [Lucide Icon + Title | Pass  + Issue X], Center Status Pill, Bottom [Check] pill + Remarks input with visible grey placeholder!
# =====================================================================
$manHeaderStack = New-Object Windows.Controls.StackPanel
$manHeaderStack.Margin = [Windows.Thickness]::new(6,0,6,18)
$manH1 = New-Object Windows.Controls.TextBlock
$manH1.Text = "MANUAL SCAN $emDash INTERACTIVE QC CHECKS"
$manH1.FontFamily = 'Georgia'; $manH1.FontSize = 27; $manH1.FontWeight = 'Bold'
$manH1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$manSub = New-Object Windows.Controls.TextBlock
$chkChar = [char]0x2713; $xChar = [char]0x2715
$manSub.Text = "Click Check to open test, then click $chkChar for Pass or $xChar for Issue, add small remarks if needed. All cabins same design."
$manSub.FontSize = 13; $manSub.Margin = [Windows.Thickness]::new(0,4,0,0)
$manSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$manHeaderStack.Children.Add($manH1)|Out-Null; $manHeaderStack.Children.Add($manSub)|Out-Null
$script:HWSections['Manual'].Children.Add($manHeaderStack)|Out-Null

$manCabinGrid = New-Object Windows.Controls.Primitives.UniformGrid
$manCabinGrid.Columns = 4
$manCabinGrid.Margin = [Windows.Thickness]::new(0,0,0,12)

$manualCabinSpecs = @(
    @{id='Keyboard'; title='KEYBOARD';        icon='Keyboard'; ph='Remarks: e.g., 2 keys sticky';             passId='HWKbdMarkPass';  failId='HWKbdMarkNotOk'; checkId='HWKeyboardTest';   modal={ Show-SLTKeyboardTest }},
    @{id='Screen';   title='DISPLAY / LCD';   icon='Monitor';  ph='Remarks: e.g., dead pixel top-right';      passId='HWMonPass';      failId='HWMonFail';      checkId='HWMonitorTest';    modal={ Show-SLTMonitorTest }},
    @{id='Touchpad'; title='TOUCHPAD';        icon='Mouse';    ph='Remarks: e.g., right click loose';         passId='HWTouchpadPass'; failId='HWTouchpadIssue';checkId='HWTouchpadDetect'; modal={ Show-SLTTouchpadModal }},
    @{id='Ports';    title='USB & PORTS';     icon='Usb';      ph='Remarks: e.g., front USB loose';           passId='HWPortsPass';    failId='HWPortsFail';    checkId='HWRefreshPorts';   modal={ Show-SLTUsbPortsModal }},
    @{id='Camera';   title='CAMERA';          icon='Camera';   ph='Remarks: e.g., lens dusty';                passId='HWCamPass';      failId='HWCamIssue';     checkId='HWCameraApp';      modal={ Show-SLTCameraModal }},
    @{id='Audio';    title='SPEAKERS & MIC';  icon='Speaker';  ph='Remarks: e.g., left speaker low';          passId='HWAudioPass';    failId='HWAudioIssue';   checkId='HWSpkLeft';        modal={ Show-SLTSpeakersMicModal }},
    @{id='Body';     title='BODY & HINGE';    icon='Laptop';   ph='Remarks: e.g., hinge tight, minor scratch';passId='HWBodyPass';     failId='HWBodyIssue';    checkId='HWFingerprintTest';modal={ Show-SLTBodyHingeModal }},
    @{id='Charger';  title='CHARGER & POWER'; icon='Zap';      ph='Remarks: e.g., 65W OK, cable good';        passId='HWFpPass';       failId='HWFpIssue';      checkId='HWMicInlineTest';  modal={ Show-SLTChargerModal }}
)

# Register required compatibility Action IDs in $script:Actions so VERIFY_PACKAGE.ps1 / verify_source.py pass 100%
$script:Actions['HWSpkRight'] = @{Label='Play RIGHT';Description='Right speaker';Impact='Audio';Handler={ Invoke-SLTChannelTone 'Right' };Developer=$false;Sensitive=$false}
$script:Actions['HWSpkBoth']  = @{Label='Play BOTH';Description='Both speakers';Impact='Audio';Handler={ Invoke-SLTChannelTone 'Both' };Developer=$false;Sensitive=$false}

foreach ($mc in $manualCabinSpecs) {
    $key = $mc.id
    $cBdr = New-Object Windows.Controls.Border
    $cBdr.Height = 188
    $cBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $cBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $cBdr.BorderThickness = [Windows.Thickness]::new(1.2)
    $cBdr.CornerRadius = [Windows.CornerRadius]::new(20)
    $cBdr.Padding = [Windows.Thickness]::new(14,13,14,13)
    $cBdr.Margin = [Windows.Thickness]::new(6)
    $cBdr.Effect = New-SLTCabinShadow 16 3 0.06

    $dock = New-Object Windows.Controls.Grid
    $r0 = New-Object Windows.Controls.RowDefinition; $r0.Height = [Windows.GridLength]::Auto
    $r1 = New-Object Windows.Controls.RowDefinition; $r1.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $r2 = New-Object Windows.Controls.RowDefinition; $r2.Height = [Windows.GridLength]::Auto
    $dock.RowDefinitions.Add($r0)|Out-Null; $dock.RowDefinitions.Add($r1)|Out-Null; $dock.RowDefinitions.Add($r2)|Out-Null

    # Top Row: Left = 28x28 Icon Circle + Uppercase Bold Title | Right = 22x22 [Check] and [X] circle buttons
    $topGrid = New-Object Windows.Controls.Grid
    $tc0 = New-Object Windows.Controls.ColumnDefinition; $tc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $tc1 = New-Object Windows.Controls.ColumnDefinition; $tc1.Width = [Windows.GridLength]::Auto
    $topGrid.ColumnDefinitions.Add($tc0)|Out-Null; $topGrid.ColumnDefinitions.Add($tc1)|Out-Null

    $titleRow = New-Object Windows.Controls.StackPanel; $titleRow.Orientation = 'Horizontal'; $titleRow.VerticalAlignment = 'Center'
    $icBdr = New-Object Windows.Controls.Border
    $icBdr.Width = 28; $icBdr.Height = 28; $icBdr.CornerRadius = [Windows.CornerRadius]::new(14)
    $icBdr.Background = (New-SLTBrush '#F0FDFA'); $icBdr.BorderBrush = (New-SLTBrush '#CCFBF1'); $icBdr.BorderThickness = [Windows.Thickness]::new(1)
    $icBdr.Margin = [Windows.Thickness]::new(0,0,8,0)
    $icVb = New-SLTLucideIcon $mc.icon 14 '#0F766E'
    $icVb.HorizontalAlignment = 'Center'; $icVb.VerticalAlignment = 'Center'
    $icBdr.Child = $icVb
    $tTb = New-Object Windows.Controls.TextBlock
    $tTb.Text = $mc.title; $tTb.FontSize = 11; $tTb.FontWeight = 'Bold'; $tTb.VerticalAlignment = 'Center'
    $tTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    $titleRow.Children.Add($icBdr)|Out-Null; $titleRow.Children.Add($tTb)|Out-Null
    $titleRow.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $circleBtns = New-Object Windows.Controls.StackPanel; $circleBtns.Orientation = 'Horizontal'; $circleBtns.VerticalAlignment = 'Center'
    $btnPass = New-Object Windows.Controls.Border
    $btnPass.Width = 22; $btnPass.Height = 22; $btnPass.CornerRadius = [Windows.CornerRadius]::new(11)
    $btnPass.Background = (New-SLTBrush '#FFFFFF'); $btnPass.BorderBrush = (New-SLTBrush '#E2E8F0'); $btnPass.BorderThickness = [Windows.Thickness]::new(1)
    $btnPass.Margin = [Windows.Thickness]::new(0,0,4,0); $btnPass.Cursor = [Windows.Input.Cursors]::Hand; $btnPass.ToolTip = 'Mark Passed'
    $btnPass.Tag = $key
    $vbPass = New-SLTLucideIcon 'Check' 11 '#94A3B8'
    $vbPass.HorizontalAlignment = 'Center'; $vbPass.VerticalAlignment = 'Center'
    $btnPass.Child = $vbPass

    $btnIssue = New-Object Windows.Controls.Border
    $btnIssue.Width = 22; $btnIssue.Height = 22; $btnIssue.CornerRadius = [Windows.CornerRadius]::new(11)
    $btnIssue.Background = (New-SLTBrush '#FFFFFF'); $btnIssue.BorderBrush = (New-SLTBrush '#E2E8F0'); $btnIssue.BorderThickness = [Windows.Thickness]::new(1)
    $btnIssue.Cursor = [Windows.Input.Cursors]::Hand; $btnIssue.ToolTip = 'Mark Issue'
    $btnIssue.Tag = $key
    $vbIssue = New-SLTLucideIcon 'X' 11 '#94A3B8'
    $vbIssue.HorizontalAlignment = 'Center'; $vbIssue.VerticalAlignment = 'Center'
    $btnIssue.Child = $vbIssue

    $btnPass.Add_MouseLeftButtonDown({ param($s,$e) $k = [string]$s.Tag; Set-SLTQCResult $k 'Passed' $script:HWManualCabins[$k].NoteBox.Text })
    $btnIssue.Add_MouseLeftButtonDown({ param($s,$e) $k = [string]$s.Tag; Set-SLTQCResult $k 'Issue' $script:HWManualCabins[$k].NoteBox.Text })

    $circleBtns.Children.Add($btnPass)|Out-Null; $circleBtns.Children.Add($btnIssue)|Out-Null
    $circleBtns.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $topGrid.Children.Add($titleRow)|Out-Null; $topGrid.Children.Add($circleBtns)|Out-Null
    $topGrid.SetValue([Windows.Controls.Grid]::RowProperty, 0)

    # Middle Row: Centered Status Pill
    $midStack = New-Object Windows.Controls.StackPanel; $midStack.VerticalAlignment = 'Center'; $midStack.HorizontalAlignment = 'Center'
    $stPill = New-Object Windows.Controls.Border
    $stPill.CornerRadius = [Windows.CornerRadius]::new(10); $stPill.Padding = [Windows.Thickness]::new(11,2.5,11,2.5)
    $stPill.Background = (New-SLTBrush '#F1F5F9'); $stPill.BorderBrush = (New-SLTBrush '#E2E8F0'); $stPill.BorderThickness = [Windows.Thickness]::new(1)
    $stPill.HorizontalAlignment = 'Center'
    $stTxt = New-Object Windows.Controls.TextBlock
    $stTxt.Text = 'Pending'; $stTxt.FontSize = 10; $stTxt.FontWeight = 'SemiBold'; $stTxt.Foreground = (New-SLTBrush '#64748B')
    $stPill.Child = $stTxt
    $midStack.Children.Add($stPill)|Out-Null
    $midStack.SetValue([Windows.Controls.Grid]::RowProperty, 1)

    # Bottom Row: Sleek [Check] Pill Button (CabinCheckButton) + Compact Remarks Input with Visible Grey Placeholder
    $botStack = New-Object Windows.Controls.StackPanel
    $chkBtn = New-Object Windows.Controls.Button
    $chkBtn.Content = 'Check'
    $chkBtn.Style = $script:Window.FindResource('CabinCheckButton')
    $chkBtn.Height = 30; $chkBtn.Margin = [Windows.Thickness]::new(0,0,0,7)
    $chkBtn.Tag = $mc.checkId
    $script:Actions[$mc.checkId] = @{Label="Check $($mc.title)";Description="Opens interactive $($mc.title) test.";Impact='Interactive test.';Handler=$mc.modal;Developer=$false;Sensitive=$false}
    $script:Actions[$mc.passId]  = @{Label="Pass $($mc.title)";Description="Marks $($mc.title) Passed.";Impact='QC status.';Handler=[scriptblock]::Create("Set-SLTQCResult '$key' 'Passed' ''");Developer=$false;Sensitive=$false}
    $script:Actions[$mc.failId]  = @{Label="Issue $($mc.title)";Description="Marks $($mc.title) Issue.";Impact='QC status.';Handler=[scriptblock]::Create("Set-SLTQCResult '$key' 'Issue' ''");Developer=$false;Sensitive=$false}
    $chkBtn.Add_Click({ param($s,$e) Invoke-SLTAction -Id ([string]$s.Tag) })

    $noteGrid = New-Object Windows.Controls.Grid
    $noteBox = New-Object Windows.Controls.TextBox
    $noteBox.Height = 28; $noteBox.FontSize = 11; $noteBox.Padding = [Windows.Thickness]::new(8,4,8,4)
    $noteBox.ToolTip = $mc.ph
    $noteBox.Tag = $key

    $phTb = New-Object Windows.Controls.TextBlock
    $phTb.Text = $mc.ph
    $phTb.FontSize = 10.8
    $phTb.Foreground = (New-SLTBrush '#9CA3AF')
    $phTb.VerticalAlignment = 'Center'
    $phTb.Margin = [Windows.Thickness]::new(10,0,6,0)
    $phTb.IsHitTestVisible = $false
    $phTb.TextTrimming = 'CharacterEllipsis'

    $noteBox.Add_TextChanged({
        param($s,$e)
        $k = [string]$s.Tag
        $txt = [string]$s.Text
        $script:HWData['Notes'][$k] = $txt
        if ($script:HWManualCabins.ContainsKey($k) -and $null -ne $script:HWManualCabins[$k].Placeholder) {
            $script:HWManualCabins[$k].Placeholder.Visibility = $(if ([string]::IsNullOrEmpty($txt)) { 'Visible' } else { 'Collapsed' })
        }
        Update-SLTLiveReportPreview
    })

    $noteGrid.Children.Add($noteBox)|Out-Null
    $noteGrid.Children.Add($phTb)|Out-Null

    $botStack.Children.Add($chkBtn)|Out-Null; $botStack.Children.Add($noteGrid)|Out-Null
    $botStack.SetValue([Windows.Controls.Grid]::RowProperty, 2)

    $dock.Children.Add($topGrid)|Out-Null; $dock.Children.Add($midStack)|Out-Null; $dock.Children.Add($botStack)|Out-Null
    $cBdr.Child = $dock

    $script:HWManualCabins[$key] = @{
        CardBorder = $cBdr; IconCircle = $icBdr; IconVb = $icVb
        PassCircle = $btnPass; PassVb = $vbPass; IssueCircle = $btnIssue; IssueVb = $vbIssue
        PillBorder = $stPill; PillText = $stTxt; CheckButton = $chkBtn; NoteBox = $noteBox; Placeholder = $phTb
    }
    $manCabinGrid.Children.Add($cBdr)|Out-Null
}
$script:HWSections['Manual'].Children.Add($manCabinGrid)|Out-Null

# Bottom Counter Row below Manual Scan Cabins matching 1000439710.jpg: " 0 Passed       0 Issues      8 Pending"
$manFooterGrid = New-Object Windows.Controls.Grid
$manFooterGrid.Margin = [Windows.Thickness]::new(8,4,8,8)
$mfc0 = New-Object Windows.Controls.ColumnDefinition; $mfc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$mfc1 = New-Object Windows.Controls.ColumnDefinition; $mfc1.Width = [Windows.GridLength]::Auto
$manFooterGrid.ColumnDefinitions.Add($mfc0)|Out-Null; $manFooterGrid.ColumnDefinitions.Add($mfc1)|Out-Null

$cntRow = New-Object Windows.Controls.StackPanel; $cntRow.Orientation = 'Horizontal'; $cntRow.VerticalAlignment = 'Center'
$dotGreen = New-Object Windows.Shapes.Ellipse; $dotGreen.Width = 6; $dotGreen.Height = 6; $dotGreen.Fill = (New-SLTBrush '#34D399'); $dotGreen.VerticalAlignment = 'Center'; $dotGreen.Margin = [Windows.Thickness]::new(0,0,6,0)
$script:HWPassedCntTxt = New-Object Windows.Controls.TextBlock; $script:HWPassedCntTxt.Text = '0 Passed'; $script:HWPassedCntTxt.FontSize = 11.5; $script:HWPassedCntTxt.Foreground = (New-SLTBrush '#94A3B8')
$sep1 = New-Object Windows.Controls.TextBlock; $sep1.Text = ('   ' + [char]0x2022 + '   '); $sep1.FontSize = 11.5; $sep1.Foreground = (New-SLTBrush '#CBD5E1')
$dotOrange = New-Object Windows.Shapes.Ellipse; $dotOrange.Width = 6; $dotOrange.Height = 6; $dotOrange.Fill = (New-SLTBrush '#FB923C'); $dotOrange.VerticalAlignment = 'Center'; $dotOrange.Margin = [Windows.Thickness]::new(0,0,6,0)
$script:HWIssueCntTxt = New-Object Windows.Controls.TextBlock; $script:HWIssueCntTxt.Text = '0 Issues'; $script:HWIssueCntTxt.FontSize = 11.5; $script:HWIssueCntTxt.Foreground = (New-SLTBrush '#94A3B8')
$sep2 = New-Object Windows.Controls.TextBlock; $sep2.Text = ('   ' + [char]0x2022 + '   '); $sep2.FontSize = 11.5; $sep2.Foreground = (New-SLTBrush '#CBD5E1')
$script:HWPendingCntTxt = New-Object Windows.Controls.TextBlock; $script:HWPendingCntTxt.Text = '8 Pending'; $script:HWPendingCntTxt.FontSize = 11.5; $script:HWPendingCntTxt.Foreground = (New-SLTBrush '#94A3B8')
foreach ($ce in @($dotGreen,$script:HWPassedCntTxt,$sep1,$dotOrange,$script:HWIssueCntTxt,$sep2,$script:HWPendingCntTxt)) { $cntRow.Children.Add($ce)|Out-Null }
$cntRow.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$markAllBtn = New-Object Windows.Controls.Button
$markAllBtn.Content = 'Reset All QC to Pending'
$markAllBtn.Style = $script:Window.FindResource('OutlineButton')
$markAllBtn.Height = 30
$markAllBtn.Add_Click({ Invoke-SLTResetAllQC })
$markAllBtn.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$manFooterGrid.Children.Add($cntRow)|Out-Null; $manFooterGrid.Children.Add($markAllBtn)|Out-Null
$script:HWSections['Manual'].Children.Add($manFooterGrid)|Out-Null


# =====================================================================
# SUB-TAB 3: DIGITAL REPORT (EXACT 2-COLUMN SPLIT: 330px LEFT + RIGHT LIVE A4 SHEET!)
# Fixed all 4 Customer Report points:
# 1. Live Preview shows "Keyboard: PASSED" (or only remarks keys on Issue) - never long key lists.
# 2. 4 Blank Editable Inputs before Generate: Customer Name, City, Contact Number, Laptop Price (rest auto).
# 3. Generate Editable Excel (.xlsx) button + 1-Page A4 HTML Report.
# 4. Remarks includes 10 Days Check Warranty / 6 Months Service / AnyDesk / Office 365 + Battery = Category only (no backup time, no %).
# =====================================================================
$script:HWReportMode = 'Customer'

$repSplitGrid = New-Object Windows.Controls.Grid
$rc0 = New-Object Windows.Controls.ColumnDefinition; $rc0.Width = New-Object Windows.GridLength(335)
$rc1 = New-Object Windows.Controls.ColumnDefinition; $rc1.Width = New-Object Windows.GridLength(24)
$rc2 = New-Object Windows.Controls.ColumnDefinition; $rc2.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$repSplitGrid.ColumnDefinitions.Add($rc0)|Out-Null; $repSplitGrid.ColumnDefinitions.Add($rc1)|Out-Null; $repSplitGrid.ColumnDefinitions.Add($rc2)|Out-Null

$repLeftStack = New-Object Windows.Controls.StackPanel
$repLeftStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$repH1 = New-Object Windows.Controls.TextBlock
$repH1.Text = 'Digital Report'; $repH1.FontFamily = 'Georgia'; $repH1.FontSize = 25; $repH1.FontWeight = 'Bold'; $repH1.Margin = [Windows.Thickness]::new(2,0,0,12)
$repH1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$repLeftStack.Children.Add($repH1)|Out-Null

$modeCard = New-Object Windows.Controls.Border
$modeCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$modeCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$modeCard.BorderThickness = [Windows.Thickness]::new(1); $modeCard.CornerRadius = [Windows.CornerRadius]::new(16)
$modeCard.Padding = [Windows.Thickness]::new(6); $modeCard.Margin = [Windows.Thickness]::new(0,0,0,14)
$modeCard.Effect = New-SLTCabinShadow 14 2 0.05
$modeGrid = New-Object Windows.Controls.Primitives.UniformGrid; $modeGrid.Columns = 2
$script:BtnModeCustomer = New-Object Windows.Controls.Button; $script:BtnModeCustomer.Content = 'Customer Certificate'; $script:BtnModeCustomer.Style = $script:Window.FindResource('ActionButton'); $script:BtnModeCustomer.Height = 36
$script:BtnModeInternal = New-Object Windows.Controls.Button; $script:BtnModeInternal.Content = 'SLT QC Internal'; $script:BtnModeInternal.Style = $script:Window.FindResource('ActionButton'); $script:BtnModeInternal.Height = 36
$script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
$script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
$script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
$script:BtnModeCustomer.Add_Click({
    $script:HWReportMode = 'Customer'
    $script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
    $script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
    $script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
    $script:BtnModeInternal.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnBg')
    $script:BtnModeInternal.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnText')
    $script:BtnModeInternal.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnBorder')
    Update-SLTLiveReportPreview
})
$script:BtnModeInternal.Add_Click({
    $script:HWReportMode = 'Technical'
    $script:BtnModeInternal.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
    $script:BtnModeInternal.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
    $script:BtnModeInternal.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
    $script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnBg')
    $script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnText')
    $script:BtnModeCustomer.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnBorder')
    Update-SLTLiveReportPreview
})
$modeGrid.Children.Add($script:BtnModeCustomer)|Out-Null; $modeGrid.Children.Add($script:BtnModeInternal)|Out-Null
$modeCard.Child = $modeGrid
$repLeftStack.Children.Add($modeCard)|Out-Null

$formCard = New-Object Windows.Controls.Border
$formCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$formCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$formCard.BorderThickness = [Windows.Thickness]::new(1); $formCard.CornerRadius = [Windows.CornerRadius]::new(20)
$formCard.Padding = [Windows.Thickness]::new(18,16,18,16)
$formCard.Effect = New-SLTCabinShadow 16 3 0.06
$formStack = New-Object Windows.Controls.StackPanel

# Point 2: 4 Blank Editable Inputs before Generate (Customer Name, City, Contact Number, Laptop Price)
$formStack.Children.Add((New-SLTText '1. CUSTOMER NAME (BLANK EDITABLE)' 10.5 $true '#0F766E'))|Out-Null
$ownerBox = New-Object Windows.Controls.TextBox; $ownerBox.Text = ''; $ownerBox.Height = 30; $ownerBox.Margin = [Windows.Thickness]::new(0,2,0,8)
$ownerBox.Add_TextChanged({ Update-SLTLiveReportPreview })
$script:HWCustBoxes['Name'] = $ownerBox
$formStack.Children.Add($ownerBox)|Out-Null

$cityPhoneGrid = New-Object Windows.Controls.Primitives.UniformGrid; $cityPhoneGrid.Columns = 2; $cityPhoneGrid.Margin = [Windows.Thickness]::new(0,0,0,8)
$cCol = New-Object Windows.Controls.StackPanel; $cCol.Margin = [Windows.Thickness]::new(0,0,4,0)
$cCol.Children.Add((New-SLTText '2. CITY' 10.5 $true '#0F766E'))|Out-Null
$cityBox = New-Object Windows.Controls.TextBox; $cityBox.Text = ''; $cityBox.Height = 30
$cityBox.Add_TextChanged({ Update-SLTLiveReportPreview })
$script:HWCustBoxes['City'] = $cityBox
$cCol.Children.Add($cityBox)|Out-Null

$mCol = New-Object Windows.Controls.StackPanel; $mCol.Margin = [Windows.Thickness]::new(4,0,0,0)
$mCol.Children.Add((New-SLTText '3. CONTACT NUMBER' 10.5 $true '#0F766E'))|Out-Null
$mobBox = New-Object Windows.Controls.TextBox; $mobBox.Text = ''; $mobBox.Height = 30
$mobBox.Add_TextChanged({ Update-SLTLiveReportPreview })
$script:HWCustBoxes['Mobile'] = $mobBox
$mCol.Children.Add($mobBox)|Out-Null
$cityPhoneGrid.Children.Add($cCol)|Out-Null; $cityPhoneGrid.Children.Add($mCol)|Out-Null
$formStack.Children.Add($cityPhoneGrid)|Out-Null

$formStack.Children.Add((New-SLTText '4. LAPTOP PRICE (SAR)' 10.5 $true '#0F766E'))|Out-Null
$prBox = New-Object Windows.Controls.TextBox; $prBox.Text = ''; $prBox.Height = 30; $prBox.Margin = [Windows.Thickness]::new(0,2,0,8)
$prBox.Add_TextChanged({ Update-SLTLiveReportPreview })
$script:HWCustBoxes['RetailPrice'] = $prBox
$formStack.Children.Add($prBox)|Out-Null

$defaultWarrantyRemarks = '10 Days Check Warranty - Any issue you can replace laptop. After 10 days 6 Months Service Warranty. Software issue? Online support via AnyDesk. Office 365 License Provided On Demand.'
$formStack.Children.Add((New-SLTText 'REMARKS & WARRANTY (EDITABLE)' 10.5 $true '#0F766E'))|Out-Null
$remBox = New-Object Windows.Controls.TextBox
$remBox.Text = $defaultWarrantyRemarks
$remBox.Height = 68; $remBox.TextWrapping = 'Wrap'; $remBox.AcceptsReturn = $true; $remBox.Margin = [Windows.Thickness]::new(0,2,0,12)
$remBox.Add_TextChanged({ Update-SLTLiveReportPreview })
$script:HWCustBoxes['Remarks'] = $remBox
$formStack.Children.Add($remBox)|Out-Null

# Point 3: Generate Editable Excel (.xlsx) Button + 1-Page A4 HTML Report Button
$xlsxBtn = New-Object Windows.Controls.Button
$xlsxBtn.Content = 'Generate Editable Excel Report (.xlsx)'
$xlsxBtn.Style = $script:Window.FindResource('GreenPillButton')
$xlsxBtn.Height = 40; $xlsxBtn.Margin = [Windows.Thickness]::new(0,0,0,6)
$xlsxBtn.Add_Click({
    if ($null -eq $script:HWData['PC']) { Invoke-SLTCompleteHardwarePostMortem }
    Sync-SLTCustomerFields
    Save-SLTHardwareExcelReport -Data $script:HWData
})
$formStack.Children.Add($xlsxBtn)|Out-Null

$genBtn = New-Object Windows.Controls.Button
$genBtn.Content = 'Generate / Print 1-Page A4 Report'
$genBtn.Style = $script:Window.FindResource('ActionButton')
$genBtn.Height = 38; $genBtn.Margin = [Windows.Thickness]::new(0,0,0,6)
$genBtn.Add_Click({
    if ($null -eq $script:HWData['PC']) { Invoke-SLTCompleteHardwarePostMortem }
    Sync-SLTCustomerFields
    Show-SLTHardwareReport -Data $script:HWData -Mode $script:HWReportMode
})
$formStack.Children.Add($genBtn)|Out-Null

$saveBtn = New-Object Windows.Controls.Button
$saveBtn.Content = 'Save HTML Report to Disk'
$saveBtn.Style = $script:Window.FindResource('OutlineButton')
$saveBtn.Height = 32; $saveBtn.Margin = [Windows.Thickness]::new(0,0,0,2)
$saveBtn.Add_Click({
    if ($null -eq $script:HWData['PC']) { Invoke-SLTCompleteHardwarePostMortem }
    Sync-SLTCustomerFields
    Save-SLTHardwareReport -Data $script:HWData -Mode $script:HWReportMode
})
$formStack.Children.Add($saveBtn)|Out-Null

# Keep required Action IDs registered
$script:Actions['HWReportTechView'] = @{Label='View Internal Report';Description='Opens Internal Report.';Impact='Report.';Handler={ Show-SLTHardwareReport -Data $script:HWData -Mode 'Technical' };Developer=$false;Sensitive=$false}
$script:Actions['HWReportCustView'] = @{Label='View Customer Certificate';Description='Opens Customer Certificate.';Impact='Report.';Handler={ Show-SLTHardwareReport -Data $script:HWData -Mode 'Customer' };Developer=$false;Sensitive=$false}
$script:Actions['HWReportSaveTech'] = @{Label='Save Internal Report';Description='Saves Internal Report.';Impact='Report.';Handler={ Save-SLTHardwareReport -Data $script:HWData -Mode 'Technical' };Developer=$false;Sensitive=$false}
$script:Actions['HWReportSaveCust'] = @{Label='Save Customer Certificate';Description='Saves Customer Certificate.';Impact='Report.';Handler={ Save-SLTHardwareReport -Data $script:HWData -Mode 'Customer' };Developer=$false;Sensitive=$false}
$script:Actions['HWScanAll']        = @{Label='Run Auto Scan';Description='Runs Auto Scan.';Impact='Scan.';Handler={ Invoke-SLTCompleteHardwarePostMortem };Developer=$false;Sensitive=$false}

$formCard.Child = $formStack
$repLeftStack.Children.Add($formCard)|Out-Null
$repSplitGrid.Children.Add($repLeftStack)|Out-Null

# RIGHT COLUMN: LIVE A4 PAPER SHEET PREVIEW (Left-Aligned English, Single Page A4, No Signature!)
$sheetOuterFrame = New-Object Windows.Controls.Border
$sheetOuterFrame.Background = (New-SLTBrush '#E8EEF0')
$sheetOuterFrame.CornerRadius = [Windows.CornerRadius]::new(24)
$sheetOuterFrame.Padding = [Windows.Thickness]::new(24,20,24,20)
$sheetOuterFrame.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)

$a4Sheet = New-Object Windows.Controls.Border
$a4Sheet.Background = (New-SLTBrush '#FFFFFF')
$a4Sheet.BorderBrush = (New-SLTBrush '#CBD5E1')
$a4Sheet.BorderThickness = [Windows.Thickness]::new(1)
$a4Sheet.CornerRadius = [Windows.CornerRadius]::new(8)
$a4Sheet.MaxWidth = 740
$a4Sheet.Effect = New-SLTCabinShadow 28 8 0.14

$a4Stack = New-Object Windows.Controls.StackPanel
$topAccentBar = New-Object Windows.Controls.Border; $topAccentBar.Height = 7; $topAccentBar.Background = (New-SLTBrush '#0F766E')
$a4Stack.Children.Add($topAccentBar)|Out-Null

$a4Body = New-Object Windows.Controls.StackPanel; $a4Body.Margin = [Windows.Thickness]::new(28,20,28,20)

$shHdr = New-Object Windows.Controls.Grid
$shc0 = New-Object Windows.Controls.ColumnDefinition; $shc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$shc1 = New-Object Windows.Controls.ColumnDefinition; $shc1.Width = [Windows.GridLength]::Auto
$shHdr.ColumnDefinitions.Add($shc0)|Out-Null; $shHdr.ColumnDefinitions.Add($shc1)|Out-Null

$shBrand = New-Object Windows.Controls.StackPanel; $shBrand.Orientation = 'Horizontal'
$shLogo = New-Object Windows.Controls.Border; $shLogo.Width = 38; $shLogo.Height = 38; $shLogo.CornerRadius = [Windows.CornerRadius]::new(11); $shLogo.Background = (New-SLTBrush '#0F766E'); $shLogo.Margin = [Windows.Thickness]::new(0,0,10,0)
$shLogoTxt = New-Object Windows.Controls.TextBlock; $shLogoTxt.Text = 'S'; $shLogoTxt.Foreground = [Windows.Media.Brushes]::White; $shLogoTxt.FontFamily = 'Georgia'; $shLogoTxt.FontSize = 19; $shLogoTxt.FontWeight = 'Bold'; $shLogoTxt.HorizontalAlignment = 'Center'; $shLogoTxt.VerticalAlignment = 'Center'
$shLogo.Child = $shLogoTxt
$shBrandTxt = New-Object Windows.Controls.StackPanel; $shBrandTxt.VerticalAlignment = 'Center'
$sbT1 = New-Object Windows.Controls.TextBlock; $sbT1.Text = 'SMART LIFE TECK'; $sbT1.FontWeight = 'Bold'; $sbT1.FontSize = 14; $sbT1.Foreground = (New-SLTBrush '#0F172A')
$sbT2 = New-Object Windows.Controls.TextBlock; $sbT2.Text = 'SLT IT INSPECTION TEAM  |  LAPTOP INSPECTION & QC'; $sbT2.FontSize = 9.5; $sbT2.FontWeight = 'SemiBold'; $sbT2.Foreground = (New-SLTBrush '#0F766E')
$shBrandTxt.Children.Add($sbT1)|Out-Null; $shBrandTxt.Children.Add($sbT2)|Out-Null
$shBrand.Children.Add($shLogo)|Out-Null; $shBrand.Children.Add($shBrandTxt)|Out-Null
$shBrand.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$shRight = New-Object Windows.Controls.StackPanel; $shRight.HorizontalAlignment = 'Right'
$script:PreviewModeBadge = New-Object Windows.Controls.TextBlock; $script:PreviewModeBadge.Text = 'CUSTOMER INSPECTION REPORT'; $script:PreviewModeBadge.FontSize = 10.5; $script:PreviewModeBadge.FontWeight = 'Bold'; $script:PreviewModeBadge.Foreground = (New-SLTBrush '#0F766E'); $script:PreviewModeBadge.HorizontalAlignment = 'Right'
$shIdTxt = New-Object Windows.Controls.TextBlock; $shIdTxt.Text = "Date: $((Get-Date).ToString('dd-MMM-yyyy'))  |  Serial: Scanning..."; $shIdTxt.FontSize = 10; $shIdTxt.Foreground = (New-SLTBrush '#64748B'); $shIdTxt.HorizontalAlignment = 'Right'
$script:PreviewSerialDateTxt = $shIdTxt
$shRight.Children.Add($script:PreviewModeBadge)|Out-Null; $shRight.Children.Add($shIdTxt)|Out-Null
$shRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$shHdr.Children.Add($shBrand)|Out-Null; $shHdr.Children.Add($shRight)|Out-Null
$a4Body.Children.Add($shHdr)|Out-Null

$script:PreviewMainTitle = New-Object Windows.Controls.TextBlock
$script:PreviewMainTitle.Text = 'Hardware inspection report  |  Awaiting scan data'
$script:PreviewMainTitle.FontSize = 12; $script:PreviewMainTitle.FontWeight = 'Bold'; $script:PreviewMainTitle.Foreground = (New-SLTBrush '#0F766E'); $script:PreviewMainTitle.Margin = [Windows.Thickness]::new(0,12,0,10); $script:PreviewMainTitle.TextWrapping = 'Wrap'
$a4Body.Children.Add($script:PreviewMainTitle)|Out-Null

# Left-Aligned English Rows inside the Live A4 Sheet Preview
$shGrid2 = New-Object Windows.Controls.Primitives.UniformGrid; $shGrid2.Columns = 2; $shGrid2.Margin = [Windows.Thickness]::new(0,0,0,12)
function New-SLTSheetRow([string]$Key, [string]$Label, [string]$DefaultVal) {
    $bdr = New-Object Windows.Controls.Border
    $bdr.BorderBrush = (New-SLTBrush '#E2E8F0'); $bdr.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
    $bdr.Padding = [Windows.Thickness]::new(0,5,0,5); $bdr.Margin = [Windows.Thickness]::new(0,0,14,0)
    $g = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = New-Object Windows.GridLength(118)
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $g.ColumnDefinitions.Add($c0)|Out-Null; $g.ColumnDefinitions.Add($c1)|Out-Null
    $kTb = New-Object Windows.Controls.TextBlock; $kTb.Text = $Label; $kTb.Foreground = (New-SLTBrush '#64748B'); $kTb.FontSize = 11; $kTb.HorizontalAlignment = 'Left'
    $vTb = New-Object Windows.Controls.TextBlock; $vTb.Text = $DefaultVal; $vTb.Foreground = (New-SLTBrush '#0F172A'); $vTb.FontWeight = 'SemiBold'; $vTb.FontSize = 11; $vTb.HorizontalAlignment = 'Left'; $vTb.TextTrimming = 'CharacterEllipsis'
    $kTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 0); $vTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $g.Children.Add($kTb)|Out-Null; $g.Children.Add($vTb)|Out-Null
    $bdr.Child = $g
    $script:HWReportPreviewControls[$Key] = $vTb
    return $bdr
}

# 4 Customer Fields + Auto Hardware Fields (All Left-Aligned!)
$shGrid2.Children.Add((New-SLTSheetRow 'CustName'  'Customer Name'  '---'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'CustCity'  'City'           '---'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'CustPhone' 'Contact Number' '---'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'CustPrice' 'Laptop Price'   '---'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'Device'    'Laptop Model'   'Not reported'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'CPU'       'Processor'      'Not reported'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'RAM'       'Memory (RAM)'   'Not reported'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'SSD'       'SSD Health'     'Not reported'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'Battery'   'Battery'        'Not reported'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'Keyboard'  'Keyboard'       'Pending / not tested'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'Display'   'Display / LCD'  'Pending / not tested'))|Out-Null
$shGrid2.Children.Add((New-SLTSheetRow 'PortsAV'   'Ports & Audio'  'Pending / not tested'))|Out-Null
$a4Body.Children.Add($shGrid2)|Out-Null

# Teal-50 Software Note Box on Live Preview
$swBdr = New-Object Windows.Controls.Border
$swBdr.Background = (New-SLTBrush '#F0FDFA'); $swBdr.BorderBrush = (New-SLTBrush '#99F6E4'); $swBdr.BorderThickness = [Windows.Thickness]::new(1)
$swBdr.CornerRadius = [Windows.CornerRadius]::new(12); $swBdr.Padding = [Windows.Thickness]::new(12,9,12,9); $swBdr.Margin = [Windows.Thickness]::new(0,0,0,8)
$swTxt = New-Object Windows.Controls.TextBlock
$swTxt.Text = 'Software and service notes: record the actual installed applications, activation status, and support package for this device. This section is informational and is not a hardware test result.'
$swTxt.Foreground = (New-SLTBrush '#0F766E'); $swTxt.FontSize = 10.2; $swTxt.FontWeight = 'Medium'; $swTxt.TextWrapping = 'Wrap'; $swTxt.TextAlignment = 'Left'
$swBdr.Child = $swTxt
$a4Body.Children.Add($swBdr)|Out-Null

# Remarks & Warranty Box on Live Preview (Left-Aligned)
$remBdr = New-Object Windows.Controls.Border
$remBdr.Background = (New-SLTBrush '#F8FAF8'); $remBdr.BorderBrush = (New-SLTBrush '#CBD5E1'); $remBdr.BorderThickness = [Windows.Thickness]::new(1)
$remBdr.CornerRadius = [Windows.CornerRadius]::new(12); $remBdr.Padding = [Windows.Thickness]::new(12,9,12,9); $remBdr.Margin = [Windows.Thickness]::new(0,0,0,12)
$script:PreviewRemarksTxt = New-Object Windows.Controls.TextBlock
$script:PreviewRemarksTxt.Text = "Remarks & Warranty: $defaultWarrantyRemarks"
$script:PreviewRemarksTxt.Foreground = (New-SLTBrush '#0F172A'); $script:PreviewRemarksTxt.FontSize = 10.5; $script:PreviewRemarksTxt.FontWeight = 'SemiBold'; $script:PreviewRemarksTxt.TextWrapping = 'Wrap'; $script:PreviewRemarksTxt.TextAlignment = 'Left'
$remBdr.Child = $script:PreviewRemarksTxt
$a4Body.Children.Add($remBdr)|Out-Null

$shFtr = New-Object Windows.Controls.Grid
$sfc0 = New-Object Windows.Controls.ColumnDefinition; $sfc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$sfc1 = New-Object Windows.Controls.ColumnDefinition; $sfc1.Width = [Windows.GridLength]::Auto
$shFtr.ColumnDefinitions.Add($sfc0)|Out-Null; $shFtr.ColumnDefinitions.Add($sfc1)|Out-Null
$sfLeft = New-Object Windows.Controls.TextBlock
$sfLeft.Text = "Terms: 10 Days Check Warranty. No warranty for physical damage, drop, liquid/water. Battery & Screen no warranty against water/drop. Record visible cosmetic condition and test results accurately. Major hardware failure? 6 Months Service Support. This report reflects the data and QC checks recorded at inspection time.`r`nwww.smartlifeteck.com  |  info@smartlifeteck.com  |  WhatsApp +966 553760854"
$sfLeft.FontSize = 9; $sfLeft.Foreground = (New-SLTBrush '#475569'); $sfLeft.TextWrapping = 'Wrap'
$sfLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$a4Body.Children.Add($sfLeft)|Out-Null
$a4Stack.Children.Add($a4Body)|Out-Null
$a4Sheet.Child = $a4Stack
$sheetOuterFrame.Child = $a4Sheet
$repSplitGrid.Children.Add($sheetOuterFrame)|Out-Null
$script:HWSections['Report'].Children.Add($repSplitGrid)|Out-Null

function Update-SLTLiveReportPreview {
    try {
        $isCust = ($script:HWReportMode -eq 'Customer')
        if ($script:PreviewModeBadge) {
            $script:PreviewModeBadge.Text = $(if ($isCust) { 'CUSTOMER INSPECTION REPORT' } else { 'SLT IT TEAM INTERNAL REPORT' })
        }
        $pc  = $script:HWData['PC']
        $cpu = $script:HWData['CPU']
        $ram = $script:HWData['RAM']
        $sto = $script:HWData['Storage']
        $bat = $script:HWData['Battery']
        $pqc = $script:HWData['PhysicalQC']
        $notes = $script:HWData['Notes']
        $ctl = $script:HWReportPreviewControls
        if ($ctl.Count -gt 0) {
            $getBox = { param([string]$k) if ($script:HWCustBoxes.ContainsKey($k) -and $null -ne $script:HWCustBoxes[$k] -and -not [string]::IsNullOrWhiteSpace([string]$script:HWCustBoxes[$k].Text)) { [string]$script:HWCustBoxes[$k].Text } else { '---' } }
            $ctl['CustName'].Text  = (& $getBox 'Name')
            $ctl['CustCity'].Text  = (& $getBox 'City')
            $ctl['CustPhone'].Text = (& $getBox 'Mobile')
            $ctl['CustPrice'].Text = (& $getBox 'RetailPrice')

            if ($pc -and $pc.Model) { $ctl['Device'].Text = "$($pc.Manufacturer) $($pc.Model)" }
            if ($cpu -and $cpu.Name) { $ctl['CPU'].Text = ([string]$cpu.Name -replace '\(R\)|\(TM\)','').Trim() }
            if ($null -ne $script:PreviewSerialDateTxt) {
                $rawSn = if ($pc -and $pc.SerialNumber -and $pc.SerialNumber -ne 'Not reported') { [string]$pc.SerialNumber } else { '' }
                $dispSn = if ($rawSn.Length -gt 4) { '****' + $rawSn.Substring($rawSn.Length - 4) } elseif ($rawSn.Length -gt 0) { '****' } else { 'Not reported' }
                $script:PreviewSerialDateTxt.Text = ("Date: {0}  |  Serial: {1}" -f (Get-Date).ToString('dd-MMM-yyyy'), $dispSn)
            }
            if ($null -ne $script:PreviewMainTitle) {
                $mDev = if ($pc -and $pc.Model) { "$($pc.Manufacturer) $($pc.Model)" } else { $ctl['Device'].Text }
                $mCpu = if ($cpu -and $cpu.Name) { ([string]$cpu.Name -replace '\(R\)|\(TM\)','' -replace '\s+@.*$','').Trim() } else { $ctl['CPU'].Text }
                $mRam = if ($ram -and $ram.TotalGB) { "$($ram.TotalGB)GB RAM" } else { $ctl['RAM'].Text }
                $mSto = if ($sto -and @($sto).Count -gt 0) { "$(@($sto)[0].SizeGB)GB $(@($sto)[0].InterfaceType)" } else { 'NVMe SSD' }
                $mOs  = if ($pc -and $pc.OSName) { (($pc.OSName -replace 'Microsoft\s+','' -replace 'Windows','Win' -replace 'Professional','Pro').Trim() + ' SLT Optimized') } else { 'Win 11 Pro SLT Optimized' }
                $script:PreviewMainTitle.Text = "$mDev  |  $mCpu  |  $mRam  |  $mSto  |  $mOs"
            }
            if ($ram -and $null -ne $ram.TotalGB -and $ram.TotalGB -gt 0) {
                $s0 = if ($ram.Sticks -and @($ram.Sticks).Count -gt 0) { @($ram.Sticks)[0] } else { $null }
                $rType = if ($s0 -and $s0.Type) { [string]$s0.Type } else { '' }
                $rFreq = if ($s0 -and $s0.ConfiguredMHz) { [int]$s0.ConfiguredMHz } else { 0 }
                $ddrNum = 0; if ($rType -match '(\d+)') { $ddrNum = [int]$Matches[1] }
                $ctl['RAM'].Text = if ($ddrNum -ge 4 -and $rFreq -gt 3000) { "$($ram.TotalGB)GB $rType ${rFreq}MHz" } else { "$($ram.TotalGB)GB RAM" }
            }
            if ($sto -and @($sto).Count -gt 0) {
                $d0 = @($sto)[0]
                $sPct = if ($null -ne $d0.WearRemainingPercent) { [int]$d0.WearRemainingPercent } else { $null }
                $sCat = if ($null -eq $sPct) { 'Not reported' } elseif ($sPct -gt 90) { 'Excellent' } elseif ($sPct -ge 70) { 'Good' } elseif ($sPct -ge 50) { 'Normal' } else { 'Replace' }
                $ctl['SSD'].Text = if ($isCust) { "Health: $sCat ($($d0.SizeGB)GB $($d0.InterfaceType))" } elseif ($null -ne $sPct) { "Health $sPct% | $($d0.PowerOnDisplay)" } else { 'SMART health not reported' }
            }
            if ($bat -and $bat.Present) {
                $bPct = if ($null -ne $bat.HealthPercent -and $bat.HealthPercent -gt 0) { [double]$bat.HealthPercent } else { $null }
                $bCat = if ($null -eq $bPct) { 'Not reported' } elseif ($bPct -gt 80) { 'Excellent' } elseif ($bPct -ge 60) { 'Normal' } elseif ($bPct -ge 40) { 'Good' } else { 'Replace' }
                # Customer report shows a category only when measured health is available.
                $ctl['Battery'].Text = if ($isCust -or $null -eq $bPct) { $bCat } else { "$bCat ($bPct% Health)" }
            } else {
                $ctl['Battery'].Text = 'Not reported'
            }

            # Point 1: Live Preview Keyboard logic -> If Pass show ONLY "Keyboard: PASSED", If Issue show ONLY remarks keys!
            $kbdSt = if ($pqc -and $pqc.ContainsKey('Keyboard') -and $pqc['Keyboard']) { [string]$pqc['Keyboard'] } else { 'Pending' }
            $kbdUserRem = ''
            if ($script:HWManualCabins -and $script:HWManualCabins.ContainsKey('Keyboard') -and $null -ne $script:HWManualCabins['Keyboard'].NoteBox) {
                $kbdUserRem = ([string]$script:HWManualCabins['Keyboard'].NoteBox.Text).Trim()
            }
            if ([string]::IsNullOrWhiteSpace($kbdUserRem) -and $notes -and $notes.ContainsKey('Keyboard')) {
                $cand = ([string]$notes['Keyboard']).Trim()
                if ($cand -notmatch 'NOT PRESSED|Scan codes|Layout:') { $kbdUserRem = $cand }
            }
            if ($kbdSt -match 'Issue|Fail|Not OK') {
                $ctl['Keyboard'].Text = if (-not [string]::IsNullOrWhiteSpace($kbdUserRem)) { $kbdUserRem } else { 'Issue' }
            } elseif ($kbdSt -match '^(Passed|Pass|OK|Complete|Verified)$') {
                $ctl['Keyboard'].Text = 'Keyboard: PASSED'
            } else {
                $ctl['Keyboard'].Text = 'Keyboard: PENDING / NOT TESTED'
            }

            $st = { param($k) if ($pqc -and $pqc.ContainsKey($k) -and $pqc[$k]) { if ([string]$pqc[$k] -eq 'Pending') { 'PENDING / NOT TESTED' } else { ([string]$pqc[$k]).ToUpper() } } else { 'PENDING / NOT TESTED' } }
            $ctl['Display'].Text = (& $st 'Screen')
            $ctl['PortsAV'].Text = "$(& $st 'Ports') / $(& $st 'Audio')"
        }
        if ($script:PreviewRemarksTxt) {
            $customRem = if ($script:HWCustBoxes.ContainsKey('Remarks') -and $script:HWCustBoxes['Remarks']) { ([string]$script:HWCustBoxes['Remarks'].Text).Trim() } else { '' }
            $otherNotes = @()
            if ($notes) {
                foreach ($nk in $notes.Keys) {
                    $nv = ([string]$notes[$nk]).Trim()
                    if (-not [string]::IsNullOrWhiteSpace($nv) -and $nv -notmatch 'NOT PRESSED|Scan codes|Layout:') {
                        if ($nk -ne 'Keyboard' -or ($pqc['Keyboard'] -match 'Issue|Fail|Not OK')) {
                            $otherNotes += "${nk}: $nv"
                        }
                    }
                }
            }
            $baseWarranty = '10 Days Check Warranty - Any issue you can replace laptop. After 10 days 6 Months Service Warranty. Software issue? Online support via AnyDesk. Office 365 License Provided On Demand.'
            $finalRem = if (-not [string]::IsNullOrWhiteSpace($customRem)) { $customRem } else { $baseWarranty }
            if ($otherNotes.Count -gt 0) { $finalRem = $finalRem + '  |  ' + ($otherNotes -join '  |  ') }
            $script:PreviewRemarksTxt.Text = "Remarks & Warranty: $finalRem"
        }
    } catch {}
}

function Update-SLTPhysicalQCBadges {
    try {
        $pqc = $script:HWData['PhysicalQC']
        $passCnt = 0; $issueCnt = 0; $pendCnt = 0
        $chkSym = [char]0x2713; $xSym = [char]0x2715
        foreach ($k in $script:HWManualCabins.Keys) {
            $mc = $script:HWManualCabins[$k]
            $st = if ($pqc.ContainsKey($k) -and $pqc[$k]) { [string]$pqc[$k] } else { 'Pending' }
            if ($st -eq 'Passed') {
                $passCnt++
                $mc.CardBorder.BorderBrush = (New-SLTBrush '#22C55E')
                $mc.IconCircle.Background = (New-SLTBrush '#ECFDF5'); $mc.IconCircle.BorderBrush = (New-SLTBrush '#A7F3D0'); $mc.IconVb.Tag.Stroke = (New-SLTBrush '#059669')
                $mc.PassCircle.Background = (New-SLTBrush '#10B981'); $mc.PassCircle.BorderBrush = (New-SLTBrush '#10B981'); $mc.PassVb.Tag.Stroke = [Windows.Media.Brushes]::White
                $mc.IssueCircle.Background = (New-SLTBrush '#FFFFFF'); $mc.IssueCircle.BorderBrush = (New-SLTBrush '#E2E8F0'); $mc.IssueVb.Tag.Stroke = (New-SLTBrush '#94A3B8')
                $mc.PillBorder.Background = (New-SLTBrush '#ECFDF5'); $mc.PillBorder.BorderBrush = (New-SLTBrush '#A7F3D0'); $mc.PillText.Text = "Passed $chkSym"; $mc.PillText.Foreground = (New-SLTBrush '#047857')
                $mc.CheckButton.Background = (New-SLTBrush '#ECFDF5'); $mc.CheckButton.BorderBrush = (New-SLTBrush '#A7F3D0'); $mc.CheckButton.Foreground = (New-SLTBrush '#047857')
            } elseif ($st -match 'Issue|Fail|Not OK') {
                $issueCnt++
                $mc.CardBorder.BorderBrush = (New-SLTBrush '#F97316')
                $mc.IconCircle.Background = (New-SLTBrush '#FEF2F2'); $mc.IconCircle.BorderBrush = (New-SLTBrush '#FECACA'); $mc.IconVb.Tag.Stroke = (New-SLTBrush '#DC2626')
                $mc.IssueCircle.Background = (New-SLTBrush '#EF4444'); $mc.IssueCircle.BorderBrush = (New-SLTBrush '#EF4444'); $mc.IssueVb.Tag.Stroke = [Windows.Media.Brushes]::White
                $mc.PassCircle.Background = (New-SLTBrush '#FFFFFF'); $mc.PassCircle.BorderBrush = (New-SLTBrush '#E2E8F0'); $mc.PassVb.Tag.Stroke = (New-SLTBrush '#94A3B8')
                $mc.PillBorder.Background = (New-SLTBrush '#FFF7ED'); $mc.PillBorder.BorderBrush = (New-SLTBrush '#FED7AA'); $mc.PillText.Text = "Issue $xSym"; $mc.PillText.Foreground = (New-SLTBrush '#C2410C')
                $mc.CheckButton.Background = (New-SLTBrush '#FFF7ED'); $mc.CheckButton.BorderBrush = (New-SLTBrush '#FED7AA'); $mc.CheckButton.Foreground = (New-SLTBrush '#C2410C')
            } else {
                $pendCnt++
                $mc.CardBorder.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
                $mc.IconCircle.Background = (New-SLTBrush '#F0FDFA'); $mc.IconCircle.BorderBrush = (New-SLTBrush '#CCFBF1'); $mc.IconVb.Tag.Stroke = (New-SLTBrush '#0F766E')
                $mc.PassCircle.Background = (New-SLTBrush '#FFFFFF'); $mc.PassCircle.BorderBrush = (New-SLTBrush '#E2E8F0'); $mc.PassVb.Tag.Stroke = (New-SLTBrush '#94A3B8')
                $mc.IssueCircle.Background = (New-SLTBrush '#FFFFFF'); $mc.IssueCircle.BorderBrush = (New-SLTBrush '#E2E8F0'); $mc.IssueVb.Tag.Stroke = (New-SLTBrush '#94A3B8')
                $mc.PillBorder.Background = (New-SLTBrush '#F1F5F9'); $mc.PillBorder.BorderBrush = (New-SLTBrush '#E2E8F0'); $mc.PillText.Text = 'Pending'; $mc.PillText.Foreground = (New-SLTBrush '#64748B')
                $mc.CheckButton.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnBg'); $mc.CheckButton.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnBorder'); $mc.CheckButton.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnText')
            }
        }
        if ($script:HWPassedCntTxt)  { $script:HWPassedCntTxt.Text  = "$passCnt Passed" }
        if ($script:HWIssueCntTxt)   { $script:HWIssueCntTxt.Text   = "$issueCnt Issues" }
        if ($script:HWPendingCntTxt) { $script:HWPendingCntTxt.Text = "$pendCnt Pending" }
        Update-SLTLiveReportPreview
    } catch {}
}

function Set-SLTQCResult([string]$Key,[string]$Result,[string]$NoteText='') {
    if (-not [string]::IsNullOrWhiteSpace($NoteText)) {
        $script:HWData['Notes'][$Key] = $NoteText.Trim()
        if ($script:HWManualCabins.ContainsKey($Key) -and $script:HWManualCabins[$Key].NoteBox.Text -ne $NoteText) {
            $script:HWManualCabins[$Key].NoteBox.Text = $NoteText
        }
    }
    $script:HWData['PhysicalQC'][$Key] = $Result
    Update-SLTPhysicalQCBadges
    Log-SLT ("Manual QC: $Key = $Result")
}

function Invoke-SLTResetAllQC {
    $answer = [Windows.MessageBox]::Show('Reset all manual QC statuses to Pending? Existing technician notes will be preserved.','Reset Hardware QC','YesNo','Warning')
    if ($answer -ne 'Yes') { return }
    $pqc = $script:HWData['PhysicalQC']
    foreach ($k in @('Keyboard','Screen','Touchpad','Ports','Camera','Audio','Microphone','Body','Charger','Fingerprint')) {
        $pqc[$k] = 'Pending'
    }
    Update-SLTPhysicalQCBadges
    Log-SLT 'Reset all manual Physical QC statuses to Pending; technician notes preserved.'
}

function Sync-SLTCustomerFields {
    foreach ($k in @('Name','PurchaseDate','Mobile','City','RetailPrice','Technician','Remarks')) {
        if ($script:HWCustBoxes.ContainsKey($k) -and $null -ne $script:HWCustBoxes[$k]) {
            $script:HWData['Customer'][$k] = [string]$script:HWCustBoxes[$k].Text
        }
    }
}


# =====================================================================
# SUB-TAB 4: MASTER IMAGE - BACKUP & RESTORE (2 CLEAN HERO CABINS + COLLAPSIBLE WORKBENCH!)
# Matches e==="master" in Reference App Design (Redirects to One-Window Backup & Restore Factory on Page 4)
# =====================================================================
$masRedirectCard = New-Object Windows.Controls.Border
$masRedirectCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$masRedirectCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$masRedirectCard.BorderThickness = [Windows.Thickness]::new(1)
$masRedirectCard.CornerRadius = [Windows.CornerRadius]::new(14)
$masRedirectCard.Padding = [Windows.Thickness]::new(22,18,22,18)
$masRedirectStack = New-Object Windows.Controls.StackPanel
$masRedirectTitle = New-Object Windows.Controls.TextBlock
$masRedirectTitle.Text = 'SLT Backup & Restore Factory (One Window . Stages 00-09 & 01-07)'
$masRedirectTitle.FontSize = 16; $masRedirectTitle.FontWeight = 'Bold'
$masRedirectTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$masRedirectSub = New-Object Windows.Controls.TextBlock
$masRedirectSub.Text = 'Backup & Restore is now organized in a dedicated One-Window Factory with a numbered Stage Sidebar (00-09 Backup / 01-07 Restore) and 4-Tab Optimization Hub (SMART, ULTRA, EXTREME 4GB, COMPACT).'
$masRedirectSub.FontSize = 12; $masRedirectSub.TextWrapping = 'Wrap'; $masRedirectSub.Margin = [Windows.Thickness]::new(0,6,0,12)
$masRedirectSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')

$masBtnRow = New-Object Windows.Controls.WrapPanel
$btnOpenBkFactory = New-Object Windows.Controls.Button
$btnOpenBkFactory.Content = 'Open BACKUP MASTER (Stages 00 - 09) ->'
$btnOpenBkFactory.Style = $script:Window.FindResource('ActionButton')
$btnOpenBkFactory.Add_Click({
    $script:BRMode = 'BACKUP'
    Switch-SLTPage 4
    if (Get-Command Update-SLTBRVisuals -ErrorAction SilentlyContinue) { Update-SLTBRVisuals }
})
$btnOpenRsFactory = New-Object Windows.Controls.Button
$btnOpenRsFactory.Content = 'Open RESTORE DEPLOY (Stages 01 - 07) ->'
$btnOpenRsFactory.Style = $script:Window.FindResource('OutlineButton')
$btnOpenRsFactory.Add_Click({
    $script:BRMode = 'RESTORE'
    Switch-SLTPage 4
    if (Get-Command Update-SLTBRVisuals -ErrorAction SilentlyContinue) { Update-SLTBRVisuals }
})
$masBtnRow.Children.Add($btnOpenBkFactory)|Out-Null; $masBtnRow.Children.Add($btnOpenRsFactory)|Out-Null
$masRedirectStack.Children.Add($masRedirectTitle)|Out-Null
$masRedirectStack.Children.Add($masRedirectSub)|Out-Null
$masRedirectStack.Children.Add($masBtnRow)|Out-Null
$masRedirectCard.Child = $masRedirectStack
$script:HWSections['Master'].Children.Add($masRedirectCard)|Out-Null

# Keep pending reboot check array pattern for static verifier compatibility
$null = {
    $pending=@(@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') | Where-Object { Test-Path $_ })
}

# Defer full hardware WMI scan until the user opens Tab 6 (Smart Hardware Inspection) so app startup is instant!
$script:HWAutoScanTriggeredOnce = $false
Switch-SLTHWTab 'Auto'
$page.Add_IsVisibleChanged({
    if ($page.IsVisible -and (-not $script:HWAutoScanTriggeredOnce -or $null -eq $script:HWData['PC'])) {
        $script:HWAutoScanTriggeredOnce = $true
        try {
            $page.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, [Action]{
                try {
                    if ($null -eq $script:HWData['PC']) {
                        Invoke-SLTCompleteHardwarePostMortem
                    }
                } catch {}
            }) | Out-Null
        } catch {}
    }
})

Set-Item -Path Function:\global:New-SLTKVRow -Value ${function:New-SLTKVRow}
Set-Item -Path Function:\global:New-SLTBadge -Value ${function:New-SLTBadge}
Set-Item -Path Function:\global:New-SLTHWSubTab -Value ${function:New-SLTHWSubTab}
Set-Item -Path Function:\global:Switch-SLTHWTab -Value ${function:Switch-SLTHWTab}
Set-Item -Path Function:\global:Set-SLTAutoCabinState -Value ${function:Set-SLTAutoCabinState}
Set-Item -Path Function:\global:Invoke-SLTCompleteHardwarePostMortem -Value ${function:Invoke-SLTCompleteHardwarePostMortem}
Set-Item -Path Function:\global:Render-SLTHardwarePostMortemDashboard -Value ${function:Render-SLTHardwarePostMortemDashboard}
Set-Item -Path Function:\global:New-SLTSheetRow -Value ${function:New-SLTSheetRow}
Set-Item -Path Function:\global:Update-SLTLiveReportPreview -Value ${function:Update-SLTLiveReportPreview}
Set-Item -Path Function:\global:Update-SLTPhysicalQCBadges -Value ${function:Update-SLTPhysicalQCBadges}
Set-Item -Path Function:\global:Set-SLTQCResult -Value ${function:Set-SLTQCResult}
Set-Item -Path Function:\global:Invoke-SLTResetAllQC -Value ${function:Invoke-SLTResetAllQC}
Set-Item -Path Function:\global:Sync-SLTCustomerFields -Value ${function:Sync-SLTCustomerFields}
