$script:SLTNavIcons = @()
$script:SLTNavLabels = @()
$script:SLTNavChevrons = @()
$script:CurrentPageRenderedOnce = $false
$script:TweaksRenderedOnce = $false
$script:BusyOuterRing = $null
$script:BusyTickRing = $null
$script:BusyNeedleLine = $null
$script:BusyNeedleTip = $null
$script:BusyCenterCap = $null

function New-SLTBrush([string]$Hex) {
    return [Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
}

# Splash window functions (New-SLTSplashWindow, Update-SLTSplashProgress, Close-SLTSplash) are defined in core/00-Initialize.ps1

function New-SLTLucideIcon([string]$IconName, [double]$Size=18, [string]$ColorHex='#0F766E') {
    $pathMap = @{
        'Search'          = 'M19 11 A8 8 0 1 1 3 11 A8 8 0 1 1 19 11 Z M21 21 L16.7 16.7'
        'Keyboard'        = 'M4 4 H20 A2 2 0 0 1 22 6 V18 A2 2 0 0 1 20 20 H4 A2 2 0 0 1 2 18 V6 A2 2 0 0 1 4 4 Z M6 8 H6.5 M10 8 H10.5 M14 8 H14.5 M18 8 H18.5 M8 12 H8.5 M12 12 H12.5 M16 12 H16.5 M7 16 H17'
        'FileText'        = 'M15 2 H6 A2 2 0 0 0 4 4 V20 A2 2 0 0 0 6 22 H18 A2 2 0 0 0 20 20 V7 Z M14 2 V6 A2 2 0 0 0 16 8 H20 M10 9 H8 M16 13 H8 M16 17 H8'
        'HardDrive'       = 'M22 12 H2 M5.45 5.11 L2 12 V18 A2 2 0 0 0 4 20 H20 A2 2 0 0 0 22 18 V12 L18.55 5.11 A2 2 0 0 0 16.76 4 H7.24 A2 2 0 0 0 5.45 5.11 Z M6 16 H6.5 M10 16 H10.5'
        'Battery'         = 'M4 7 H16 A2 2 0 0 1 18 9 V15 A2 2 0 0 1 16 17 H4 A2 2 0 0 1 2 15 V9 A2 2 0 0 1 4 7 Z M22 11 V13'
        'Cpu'             = 'M6 4 H18 A2 2 0 0 1 20 6 V18 A2 2 0 0 1 18 20 H6 A2 2 0 0 1 4 18 V6 A2 2 0 0 1 6 4 Z M9 9 H15 V15 H9 Z M9 2 V4 M15 2 V4 M9 20 V22 M15 20 V22 M2 9 H4 M2 15 H4 M20 9 H22 M20 15 H22'
        'MemoryStick'     = 'M4 5 H20 A2 2 0 0 1 22 7 V17 A2 2 0 0 1 20 19 H4 A2 2 0 0 1 2 17 V7 A2 2 0 0 1 4 5 Z M2 15 H22 M6 19 V16 M10 19 V16 M14 19 V16 M18 19 V16 M8 11 V9 M12 11 V9 M16 11 V9'
        'Layers'          = 'M12 2 L2 7 L12 12 L22 7 Z M2 12 L12 17 L22 12 M2 17 L12 22 L22 17'
        'Box'             = 'M12 2 L3 7 V17 L12 22 L21 17 V7 Z M3.3 7 L12 12 L20.7 7 M12 22 V12'
        'Wifi'            = 'M2 8.8 A15 15 0 0 1 22 8.8 M5 12.8 A10 10 0 0 1 19 12.8 M8.5 16.4 A5 5 0 0 1 15.5 16.4 M12 20 H12.2'
        'Laptop'          = 'M6 5 H18 A2 2 0 0 1 20 7 V16 H4 V7 A2 2 0 0 1 6 5 Z M2 20 H22 L20 16 H4 Z'
        'Monitor'         = 'M4 3 H20 A2 2 0 0 1 22 5 V15 A2 2 0 0 1 20 17 H4 A2 2 0 0 1 2 15 V5 A2 2 0 0 1 4 3 Z M8 21 H16 M12 17 V21'
        'Mouse'           = 'M12 2 A7 7 0 0 1 19 9 V15 A7 7 0 0 1 5 15 V9 A7 7 0 0 1 12 2 Z M12 6 V10'
        'Usb'             = 'M4 20 L19 5 M21 3 L18 4 L20 6 Z M9.3 7.7 L5 12 L7 17 M10 14 L15 16 L18.5 12.5'
        'Camera'          = 'M14.5 4 H9.5 L7 7 H4 A2 2 0 0 0 2 9 V18 A2 2 0 0 0 4 20 H20 A2 2 0 0 0 22 18 V9 A2 2 0 0 0 20 7 H17 Z M15 13 A3 3 0 1 1 9 13 A3 3 0 1 1 15 13 Z'
        'Speaker'         = 'M6 2 H18 A2 2 0 0 1 20 4 V20 A2 2 0 0 1 18 22 H6 A2 2 0 0 1 4 20 V4 A2 2 0 0 1 6 2 Z M12 6 H12.2 M16 14 A4 4 0 1 1 8 14 A4 4 0 1 1 16 14 Z'
        'Zap'             = 'M13 2 L3 14 H12 L11 22 L21 10 H12 Z'
        'LayoutDashboard' = 'M3 3 H10 V12 H3 Z M14 3 H21 V8 H14 Z M14 12 H21 V21 H14 Z M3 16 H10 V21 H3 Z'
        'Download'        = 'M21 15 V19 A2 2 0 0 1 19 21 H5 A2 2 0 0 1 3 19 V15 M7 10 L12 15 L17 10 M12 15 V3'
        'Rocket'          = 'M4.5 16.5 C3 17.8 2.5 21.5 2.5 21.5 S6.2 21 7.5 19.5 M12 15 L9 12 C11 7 15 3 22 2 C21 9 17 13 12 15 Z M9 12 H4 L6 8 H11 M12 15 V20 L16 18 V13'
        'Settings'        = 'M12 8 A4 4 0 1 1 12 16 A4 4 0 1 1 12 8 Z M12 2 V5 M12 19 V22 M2 12 H5 M19 12 H22 M4.9 4.9 L7 7 M17 17 L19.1 19.1 M19.1 4.9 L17 7 M7 17 L4.9 19.1'
        'RefreshCw'       = 'M3 12 A9 9 0 0 1 18.7 5.7 L21 8 M21 3 V8 H16 M21 12 A9 9 0 0 1 5.3 18.3 L3 16 M8 16 H3 V21'
        'MessageCircle'   = 'M7.9 20 A9 9 0 1 0 4 16.1 L2 22 Z'
        'ChevronRight'    = 'M9 18 L15 12 L9 6'
        'ChevronDown'     = 'M6 9 L12 15 L18 9'
        'Check'           = 'M20 6 L9 17 L4 12'
        'X'               = 'M18 6 L6 18 M6 6 L18 18'
        'ShieldCheck'     = 'M20 13 C20 18 12 22 12 22 C12 22 4 18 4 13 V5 L12 2 L20 5 Z M9 12 L11 14 L15 10'
        'ArrowRight'      = 'M5 12 H19 M12 5 L19 12 L12 19'
        'Wrench'          = 'M14.7 6.3 A4 4 0 0 1 18 12 L10 20 A2 2 0 0 1 7 17 L15 9 A4 4 0 0 1 14.7 6.3 Z'
        'Mic'             = 'M12 2 A3 3 0 0 0 9 5 V12 A3 3 0 0 0 15 12 V5 A3 3 0 0 0 12 2 Z M19 10 V12 A7 7 0 0 1 5 12 V10 M12 19 V22'
        'Sparkles'        = 'M12 3 L14.5 9.5 L21 12 L14.5 14.5 L12 21 L9.5 14.5 L3 12 L9.5 9.5 Z M19 3 L19.8 5.2 L22 6 L19.8 6.8 L19 9 L18.2 6.8 L16 6 L18.2 5.2 Z'
    }
    $dStr = if ($pathMap.ContainsKey($IconName)) { $pathMap[$IconName] } else { $pathMap['Cpu'] }
    $vb = New-Object Windows.Controls.Viewbox
    $vb.Width = $Size; $vb.Height = $Size
    $cv = New-Object Windows.Controls.Canvas
    $cv.Width = 24; $cv.Height = 24
    $p = New-Object Windows.Shapes.Path
    $p.Data = [Windows.Media.Geometry]::Parse($dStr)
    $p.Stroke = (New-SLTBrush $ColorHex)
    $p.StrokeThickness = 1.95
    $p.StrokeStartLineCap = 'Round'; $p.StrokeEndLineCap = 'Round'; $p.StrokeLineJoin = 'Round'
    $cv.Children.Add($p)|Out-Null
    $vb.Child = $cv
    $vb.Tag = $p
    return $vb
}

function New-SLTCabinShadow([double]$Blur=16, [double]$Depth=3, [double]$Opacity=0.06, [string]$ColorHex='#0F172A') {
    # Lightweight zero-lag card rendering (avoids expensive WPF offscreen DropShadow bitmap shaders on tab switch)
    return $null
}

function New-SLTCabinFooterPill {
    $bdr = New-Object Windows.Controls.Border
    $bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $bdr.BorderThickness = [Windows.Thickness]::new(1)
    $bdr.CornerRadius = [Windows.CornerRadius]::new(20)
    $bdr.Padding = [Windows.Thickness]::new(18,9,18,9)
    $bdr.Margin = [Windows.Thickness]::new(6,24,6,8)
    $bdr.HorizontalAlignment = 'Center'
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Center'; $row.VerticalAlignment = 'Center'
    $dot = ([char]0x2022)
    $t1 = New-Object Windows.Controls.TextBlock
    $t1.Text = "$dot Cabin Style Clean $dot Apple-widget premium   |   "
    $t1.FontSize = 10.5; $t1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $t2 = New-Object Windows.Controls.TextBlock
    $t2.Text = 'Smart Life Teck - Shahzad Babar'
    $t2.FontSize = 10.5; $t2.FontWeight = 'SemiBold'; $t2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
    $t3 = New-Object Windows.Controls.TextBlock
    $t3.Text = '   |   www.smartlifeteck.com   |   info@smartlifeteck.com   |   WhatsApp +966 553760854   |   '
    $t3.FontSize = 10.5; $t3.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    $shIc = New-SLTLucideIcon 'ShieldCheck' 12 '#047857'
    try { if ($null -ne $shIc.Tag) { $shIc.Tag.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, 'SLTStatusOk') } } catch {}
    $shIc.Margin = [Windows.Thickness]::new(0,0,4,0); $shIc.VerticalAlignment = 'Center'
    $t4 = New-Object Windows.Controls.TextBlock
    $t4.Text = 'System Protected'
    $t4.FontSize = 10.5; $t4.FontWeight = 'Medium'; $t4.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
    foreach ($el in @($t1,$t2,$t3,$shIc,$t4)) { $row.Children.Add($el)|Out-Null }
    $bdr.Child = $row
    return $bdr
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
if ($null -eq $script:SLTSplashWindow) { New-SLTSplashWindow | Out-Null }
[xml]$xaml=Get-Content -LiteralPath (Join-Path $script:Root 'ui\Main.xaml') -Raw
$reader=New-Object System.Xml.XmlNodeReader $xaml
$script:Window=[Windows.Markup.XamlReader]::Load($reader)
$script:LogBox=$script:Window.FindName('LogBox')
$script:HelpBox=$script:Window.FindName('HelpBox')
$script:HostControl=$script:Window.FindName('PageHost')
$script:TitleBlock=$script:Window.FindName('PageTitle')
$script:SubtitleBlock=$script:Window.FindName('PageSubtitle')
$script:ThemeSelector=$script:Window.FindName('ThemeSelector')
try {
    $image=[Windows.Media.Imaging.BitmapImage]::new()
    $image.BeginInit();$image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $image.UriSource=[Uri]::new((Join-Path $script:Root 'assets\SLT_Emblem.png'))
    $image.EndInit();$script:Window.FindName('BrandLogo').Source=$image
    $script:Window.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new((Join-Path $script:Root 'assets\SLT_PC_CARE_PRO.ico')))
} catch {Log-SLT ('Brand image load warning: '+$_.Exception.Message)}

function Apply-SLTDialogTheme([Windows.Window]$Dialog) {
    if ($null -eq $Dialog) { return }
    foreach ($rk in $script:Window.Resources.Keys) {
        $Dialog.Resources[$rk] = $script:Window.Resources[$rk]
    }
    $Dialog.SetResourceReference([Windows.Window]::BackgroundProperty, 'WindowBg')
    $Dialog.SetResourceReference([Windows.Window]::ForegroundProperty, 'TextPrimary')
    $Dialog.FontFamily = 'Segoe UI'
    $isLight = $false
    try {
        $bg = $script:Window.Resources['WindowBg']
        if ($bg -and $bg.Color) {
            $lum = 0.299 * $bg.Color.R + 0.587 * $bg.Color.G + 0.114 * $bg.Color.B
            $isLight = ($lum -gt 128)
        }
    } catch {}
    if ($isLight) {
        $Dialog.Resources['SLTStatusWarn'] = (New-SLTBrush '#92400E')
        $Dialog.Resources['SLTStatusError'] = (New-SLTBrush '#B91C1C')
        $Dialog.Resources['SLTStatusOk'] = (New-SLTBrush '#047857')
        $Dialog.Resources['SLTStatusInfo'] = (New-SLTBrush '#0D2137')
    } else {
        $Dialog.Resources['SLTStatusWarn'] = (New-SLTBrush '#FCD34D')
        $Dialog.Resources['SLTStatusError'] = (New-SLTBrush '#F87171')
        $Dialog.Resources['SLTStatusOk'] = (New-SLTBrush '#34D399')
        $Dialog.Resources['SLTStatusInfo'] = (New-SLTBrush '#E2E8F0')
    }
    $Dialog.Resources['SLTDialogWarnBg'] = (New-SLTBrush $(if ($isLight) { '#FEF3C7' } else { '#451A03' }))
}

function New-SLTDialogButton([string]$Content, [string]$BackgroundHex, [string]$ForegroundHex='#FFFFFF', [int]$MinWidth=120) {
    $b = New-Object Windows.Controls.Button
    $b.Content = $Content; $b.MinWidth = $MinWidth; $b.MinHeight = 38
    $b.Style = $script:Window.FindResource('ActionButton')
    $b.Background = (New-SLTBrush $BackgroundHex)
    $b.Foreground = (New-SLTBrush $ForegroundHex)
    return $b
}

function Test-SLTLightTheme {
    try { if ($script:Themes.PSObject.Properties[$script:CurrentTheme]) { return [bool]$script:Themes.($script:CurrentTheme).IsLight } } catch {}
    return $false
}

function Invoke-SLTMainWindowForeground {
    try {
        if ($null -eq $script:Window) { return }
        try { $script:Window.Owner = $null } catch {}
        try { $script:Window.ShowInTaskbar = $true } catch {}
        $script:Window.WindowState = 'Maximized'
        $script:Window.Topmost = $true
        try { $script:Window.Activate() } catch {}
        try { $script:Window.Focus() } catch {}
        $script:Window.Topmost = $false
    } catch {}
}

function Select-SLTButton([Windows.Controls.Control]$Btn) {
    if ($null -eq $Btn) { return }
    try {
        if ($null -ne $script:SelectedActionBtn -and $script:SelectedActionBtn -ne $Btn) {
            $script:SelectedActionBtn.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnBg')
            $script:SelectedActionBtn.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnText')
            $script:SelectedActionBtn.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnBorder')
        }
        $script:SelectedActionBtn = $Btn
        $Btn.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
        $Btn.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
        $Btn.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
    } catch {}
}

function Select-SLTBorderButton([Windows.Controls.Border]$Bdr, [Windows.Controls.TextBlock]$Lbl) {
    if ($null -eq $Bdr) { return }
    try {
        if ($null -ne $script:SelectedBorderBtn -and $script:SelectedBorderBtn -ne $Bdr) {
            $script:SelectedBorderBtn.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
            $script:SelectedBorderBtn.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            if ($null -ne $script:SelectedBorderLbl) {
                $script:SelectedBorderLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
            }
        }
        $script:SelectedBorderBtn = $Bdr
        $script:SelectedBorderLbl = $Lbl
        $Bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnSelectedBg')
        $Bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
        if ($null -ne $Lbl) {
            $Lbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
        }
    } catch {}
}

function Set-SLTTheme([ValidateSet('EmeraldDark','MidnightDark','OceanCalmDark','CarbonGoldDark','ArcticBlueLight','SnowWhiteLight','WarmSandLight','SoftSageLight')][string]$ThemeName) {
    if(-not $script:Themes.PSObject.Properties[$ThemeName]){$ThemeName='EmeraldDark'}
    $t=$script:Themes.$ThemeName
    $script:CurrentTheme=$ThemeName
    foreach($key in @('WindowBg','SidebarBg','SidebarBorder','Panel','PanelBorder','CardSurface','CardDeep','CardBorder','InputBg','InputBorder','FooterBg','LogBg','LogFg','TextPrimary','TextSecondary','TextAccent','BtnBg','BtnText','BtnBorder','BtnHoverBg','BtnHoverText','BtnSelectedBg','BtnSelectedText','NavIdle','NavActive','NavText','NavActiveText','NavHover','NavHoverText','ActionPrimary','ActionSecondary','ActionHover','ActionText','ActionBorder')) {
        if($t.PSObject.Properties[$key]) {
            $script:Window.Resources[$key] = ([Windows.Media.BrushConverter]::new().ConvertFromString([string]$t.$key))
        }
    }
    foreach($rKey in @('BtnRadius','NavRadius','CardRadius')) {
        if($t.PSObject.Properties[$rKey]) {
            $script:Window.Resources[$rKey] = [Windows.CornerRadius]::new([double]$t.$rKey)
        }
    }
    if($t.PSObject.Properties['BtnBorderWidth']) {
        $script:Window.Resources['BtnBorderThickness'] = [Windows.Thickness]::new([double]$t.BtnBorderWidth)
    }
    foreach($fKey in @('BtnFontSize','NavFontSize','TitleFontSize','BodyFontSize')) {
        if($t.PSObject.Properties[$fKey]) {
            $script:Window.Resources[$fKey] = [double]$t.$fKey
        }
    }
    foreach($sr in @(@('SLTStatusOk','StatusOk'),@('SLTStatusWarn','StatusWarn'),@('SLTStatusError','StatusError'),@('SLTStatusInfo','StatusInfo'))) {
        if($t.PSObject.Properties[$sr[1]]) {
            $script:Window.Resources[$sr[0]] = ([Windows.Media.BrushConverter]::new().ConvertFromString([string]$t.($sr[1])))
        }
    }
    try {
        $rgStop = $script:Window.FindName('RadialGlowStop')
        $rgEnd  = $script:Window.FindName('RadialGlowEnd')
        if ($null -ne $rgStop -and $t.PSObject.Properties['RadialGlow']) {
            $cGlow = [Windows.Media.ColorConverter]::ConvertFromString([string]$t.RadialGlow)
            $glowAlpha = if ([bool]$t.IsLight) { [byte]136 } else { [byte]204 }
            $rgStop.Color = [Windows.Media.Color]::FromArgb($glowAlpha, $cGlow.R, $cGlow.G, $cGlow.B)
        }
        if ($null -ne $rgEnd -and $t.PSObject.Properties['WindowBg']) {
            $cBg = [Windows.Media.ColorConverter]::ConvertFromString([string]$t.WindowBg)
            $rgEnd.Color = [Windows.Media.Color]::FromArgb(0, $cBg.R, $cBg.G, $cBg.B)
        }
        $s1=$script:Window.FindName('HeaderStop1');if($null -ne $s1){$s1.Color=[Windows.Media.ColorConverter]::ConvertFromString([string]$t.HeaderGrad1)}
        $s2=$script:Window.FindName('HeaderStop2');if($null -ne $s2){$s2.Color=[Windows.Media.ColorConverter]::ConvertFromString([string]$t.HeaderGrad2)}
        $s3=$script:Window.FindName('HeaderStop3');if($null -ne $s3){$s3.Color=[Windows.Media.ColorConverter]::ConvertFromString([string]$t.HeaderGrad3)}
    } catch {}
    if($script:NavButtons -and $script:NavButtons.Count -gt 0) {
        for($k=0;$k -lt $script:NavButtons.Count;$k++){
            if($k -eq $script:CurrentPageIndex){
                $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
                $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
                if($k -lt $script:SLTNavLabels.Count){
                    $script:SLTNavLabels[$k].SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
                    $script:SLTNavIcons[$k].Tag.Stroke=(New-SLTBrush ([string]$t.BtnSelectedText))
                    $script:SLTNavChevrons[$k].Visibility='Visible'
                    $script:SLTNavChevrons[$k].Tag.Stroke=(New-SLTBrush ([string]$t.BtnSelectedText))
                }
            } else {
                $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnBg')
                $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnBorder')
                if($k -lt $script:SLTNavLabels.Count){
                    $script:SLTNavLabels[$k].SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
                    $script:SLTNavIcons[$k].Tag.Stroke=(New-SLTBrush ([string]$t.BtnText))
                    $script:SLTNavChevrons[$k].Visibility='Collapsed'
                }
            }
        }
    }
    try {
        $prefFile=Join-Path $script:StateDir 'UnifiedThemePref_v55.json'
        @{theme=$ThemeName;updated=(Get-Date -Format s)}|ConvertTo-Json|Set-Content -LiteralPath $prefFile -Encoding UTF8
    } catch {}
    if($script:CatalogInitialized -and (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue)){try{Render-SLTAppCatalog}catch{}}
    if(Get-Command Update-SLTBoostThemeVisuals -ErrorAction SilentlyContinue){try{Update-SLTBoostThemeVisuals}catch{}}
    if(Get-Command Switch-SLTHWTab -ErrorAction SilentlyContinue){try{if($script:HWCurrentSubTab){Switch-SLTHWTab $script:HWCurrentSubTab}}catch{}}
    if(Get-Command Update-SLTHubThemeVisuals -ErrorAction SilentlyContinue){try{Update-SLTHubThemeVisuals}catch{}}
    if(Get-Command Update-SLTBRVisuals -ErrorAction SilentlyContinue){try{Update-SLTBRVisuals}catch{}}
    if(Get-Command Invoke-SLTDashboardLiveRefresh -ErrorAction SilentlyContinue){try{Invoke-SLTDashboardLiveRefresh -FastStartup}catch{}}
    if(Get-Command Sync-SLTSupportPageVisuals -ErrorAction SilentlyContinue){try{Sync-SLTSupportPageVisuals}catch{}}
    if(Get-Command Update-SLTBusySpinnerTheme -ErrorAction SilentlyContinue){try{Update-SLTBusySpinnerTheme}catch{}}
    try {
        $subEl = $script:Window.FindName('SidebarThemeSubText')
        if ($null -ne $subEl) {
            $modeTag = if ([bool]$t.IsLight) { 'Light Eye-Care' } else { 'Dark Eye-Care' }
            $subEl.Text = ('v1.0.0 . ' + $modeTag + ' . Smart Life Teck')
        }
    } catch {}
    try {
        if ($null -ne $script:ThemeSelector -and $script:ThemeKeys -contains $ThemeName) {
            $ti = [array]::IndexOf($script:ThemeKeys, $ThemeName)
            if ($script:ThemeSelector.SelectedIndex -ne $ti) { $script:ThemeSelector.SelectedIndex = $ti }
            if ($null -ne $script:SupportThemeCombo -and $script:SupportThemeCombo.SelectedIndex -ne $ti) { $script:SupportThemeCombo.SelectedIndex = $ti }
        }
    } catch {}
    Log-SLT ('Applied UI Theme: '+[string]$t.label+' | Smart Life Teck | Developed by Shahzad Babar')
}

function New-SLTText([string]$Content,[double]$Size=13,[bool]$Bold=$false,[string]$Color='#C3D7E8') {
    $c=New-Object Windows.Controls.TextBlock
    $c.Text=$Content;$c.FontSize=$Size;$c.TextWrapping='Wrap'
    $c.Margin=[Windows.Thickness]::new(2,3,2,3)
    if($Size -le 13.5 -and -not $Bold) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty,'BodyFontSize')
    }
    if($Color -in @('#F2FAFF','#E4F4FF','#D8F0FF','#E2F2FF','#ECF6FF','#EAF5FF','#FFFFFF','#F0FAFF','#E2E8F0','#F8FAFC','#ECFEFF','#F4EAD7','#F7EFE0','#F1F5F9','#EDF7FA','#F0F7FF','#F5F5F4','#F4F3EF','#0F172A','#0D1F1D','#1C1917','#0C241A','#0F291E')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextPrimary')
    } elseif($Color -in @('#9DC6E1','#C3D7E8','#8DC9EA','#A6D6F1','#94B7D4','#BFD6EA','#87C5EA','#96CDEB','#86BDDF','#94B8D7','#D5E8F9','#C8E1F5','#C5DCF0','#8AB4D8','#7FA6C9','#A1C6DF','#A2C9DE','#B0DEF4','#84B2CB','#7FA0BE','#CBD5E1','#94A3B8','#AEC9BD','#BFE0D2','#B0C0D4','#A8C5DA','#B4D2E3','#B8B5AD','#C7C3B8','#334155','#475569','#4B5563','#2D4744','#44403C','#57534E','#2C4C3E','#3F6252')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    } elseif($Color -in @('#2FC9F0','#49D8FC','#50DBFF','#39BFEB','#38BDF8','#56D9FF','#42C9EE','#7ABEEA','#60A5FA','#93C5FD','#9ACCEC','#A78BFA','#F472B6','#22D3EE','#E4C158','#ECC95A','#4FD1C5','#2DD4BF','#C9A227','#D4AF37','#DFBD46','#0369A1','#0284C7','#0F766E','#0D6B63','#0D655E','#065F46')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextAccent')
    } elseif($Color -in @('#10B981','#34D399','#A6EAC8','#059669','#6EE7B7','#4ADE80','#047857','#0E8F5B')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'SLTStatusOk')
    } elseif($Color -in @('#EF4444','#DC2626','#F87171','#FCA5A5','#F48771','#B91C1C','#B85E44')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'SLTStatusError')
    } elseif($Color -in @('#F59E0B','#D97706','#FDE68A','#FBBF24','#FACC15','#D7BA7D','#92400E')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'SLTStatusWarn')
    } elseif($Color -in @('#E0B98C','#EFB687','#E9B187','#E4C399')) {
        $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'TextSecondary')
    } else {
        $c.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    }
    if($Bold){$c.FontWeight='Bold'}
    return $c
}

function New-SLTPanel([string]$Title,[string]$Summary='') {
    $b=New-Object Windows.Controls.Border
    $b.Style=$script:Window.FindResource('Card')
    $b.Effect = New-SLTCabinShadow 16 3 0.05
    $stack=New-Object Windows.Controls.StackPanel
    $b.Child=$stack
    $hdr = New-SLTText $Title 17 $true '#F2FAFF'
    $hdr.FontFamily = 'Georgia'
    $stack.Children.Add($hdr)|Out-Null
    if($Summary){$stack.Children.Add((New-SLTText $Summary 12 $false '#9DC6E1'))|Out-Null}
    return $b
}

function Add-SLTAction([string]$Id,[string]$Label,[string]$Description,[string]$Impact,[scriptblock]$Handler,[bool]$Developer=$false,[bool]$Sensitive=$false,[string]$Color='#1477D4') {
    $visible=$true
    if($script:ActionOverrides.ContainsKey($Id)) {
        $override=$script:ActionOverrides[$Id]
        $Label=Get-SLTOptionalText $override 'label' $Label
        $Description=Get-SLTOptionalText $override 'description' $Description
        $Impact=Get-SLTOptionalText $override 'impact' $Impact
        if($null -ne $override.PSObject.Properties['visible']) { $visible=([bool]$override.visible) }
    }
    $script:Actions[$Id]=@{Label=$Label;Description=$Description;Impact=$Impact;Handler=$Handler;Developer=$Developer;Sensitive=$Sensitive}
    $btn=New-Object Windows.Controls.Button
    if(-not $visible){$btn.Visibility='Collapsed'}
    $btn.Content=$Label;$btn.Tag=$Id;$btn.Style=$script:Window.FindResource('ActionButton');$btn.SetResourceReference([Windows.Controls.Control]::FontSizeProperty,'BtnFontSize')
    $btn.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'BtnBg')
    $btn.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'BtnText')
    $btn.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty,'BtnBorder')
    $btn.Add_Click({param($sender,$e) Select-SLTButton $sender; Invoke-SLTAction -Id ([string]$sender.Tag)})
    $btn.Add_MouseEnter({param($sender,$e) $id=[string]$sender.Tag;if($script:Actions.ContainsKey($id)){$d=$script:Actions[$id];$script:HelpBox.Text=$d.Description+'  |  Impact: '+$d.Impact+'  |  Smart Life Teck | Developed by Shahzad Babar'}})
    return $btn
}

$script:DecisionDlg = $null
function Show-SLTDecision([string]$Label,[string]$Description,[string]$Impact,[bool]$Risky) {
    $dlg=New-Object Windows.Window
    $dlg.Title='SLT Smart PC Boost | Confirm Action';$dlg.Width=580;$dlg.Height=375
    $dlg.WindowStartupLocation='CenterOwner';$dlg.Owner=$script:Window
    $dlg.ResizeMode='NoResize'
    Apply-SLTDialogTheme $dlg
    $script:DecisionDlg = $dlg
    $s=New-Object Windows.Controls.StackPanel;$s.Margin=[Windows.Thickness]::new(22)
    $card=New-Object Windows.Controls.Border
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'CardSurface')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'CardBorder')
    $card.BorderThickness=[Windows.Thickness]::new(1.5)
    $card.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty,'CardRadius')
    $card.Padding=[Windows.Thickness]::new(18,14,18,14)
    $cs=New-Object Windows.Controls.StackPanel
    $head=New-SLTText $Label 20 $true '#50DBFF';$cs.Children.Add($head)|Out-Null
    $cs.Children.Add((New-SLTText 'ACTION DESCRIPTION' 11 $true '#7ABEEA'))|Out-Null
    $cs.Children.Add((New-SLTText $Description 13.5 $false '#ECF6FF'))|Out-Null
    $cs.Children.Add((New-SLTText 'POTENTIAL IMPACT / WARNINGS' 11 $true $(if($Risky){'#D97706'}else{'#10B981'})))|Out-Null
    $cs.Children.Add((New-SLTText $Impact 13 $false '#D5E8F9'))|Out-Null
    $cs.Children.Add((New-SLTText 'Developed by Shahzad Babar  |  Smart Life Teck (www.smartlifeteck.com)' 11 $false '#84B2CB'))|Out-Null
    $card.Child=$cs
    $s.Children.Add($card)|Out-Null
    $buttons=New-Object Windows.Controls.StackPanel;$buttons.Orientation='Horizontal';$buttons.HorizontalAlignment='Right';$buttons.Margin=[Windows.Thickness]::new(0,14,0,0)
    $no=New-Object Windows.Controls.Button;$no.Content='No | Cancel';$no.Style=$script:Window.FindResource('ActionButton');$no.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'ActionSecondary');$no.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary');$no.MinWidth=120
    $yes=New-Object Windows.Controls.Button;$yes.Content='Yes | Continue';$yes.Style=$script:Window.FindResource('ActionButton');$yes.MinWidth=135
    if($Risky){$yes.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#B45309');$yes.Foreground=[Windows.Media.Brushes]::White}
    else{$yes.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'ActionPrimary');$yes.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'ActionText')}
    $no.Add_Click({if($script:DecisionDlg){$script:DecisionDlg.DialogResult=$false;$script:DecisionDlg.Close()}})
    $yes.Add_Click({if($script:DecisionDlg){$script:DecisionDlg.DialogResult=$true;$script:DecisionDlg.Close()}})
    $buttons.Children.Add($no)|Out-Null;$buttons.Children.Add($yes)|Out-Null;$s.Children.Add($buttons)|Out-Null
    $dlg.Content=$s
    $res = ($dlg.ShowDialog() -eq $true)
    $script:DecisionDlg = $null
    return $res
}

function Invoke-SLTAction([string]$Id) {
    if(-not $script:Actions.ContainsKey($Id)){return}
    $a=$script:Actions[$Id]
    $script:HelpBox.Text=$a.Description+'  |  Impact: '+$a.Impact+'  |  Smart Life Teck | Developed by Shahzad Babar'
    if($a.Developer) {
       if(-not(Show-SLTDecision $a.Label $a.Description $a.Impact ([bool]$a.Sensitive))){Log-SLT ('Cancelled: '+$a.Label);return}
    }
    try {
       & $a.Handler
       Log-SLT ('Action requested: '+$a.Label)
    } catch {
       $m=$_.Exception.Message;Log-SLT ('ERROR '+$Id+': '+$m)
       [Windows.MessageBox]::Show($m,'Smart Life Teck - Action Failed','OK','Error')|Out-Null
    }
}

function New-SLTActionRow([object[]]$Actions) {
    $w=New-Object Windows.Controls.WrapPanel
    $w.Margin='0,9,0,8'
    foreach($a in $Actions){$w.Children.Add((Add-SLTAction @a))|Out-Null}
    return $w
}

function New-SLTPage([int]$Index) {
    $container=New-Object Windows.Controls.StackPanel;$container.Margin=[Windows.Thickness]::new(0,0,4,2)
    if ($Index -eq 3) {
        $hdrStack = New-Object Windows.Controls.StackPanel
        $hdrStack.Margin = [Windows.Thickness]::new(6,2,6,18)
        $h1 = New-Object Windows.Controls.TextBlock
        $h1.Text = ($script:PageNames[$Index]).ToUpper()
        $h1.FontSize = 26; $h1.FontWeight = 'Bold'
        $h1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $sub = New-Object Windows.Controls.TextBlock
        $sub.Text = $script:PageDescriptions[$Index]
        $sub.FontSize = 13; $sub.Margin = [Windows.Thickness]::new(0,4,0,0)
        $sub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $hdrStack.Children.Add($h1)|Out-Null; $hdrStack.Children.Add($sub)|Out-Null
        $container.Children.Add($hdrStack)|Out-Null
    }
    $script:Pages[$Index]=$container
    return $container
}

function Add-SLTPanel([Windows.Controls.StackPanel]$Page,[Windows.Controls.Border]$Panel){$Page.Children.Add($Panel)|Out-Null}
function Add-SLTNote([Windows.Controls.Panel]$Panel,[string]$Text,[string]$Color='#94B7D4') {$Panel.Children.Add((New-SLTText $Text 12 $false $Color))|Out-Null}

function New-SLTDevGradient {
    $g = New-Object Windows.Media.LinearGradientBrush
    $g.StartPoint = New-Object Windows.Point(0,0)
    $g.EndPoint = New-Object Windows.Point(1,0)
    $g.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString('#3306B6D4'),0)))
    $g.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString('#332563EB'),1)))
    return $g
}

function Switch-SLTPage([int]$Index) {
    $script:CurrentPageIndex=$Index
    $t=$script:Themes.($script:CurrentTheme)
    $selBrush  = New-SLTBrush ([string]$t.BtnSelectedText)
    $idleBrush = New-SLTBrush ([string]$t.BtnText)
    for($k=0;$k -lt $script:NavButtons.Count;$k++){
       if($k -eq $Index){
          $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
          $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
          if($k -lt $script:SLTNavLabels.Count){
             $script:SLTNavLabels[$k].SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnSelectedText')
             $script:SLTNavIcons[$k].Tag.Stroke = $selBrush
             $script:SLTNavChevrons[$k].Visibility = 'Visible'
             $script:SLTNavChevrons[$k].Tag.Stroke = $selBrush
          }
       } else {
          $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnBg')
          $script:NavButtons[$k].SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnBorder')
          if($k -lt $script:SLTNavLabels.Count){
             $script:SLTNavLabels[$k].SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
             $script:SLTNavIcons[$k].Tag.Stroke = $idleBrush
             $script:SLTNavChevrons[$k].Visibility = 'Collapsed'
          }
       }
    }
    try {
        if ($Index -ne 6 -and $script:SysProtSelected) {
            $script:SysProtSelected = $false
            $sysCard = $script:Window.FindName('SystemProtectedCard')
            $sysTitle = $script:Window.FindName('SysProtTitle')
            if ($null -ne $sysCard) {
                $sysCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
                $sysCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
                if ([object]::ReferenceEquals($script:SelectedBorderBtn, $sysCard)) {
                    $script:SelectedBorderBtn = $null
                    $script:SelectedBorderLbl = $null
                }
            }
            if ($null -ne $sysTitle) {
                $sysTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
            }
        }
    } catch {}
    try {
        $wsScroller = $script:Window.FindName('WorkspaceScroller')
        if ($null -ne $wsScroller) {
            if ($Index -in @(2,4)) {
                $wsScroller.Padding = [Windows.Thickness]::new(0)
            } else {
                $wsScroller.Padding = [Windows.Thickness]::new(28,22,28,22)
            }
            $wsScroller.ScrollToTop()
        }
        $script:HostControl.MaxWidth = $(if ($Index -in @(2,4)) { [double]::PositiveInfinity } else { 1240 })
    } catch {}
    $script:TitleBlock.Text=$script:PageNames[$Index]
    $script:SubtitleBlock.Text=$script:PageDescriptions[$Index]
    $script:HelpBox.Text='Select an action. Description, possible impact and restore information appear here. Powered by Smart Life Teck | Developed by Shahzad Babar.'
    if ([object]::ReferenceEquals($script:HostControl.Content, $script:Pages[$Index]) -and $script:CurrentPageRenderedOnce) {
        return
    }
    $script:CurrentPageRenderedOnce = $true
    $script:HostControl.Content=$script:Pages[$Index]
    if($Index -eq 3 -and (-not $script:TweaksRenderedOnce)) {
        $script:TweaksRenderedOnce = $true
        try {
            $script:Window.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, [action]{ try { Render-SLTTweaks } catch {} }) | Out-Null
        } catch {}
    }
}

# Navigation order is fixed as requested. Left rail persists on all pages.
$script:NavButtons=New-Object System.Collections.ArrayList
$nav=$script:Window.FindName('NavPanel')
$navSpecs=@(
  @{Label='Dashboard';                 Icon='LayoutDashboard'},
  @{Label='Smart Install & Uninstall'; Icon='Download'},
  @{Label='Smart Tools Hub';           Icon='Sparkles'},
  @{Label='Boost Your PC';             Icon='Rocket'},
  @{Label='Backup & Restore';          Icon='HardDrive'},
  @{Label='Smart Hardware Inspection'; Icon='Cpu'},
  @{Label='Support & Contact';         Icon='MessageCircle'}
)
for($i=0;$i -lt 7;$i++) {
    $script:Pages[$i]=(New-Object Windows.Controls.StackPanel)
    $b=New-Object Windows.Controls.Button
    $b.Tag=$i;$b.Style=$script:Window.FindResource('NavButton')

    $rowGrid = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = [Windows.GridLength]::Auto
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = [Windows.GridLength]::Auto
    $rowGrid.ColumnDefinitions.Add($c0)|Out-Null; $rowGrid.ColumnDefinitions.Add($c1)|Out-Null; $rowGrid.ColumnDefinitions.Add($c2)|Out-Null

    $ic = New-SLTLucideIcon $navSpecs[$i].Icon 16 '#475569'
    $ic.Margin = [Windows.Thickness]::new(0,0,10,0); $ic.VerticalAlignment = 'Center'
    $ic.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $lbl = New-Object Windows.Controls.TextBlock
    $lbl.Text = $navSpecs[$i].Label; $lbl.FontSize = 13; $lbl.FontWeight = 'Medium'; $lbl.VerticalAlignment = 'Center'
    $lbl.Foreground = (New-SLTBrush '#475569')
    $lbl.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

    $chev = New-SLTLucideIcon 'ChevronRight' 15 '#FFFFFF'
    $chev.VerticalAlignment = 'Center'; $chev.Visibility = 'Collapsed'
    $chev.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)

    $rowGrid.Children.Add($ic)|Out-Null; $rowGrid.Children.Add($lbl)|Out-Null; $rowGrid.Children.Add($chev)|Out-Null
    $b.Content = $rowGrid

    $script:SLTNavIcons += $ic
    $script:SLTNavLabels += $lbl
    $script:SLTNavChevrons += $chev

    if($i -in @(1,5)) {
        $lbl.FontSize = 12.1
    }
    # Index 4 is now SLT Backup & Restore Factory (visible in sidebar)
    if($i -eq 5) {
        $b.Add_Click({param($sender,$e) if($script:DevUnlockedSession -or (Test-SLTHardwareAccess)){$script:DevUnlockedSession=$true;Switch-SLTPage 5} })
    } else {
        $b.Add_Click({param($sender,$e) Switch-SLTPage ([int]$sender.Tag)})
    }
    $nav.Children.Add($b)|Out-Null;$null=$script:NavButtons.Add($b)
}

# Enable Smooth Two-Finger Touchpad & MouseWheel Scrolling on WorkspaceScroller
try {
    $wsScroller = $script:Window.FindName('WorkspaceScroller')
    if ($null -ne $wsScroller) {
        $wsScroller.Add_PreviewMouseWheel({
            param($sender, $e)
            try {
                if ($e.Delta -ne 0) {
                    $newOffset = $sender.VerticalOffset - ([double]$e.Delta * 0.85)
                    if ($newOffset -lt 0) { $newOffset = 0 }
                    if ($newOffset -gt $sender.ScrollableHeight) { $newOffset = $sender.ScrollableHeight }
                    $sender.ScrollToVerticalOffset($newOffset)
                    $e.Handled = $true
                }
            } catch {}
        })
    }
} catch {}

# Wire SystemProtectedCard in Sidebar Footer as a normal .slt-btn (hover lift -2px, only highlights when clicked)
try {
    $sysCard = $script:Window.FindName('SystemProtectedCard')
    $sysTitle = $script:Window.FindName('SysProtTitle')
    if ($null -ne $sysCard) {
        $sysCard.Add_MouseEnter({
            param($s, $e)
            $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, -2)
            if (-not $script:SysProtSelected) {
                $s.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnHoverBg')
                $s.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            }
        })
        $sysCard.Add_MouseLeave({
            param($s, $e)
            $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)
            if (-not $script:SysProtSelected) {
                $s.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
                $s.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            }
        })
        $sysCard.Add_MouseLeftButtonUp({
            param($s, $e)
            $script:SysProtSelected = $true
            Select-SLTBorderButton $s $sysTitle
            Switch-SLTPage 6
        })
    }
} catch {}

# Populate 4 New Clean Themes in Sidebar Footer (Default = 'EmeraldDark': 1. SLT Smart Tools - Emerald Dark (Main))
$script:ThemeKeys=@('EmeraldDark','MidnightDark','OceanCalmDark','CarbonGoldDark','ArcticBlueLight','SnowWhiteLight','WarmSandLight','SoftSageLight')
foreach($tk in $script:ThemeKeys) {
    $item=New-Object Windows.Controls.ComboBoxItem
    $item.Content=[string]$script:Themes.$tk.label
    $item.Tag=$tk
    $item.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardSurface')
    $item.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary')
    $script:ThemeSelector.Items.Add($item)|Out-Null
}
$savedTheme='EmeraldDark'
$prefPath=Join-Path $script:StateDir 'UnifiedThemePref_v55.json'
if(Test-Path -LiteralPath $prefPath){
    try{$savedObj=Get-Content -LiteralPath $prefPath -Raw|ConvertFrom-Json;if($savedObj.theme -in $script:ThemeKeys){$savedTheme=[string]$savedObj.theme}}catch{}
}
$script:ThemeSelector.SelectedIndex=[array]::IndexOf($script:ThemeKeys,$savedTheme)
Set-SLTTheme $savedTheme
$script:ThemeSelector.Add_SelectionChanged({
    $sel=$script:ThemeSelector.SelectedItem
    if($null -ne $sel -and $null -ne $sel.Tag){
        $tn = [string]$sel.Tag
        Set-SLTTheme $tn
        try { @{theme=$tn} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:StateDir 'UnifiedThemePref_v55.json') -Encoding UTF8 } catch {}
    }
})


# ==============================================================================
# LIVE ROTATING NEEDLE / GAUGE BUSY SPINNER OVERLAY (Zero Perceived Freeze)
# ==============================================================================
function Initialize-SLTBusySpinnerOverlay {
    try {
        if ($null -eq $script:Window -or $null -ne $script:BusyOverlayHost) { return }
        $wsGrid = $script:Window.FindName('WorkspaceGrid')
        if ($null -eq $wsGrid) { return }

        $conv = [Windows.Media.BrushConverter]::new()
        $overlay = New-Object Windows.Controls.Grid
        $overlay.Background = $conv.ConvertFromString('#6605130F')
        $overlay.HorizontalAlignment = 'Stretch'
        $overlay.VerticalAlignment = 'Stretch'
        $overlay.Visibility = 'Collapsed'
        [Windows.Controls.Panel]::SetZIndex($overlay, 9999)

        $card = New-Object Windows.Controls.Border
        $card.Width = 370
        $card.CornerRadius = [Windows.CornerRadius]::new(18)
        $card.Padding = [Windows.Thickness]::new(24, 20, 24, 20)
        $card.HorizontalAlignment = 'Center'
        $card.VerticalAlignment = 'Center'
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
        $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
        $card.BorderThickness = [Windows.Thickness]::new(1.8)

        $stack = New-Object Windows.Controls.StackPanel
        $stack.HorizontalAlignment = 'Center'

        # 64x64 Circular Speedometer / Gauge Dial with Rotating Needle
        $dialCanvas = New-Object Windows.Controls.Canvas
        $dialCanvas.Width = 64
        $dialCanvas.Height = 64
        $dialCanvas.HorizontalAlignment = 'Center'
        $dialCanvas.Margin = [Windows.Thickness]::new(0, 0, 0, 12)

        $outerRing = New-Object Windows.Shapes.Ellipse
        $outerRing.Width = 64; $outerRing.Height = 64
        $outerRing.Stroke = $conv.ConvertFromString('#D4AF37')
        $outerRing.StrokeThickness = 3
        $outerRing.Fill = $conv.ConvertFromString('#0F3429')
        $script:BusyOuterRing = $outerRing
        $dialCanvas.Children.Add($outerRing)|Out-Null

        $tickRing = New-Object Windows.Shapes.Ellipse
        $tickRing.Width = 52; $tickRing.Height = 52
        [Windows.Controls.Canvas]::SetLeft($tickRing, 6)
        [Windows.Controls.Canvas]::SetTop($tickRing, 6)
        $tickRing.Stroke = $conv.ConvertFromString('#ECC95A')
        $tickRing.StrokeThickness = 1.5
        $tickRing.StrokeDashArray = [Windows.Media.DoubleCollection]::new(@(2.0, 3.0))
        $script:BusyTickRing = $tickRing
        $dialCanvas.Children.Add($tickRing)|Out-Null

        # Rotating Needle Group (64x64 Canvas rotated around center 32,32)
        $needleCanvas = New-Object Windows.Controls.Canvas
        $needleCanvas.Width = 64; $needleCanvas.Height = 64
        $needleCanvas.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
        $rot = New-Object Windows.Media.RotateTransform(0)
        $needleCanvas.RenderTransform = $rot
        $script:BusyNeedleRotate = $rot

        $needleLine = New-Object Windows.Shapes.Line
        $needleLine.X1 = 32; $needleLine.Y1 = 32
        $needleLine.X2 = 32; $needleLine.Y2 = 9
        $needleLine.Stroke = $conv.ConvertFromString('#34D399')
        $needleLine.StrokeThickness = 3.2
        $needleLine.StrokeStartLineCap = 'Round'
        $needleLine.StrokeEndLineCap = 'Round'
        $script:BusyNeedleLine = $needleLine
        $needleCanvas.Children.Add($needleLine)|Out-Null

        $needleTip = New-Object Windows.Shapes.Ellipse
        $needleTip.Width = 8; $needleTip.Height = 8
        [Windows.Controls.Canvas]::SetLeft($needleTip, 28)
        [Windows.Controls.Canvas]::SetTop($needleTip, 5)
        $needleTip.Fill = $conv.ConvertFromString('#ECC95A')
        $script:BusyNeedleTip = $needleTip
        $needleCanvas.Children.Add($needleTip)|Out-Null

        $dialCanvas.Children.Add($needleCanvas)|Out-Null

        $centerCap = New-Object Windows.Shapes.Ellipse
        $centerCap.Width = 12; $centerCap.Height = 12
        [Windows.Controls.Canvas]::SetLeft($centerCap, 26)
        [Windows.Controls.Canvas]::SetTop($centerCap, 26)
        $centerCap.Fill = $conv.ConvertFromString('#D4AF37')
        $centerCap.Stroke = $conv.ConvertFromString('#F7EFE0')
        $centerCap.StrokeThickness = 2
        $script:BusyCenterCap = $centerCap
        $dialCanvas.Children.Add($centerCap)|Out-Null

        $stack.Children.Add($dialCanvas)|Out-Null

        $titleTb = New-Object Windows.Controls.TextBlock
        $titleTb.Text = 'Processing... Please Wait'
        $titleTb.FontSize = 14
        $titleTb.FontWeight = 'Bold'
        $titleTb.HorizontalAlignment = 'Center'
        $titleTb.TextAlignment = 'Center'
        $titleTb.TextWrapping = 'Wrap'
        $titleTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $script:BusyOverlayTitle = $titleTb
        $stack.Children.Add($titleTb)|Out-Null

        $subTb = New-Object Windows.Controls.TextBlock
        $subTb.Text = 'Smart Life Teck Engine is working...'
        $subTb.FontSize = 11.2
        $subTb.FontWeight = 'SemiBold'
        $subTb.HorizontalAlignment = 'Center'
        $subTb.TextAlignment = 'Center'
        $subTb.TextWrapping = 'Wrap'
        $subTb.Margin = [Windows.Thickness]::new(0, 5, 0, 0)
        $subTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        $script:BusyOverlaySub = $subTb
        $stack.Children.Add($subTb)|Out-Null

        $card.Child = $stack
        $overlay.Children.Add($card)|Out-Null
        $wsGrid.Children.Add($overlay)|Out-Null
        $script:BusyOverlayHost = $overlay

        $timer = New-Object Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(30)
        $timer.Add_Tick({
            try {
                if ($null -ne $script:BusyNeedleRotate) {
                    $script:BusyNeedleRotate.Angle = ($script:BusyNeedleRotate.Angle + 24) % 360
                }
            } catch {}
        })
        $script:BusySpinnerTimer = $timer
    } catch {}
}

function Pump-SLTBusySpinnerFrame {
    try {
        if ($null -ne $script:Window -and $null -ne $script:Window.Dispatcher) {
            $script:Window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    } catch {}
}

function Show-SLTBusySpinner([string]$Title='Scanning... Please Wait', [string]$Sub='Smart Life Teck Engine is working...') {
    try {
        if ($null -eq $script:BusyOverlayHost) { Initialize-SLTBusySpinnerOverlay }
        if ($null -ne $script:BusyOverlayTitle) { $script:BusyOverlayTitle.Text = $Title }
        if ($null -ne $script:BusyOverlaySub)   { $script:BusyOverlaySub.Text   = $Sub }
        if ($null -ne $script:BusyNeedleRotate) { $script:BusyNeedleRotate.Angle = ($script:BusyNeedleRotate.Angle + 30) % 360 }
        if ($null -ne $script:BusyOverlayHost)  { $script:BusyOverlayHost.Visibility = 'Visible' }
        if ($null -ne $script:BusySpinnerTimer) { $script:BusySpinnerTimer.Start() }
        if ($null -ne $script:Window) { $script:Window.Cursor = [Windows.Input.Cursors]::Wait }
        Pump-SLTBusySpinnerFrame
    } catch {}
}

function Step-SLTBusySpinner([string]$Title='', [string]$Sub='') {
    try {
        if (-not [string]::IsNullOrWhiteSpace($Title) -and $null -ne $script:BusyOverlayTitle) {
            $script:BusyOverlayTitle.Text = $Title
        }
        if (-not [string]::IsNullOrWhiteSpace($Sub) -and $null -ne $script:BusyOverlaySub) {
            $script:BusyOverlaySub.Text = $Sub
        }
        if ($null -ne $script:BusyNeedleRotate) {
            $script:BusyNeedleRotate.Angle = ($script:BusyNeedleRotate.Angle + 42) % 360
        }
        Pump-SLTBusySpinnerFrame
    } catch {}
}

function Hide-SLTBusySpinner {
    try {
        if ($null -ne $script:BusySpinnerTimer) { $script:BusySpinnerTimer.Stop() }
        if ($null -ne $script:BusyOverlayHost)  { $script:BusyOverlayHost.Visibility = 'Collapsed' }
        if ($null -ne $script:Window) { $script:Window.Cursor = [Windows.Input.Cursors]::Arrow }
        Pump-SLTBusySpinnerFrame
    } catch {}
}

function Update-SLTBusySpinnerTheme {
    try {
        if ($null -eq $script:Themes -or -not $script:Themes.PSObject.Properties[$script:CurrentTheme]) { return }
        $t = $script:Themes.($script:CurrentTheme)
        if ($null -ne $script:BusyOverlayHost) {
            $script:BusyOverlayHost.Background = (New-SLTBrush $(if ([bool]$t.IsLight) { '#550F172A' } else { '#77050D0A' }))
        }
        if ($null -ne $script:BusyOuterRing) {
            $script:BusyOuterRing.Stroke = (New-SLTBrush ([string]$t.BtnSelectedBg))
            $script:BusyOuterRing.Fill   = (New-SLTBrush ([string]$t.CardDeep))
        }
        if ($null -ne $script:BusyTickRing) {
            $script:BusyTickRing.Stroke = (New-SLTBrush ([string]$t.TextAccent))
        }
        if ($null -ne $script:BusyNeedleLine) {
            $script:BusyNeedleLine.Stroke = (New-SLTBrush ([string]$t.StatusOk))
        }
        if ($null -ne $script:BusyNeedleTip) {
            $script:BusyNeedleTip.Fill = (New-SLTBrush ([string]$t.TextAccent))
        }
        if ($null -ne $script:BusyCenterCap) {
            $script:BusyCenterCap.Fill   = (New-SLTBrush ([string]$t.BtnSelectedBg))
            $script:BusyCenterCap.Stroke = (New-SLTBrush ([string]$t.TextPrimary))
        }
    } catch {}
}

Set-Item -Path Function:\global:Set-SLTTheme -Value ${function:Set-SLTTheme}
Set-Item -Path Function:\global:Test-SLTLightTheme -Value ${function:Test-SLTLightTheme}
Set-Item -Path Function:\global:Switch-SLTPage -Value ${function:Switch-SLTPage}
Set-Item -Path Function:\global:Initialize-SLTBusySpinnerOverlay -Value ${function:Initialize-SLTBusySpinnerOverlay}
Set-Item -Path Function:\global:Update-SLTBusySpinnerTheme -Value ${function:Update-SLTBusySpinnerTheme}
Set-Item -Path Function:\global:Show-SLTBusySpinner -Value ${function:Show-SLTBusySpinner}
Set-Item -Path Function:\global:Step-SLTBusySpinner -Value ${function:Step-SLTBusySpinner}
Set-Item -Path Function:\global:Hide-SLTBusySpinner -Value ${function:Hide-SLTBusySpinner}
Initialize-SLTBusySpinnerOverlay
Update-SLTBusySpinnerTheme
