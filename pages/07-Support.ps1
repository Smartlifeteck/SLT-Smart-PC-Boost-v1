# ==============================================================================
# pages/07-Support.ps1 (Index 6)
# SLT Smart PC Boost v1.0.0 - Support & Contact Option 1 (Simple + Social)
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# ==============================================================================
$page = New-SLTPage 6
$emDash = [char]0x2014
$bullet = [char]0x2022
$arrSym = [char]0x2192
$chkSym = [char]0x2713
$script:SuppressSupportThemeEvent = $false

# Load brand.json dynamically with safe defaults
$brandWa  = '+966 553760854'
$brandWaUrl = 'https://wa.me/966553760854'
$brandWeb = 'www.smartlifeteck.com'
$brandWebUrl = 'https://www.smartlifeteck.com'
$brandMail = 'info@smartlifeteck.com'
$brandHarajUrl = 'https://haraj.com.sa/users/smartlifeteck.ksa'
try {
    $brandFile = Join-Path $script:Root 'config\brand.json'
    if (Test-Path -LiteralPath $brandFile) {
        $bObj = Get-Content -LiteralPath $brandFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        if ($null -ne $bObj) {
            if ($bObj.PSObject.Properties['WhatsApp'] -and $bObj.WhatsApp) { $brandWa = [string]$bObj.WhatsApp }
            if ($bObj.PSObject.Properties['WhatsAppUrl'] -and $bObj.WhatsAppUrl) { $brandWaUrl = [string]$bObj.WhatsAppUrl }
            if ($bObj.PSObject.Properties['Website'] -and $bObj.Website) { $brandWeb = [string]$bObj.Website }
            if ($bObj.PSObject.Properties['WebsiteUrl'] -and $bObj.WebsiteUrl) { $brandWebUrl = [string]$bObj.WebsiteUrl }
            if ($bObj.PSObject.Properties['Email'] -and $bObj.Email) { $brandMail = [string]$bObj.Email }
            if ($bObj.PSObject.Properties['HarajUrl'] -and $bObj.HarajUrl) { $brandHarajUrl = [string]$bObj.HarajUrl }
        }
    }
} catch {}

$mainStack = New-Object Windows.Controls.StackPanel
$mainStack.Margin = [Windows.Thickness]::new(6, 2, 6, 18)

# ==============================================================================
# CARD 1: OWNER CARD (Shahzad Babar - Owner, Warranty Badge & 3 Clickable Contact Pills)
# ==============================================================================
$ownerCard = New-Object Windows.Controls.Border
$ownerCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$ownerCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$ownerCard.BorderThickness = [Windows.Thickness]::new(1.2)
$ownerCard.CornerRadius = [Windows.CornerRadius]::new(16)
$ownerCard.Padding = [Windows.Thickness]::new(22, 18, 22, 18)
$ownerCard.Margin = [Windows.Thickness]::new(4, 0, 4, 14)
$ownerCard.Effect = New-SLTCabinShadow 14 2 0.06

$ownerStack = New-Object Windows.Controls.StackPanel

$topBadgesRow = New-Object Windows.Controls.WrapPanel
$topBadgesRow.Orientation = 'Horizontal'
$topBadgesRow.Margin = [Windows.Thickness]::new(0, 0, 0, 6)

$ownerTopBadge = New-Object Windows.Controls.Border
$ownerTopBadge.CornerRadius = [Windows.CornerRadius]::new(8)
$ownerTopBadge.Padding = [Windows.Thickness]::new(10, 3, 10, 3)
$ownerTopBadge.Margin = [Windows.Thickness]::new(0, 0, 8, 2)
$ownerTopBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
$ownerTopBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
$ownerTopBadge.BorderThickness = [Windows.Thickness]::new(1)
$ownerTopBadgeTxt = New-Object Windows.Controls.TextBlock
$ownerTopBadgeTxt.Text = 'SMART LIFE TECK  -  OFFICIAL SUPPORT & CONTACT'
$ownerTopBadgeTxt.FontSize = 10.5; $ownerTopBadgeTxt.FontWeight = 'Bold'
$ownerTopBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$ownerTopBadge.Child = $ownerTopBadgeTxt
$topBadgesRow.Children.Add($ownerTopBadge)|Out-Null

$warrantyBadge = New-Object Windows.Controls.Border
$warrantyBadge.CornerRadius = [Windows.CornerRadius]::new(8)
$warrantyBadge.Padding = [Windows.Thickness]::new(10, 3, 10, 3)
$warrantyBadge.Margin = [Windows.Thickness]::new(0, 0, 0, 2)
$warrantyBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
$warrantyBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
$warrantyBadge.BorderThickness = [Windows.Thickness]::new(1)
$warrantyBadgeTxt = New-Object Windows.Controls.TextBlock
$warrantyBadgeTxt.Text = "$chkSym 10-Day Check + 6-Month Service Warranty  |  Saudi Arabia"
$warrantyBadgeTxt.FontSize = 10.5; $warrantyBadgeTxt.FontWeight = 'Bold'
$warrantyBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SLTStatusOk')
$warrantyBadge.Child = $warrantyBadgeTxt
$topBadgesRow.Children.Add($warrantyBadge)|Out-Null

$ownerStack.Children.Add($topBadgesRow)|Out-Null

$ownerTitle = New-Object Windows.Controls.TextBlock
$ownerTitle.Text = 'Shahzad Babar - Owner'
$ownerTitle.FontSize = 21; $ownerTitle.FontWeight = 'Bold'
$ownerTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$ownerStack.Children.Add($ownerTitle)|Out-Null

$ownerSub = New-Object Windows.Controls.TextBlock
$ownerSub.Text = 'Laptops | Software & Online Support | Saudi Arabia, Pakistan, Worldwide'
$ownerSub.FontSize = 13; $ownerSub.TextWrapping = 'Wrap'
$ownerSub.Margin = [Windows.Thickness]::new(0, 4, 0, 14)
$ownerSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$ownerStack.Children.Add($ownerSub)|Out-Null

# 3 Clickable Contact Pills
$pillsWrap = New-Object Windows.Controls.WrapPanel
$pillsWrap.Orientation = 'Horizontal'

$contactPills = @(
    @{ Label = "WhatsApp $brandWa"; Url = $brandWaUrl; Tip = "Open WhatsApp chat with Smart Life Teck ($brandWa)" },
    @{ Label = "Website $brandWeb"; Url = $brandWebUrl; Tip = "Open official Smart Life Teck website ($brandWebUrl)" },
    @{ Label = "Email $brandMail";  Url = "mailto:$brandMail"; Tip = "Send email to $brandMail" }
)

foreach ($cp in $contactPills) {
    $pBtn = New-Object Windows.Controls.Button
    $pBtn.Content = $cp.Label
    $pBtn.Tag = [string]$cp.Url
    $pBtn.ToolTip = [string]$cp.Tip
    $pBtn.Style = $script:Window.FindResource('OutlineButton')
    $pBtn.Height = 36; $pBtn.Padding = [Windows.Thickness]::new(16, 4, 16, 4)
    $pBtn.Margin = [Windows.Thickness]::new(0, 0, 10, 6)
    $pBtn.FontSize = 12.2; $pBtn.FontWeight = 'Bold'
    $pBtn.Cursor = [Windows.Input.Cursors]::Hand
    $pBtn.Add_Click({
        param($s, $e)
        try {
            $u = [string]$s.Tag
            if ($u -match '^mailto:') { Start-Process $u } else { Open-SLTLink $u }
        } catch {}
    })
    $pillsWrap.Children.Add($pBtn)|Out-Null
}
$ownerStack.Children.Add($pillsWrap)|Out-Null

$ownerCard.Child = $ownerStack
$mainStack.Children.Add($ownerCard)|Out-Null

# ==============================================================================
# CARD 2: FOLLOW US (@smartlifeteck) - 6 SOCIAL BUTTONS IN ONE ROW
# ==============================================================================
$socialCard = New-Object Windows.Controls.Border
$socialCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$socialCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$socialCard.BorderThickness = [Windows.Thickness]::new(1.2)
$socialCard.CornerRadius = [Windows.CornerRadius]::new(16)
$socialCard.Padding = [Windows.Thickness]::new(22, 16, 22, 16)
$socialCard.Margin = [Windows.Thickness]::new(4, 0, 4, 14)
$socialCard.Effect = New-SLTCabinShadow 14 2 0.05

$socialStack = New-Object Windows.Controls.StackPanel

$socialHdr = New-Object Windows.Controls.TextBlock
$socialHdr.Text = 'FOLLOW US  -  @smartlifeteck'
$socialHdr.FontSize = 13.5; $socialHdr.FontWeight = 'Bold'
$socialHdr.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$socialStack.Children.Add($socialHdr)|Out-Null

$socialSub = New-Object Windows.Controls.TextBlock
$socialSub.Text = 'Click any platform below to open official @smartlifeteck channels directly in your browser or WhatsApp.'
$socialSub.FontSize = 11.8; $socialSub.Margin = [Windows.Thickness]::new(0, 3, 0, 12)
$socialSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$socialStack.Children.Add($socialSub)|Out-Null

$socialGrid = New-Object Windows.Controls.Primitives.UniformGrid
$socialGrid.Columns = 6

$socialChannels = @(
    @{ Name = 'WhatsApp';  Handle = '@smartlifeteck';     Url = $brandWaUrl },
    @{ Name = 'Facebook';  Handle = '@smartlifeteck';     Url = 'https://www.facebook.com/SmartLIfeTeck' },
    @{ Name = 'Instagram'; Handle = '@smartlifeteck';     Url = 'https://www.instagram.com/smartlifeteck/' },
    @{ Name = 'YouTube';   Handle = '@smartlifeteck';     Url = 'https://www.youtube.com/@smartlifeteck' },
    @{ Name = 'TikTok';    Handle = '@smartlifeteck';     Url = 'https://www.tiktok.com/@smartlifeteck' },
    @{ Name = 'Haraj KSA'; Handle = '@smartlifeteck.ksa'; Url = $brandHarajUrl }
)

foreach ($sc in $socialChannels) {
    $sBtn = New-Object Windows.Controls.Button
    $sBtn.Style = $script:Window.FindResource('ActionButton')
    $sBtn.Height = 52; $sBtn.Margin = [Windows.Thickness]::new(4, 0, 4, 0)
    $sBtn.Padding = [Windows.Thickness]::new(8, 4, 8, 4)
    $sBtn.Tag = [string]$sc.Url
    $sBtn.ToolTip = ("Open Smart Life Teck on " + $sc.Name + " (" + $sc.Url + ")")
    $sBtn.Cursor = [Windows.Input.Cursors]::Hand

    $sbStack = New-Object Windows.Controls.StackPanel
    $sbStack.HorizontalAlignment = 'Center'; $sbStack.VerticalAlignment = 'Center'
    $sbStack.IsHitTestVisible = $false

    $sbTitle = New-Object Windows.Controls.TextBlock
    $sbTitle.Text = $sc.Name
    $sbTitle.FontSize = 12.5; $sbTitle.FontWeight = 'Bold'; $sbTitle.HorizontalAlignment = 'Center'
    $sbTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')

    $sbSub = New-Object Windows.Controls.TextBlock
    $sbSub.Text = $sc.Handle
    $sbSub.FontSize = 9.8; $sbSub.HorizontalAlignment = 'Center'
    $sbSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')

    $sbStack.Children.Add($sbTitle)|Out-Null
    $sbStack.Children.Add($sbSub)|Out-Null
    $sBtn.Content = $sbStack

    $sBtn.Add_Click({
        param($s, $e)
        try { Open-SLTLink ([string]$s.Tag) } catch {}
    })
    $socialGrid.Children.Add($sBtn)|Out-Null
}
$socialStack.Children.Add($socialGrid)|Out-Null
$socialCard.Child = $socialStack
$mainStack.Children.Add($socialCard)|Out-Null

# ==============================================================================
# CARD 3: SUPPORT ACTIONS & COMPACT THEME DROPDOWN (NO 10 Big Theme Buttons)
# ==============================================================================
$supportCard = New-Object Windows.Controls.Border
$supportCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$supportCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$supportCard.BorderThickness = [Windows.Thickness]::new(1.2)
$supportCard.CornerRadius = [Windows.CornerRadius]::new(16)
$supportCard.Padding = [Windows.Thickness]::new(22, 16, 22, 16)
$supportCard.Margin = [Windows.Thickness]::new(4, 0, 4, 14)
$supportCard.Effect = New-SLTCabinShadow 14 2 0.05

$supGrid = New-Object Windows.Controls.Grid
$sg0 = New-Object Windows.Controls.ColumnDefinition; $sg0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$sg1 = New-Object Windows.Controls.ColumnDefinition; $sg1.Width = [Windows.GridLength]::Auto
$supGrid.ColumnDefinitions.Add($sg0)|Out-Null
$supGrid.ColumnDefinitions.Add($sg1)|Out-Null

$supLeft = New-Object Windows.Controls.StackPanel
$supHdr = New-Object Windows.Controls.TextBlock
$supHdr.Text = 'SUPPORT & DIAGNOSTICS'
$supHdr.FontSize = 13.5; $supHdr.FontWeight = 'Bold'
$supHdr.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
$supHdr.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$supLeft.Children.Add($supHdr)|Out-Null

$supBtnRow = New-Object Windows.Controls.WrapPanel
$supBtnRow.Orientation = 'Horizontal'

$btnWaSupport = New-Object Windows.Controls.Button
$btnWaSupport.Content = 'WhatsApp Support'
$btnWaSupport.ToolTip = "Chat with Smart Life Teck Support on WhatsApp ($brandWa)"
$btnWaSupport.Style = $script:Window.FindResource('ActionButton')
$btnWaSupport.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'BtnSelectedBg')
$btnWaSupport.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'BtnSelectedText')
$btnWaSupport.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg')
$btnWaSupport.Height = 38; $btnWaSupport.Padding = [Windows.Thickness]::new(18, 4, 18, 4)
$btnWaSupport.Margin = [Windows.Thickness]::new(0, 0, 10, 4)
$btnWaSupport.Add_Click({
    try { Open-SLTLink $brandWaUrl } catch {}
})

$btnOpenLogs = New-Object Windows.Controls.Button
$btnOpenLogs.Content = 'Open SLT Logs'
$btnOpenLogs.ToolTip = 'Open local Smart PC Boost diagnostic and operation logs folder'
$btnOpenLogs.Style = $script:Window.FindResource('ActionButton')
$btnOpenLogs.Height = 38; $btnOpenLogs.Padding = [Windows.Thickness]::new(18, 4, 18, 4)
$btnOpenLogs.Margin = [Windows.Thickness]::new(0, 0, 10, 4)
$btnOpenLogs.Add_Click({
    try { Start-Process explorer.exe $script:LogDir } catch {}
})

$btnCheckUpdate = New-Object Windows.Controls.Button
$btnCheckUpdate.Content = 'Check for Update'
$btnCheckUpdate.ToolTip = "Visit $brandWeb to check for the latest Smart PC Boost release"
$btnCheckUpdate.Style = $script:Window.FindResource('ActionButton')
$btnCheckUpdate.Height = 38; $btnCheckUpdate.Padding = [Windows.Thickness]::new(18, 4, 18, 4)
$btnCheckUpdate.Margin = [Windows.Thickness]::new(0, 0, 10, 4)
$btnCheckUpdate.Add_Click({
    try { Open-SLTLink $brandWebUrl } catch {}
})

$supBtnRow.Children.Add($btnWaSupport)|Out-Null
$supBtnRow.Children.Add($btnOpenLogs)|Out-Null
$supBtnRow.Children.Add($btnCheckUpdate)|Out-Null
$supLeft.Children.Add($supBtnRow)|Out-Null
$supLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
$supGrid.Children.Add($supLeft)|Out-Null

# Right side: ONLY 1 Small Theme Dropdown (Synchronized two-way with $script:CurrentTheme & $script:ThemeSelector)
$themeRight = New-Object Windows.Controls.StackPanel
$themeRight.VerticalAlignment = 'Center'
$themeLbl = New-Object Windows.Controls.TextBlock
$themeLbl.Text = 'App Theme:'
$themeLbl.FontSize = 11.5; $themeLbl.FontWeight = 'Bold'
$themeLbl.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
$themeLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')

$script:SupportThemeCombo = New-Object Windows.Controls.ComboBox
$script:SupportThemeCombo.Width = 240; $script:SupportThemeCombo.Height = 36
$script:SupportThemeCombo.FontSize = 12; $script:SupportThemeCombo.FontWeight = 'SemiBold'
$script:SupportThemeCombo.VerticalContentAlignment = 'Center'
$themeChoices = @(
    @{ Name = '1. SLT Emerald Dark (Main)';               Key = 'EmeraldDark' },
    @{ Name = '2. SLT Midnight Dark (Deep Slate)';        Key = 'MidnightDark' },
    @{ Name = '3. SLT Ocean Calm Dark (Eye-Comfort Teal)';Key = 'OceanCalmDark' },
    @{ Name = '4. SLT Carbon Gold Dark (Soft Graphite)';  Key = 'CarbonGoldDark' },
    @{ Name = '5. SLT Arctic Blue Light (Crisp White)';   Key = 'ArcticBlueLight' },
    @{ Name = '6. SLT Snow White Light (Pure Teal)';      Key = 'SnowWhiteLight' },
    @{ Name = '7. SLT Warm Paper Comfort (Cream)';        Key = 'WarmSandLight' },
    @{ Name = '8. SLT Soft Sage Eye-Care (Mint Light)';   Key = 'SoftSageLight' }
)
$initialIdx = 0
for ($ti = 0; $ti -lt $themeChoices.Count; $ti++) {
    $tc = $themeChoices[$ti]
    $cbi = New-Object Windows.Controls.ComboBoxItem
    $cbi.Content = $tc.Name
    $cbi.Tag = $tc.Key
    $script:SupportThemeCombo.Items.Add($cbi)|Out-Null
    if ($script:CurrentTheme -eq $tc.Key) { $initialIdx = $ti }
}
$script:SupportThemeCombo.SelectedIndex = $initialIdx
$script:SupportThemeCombo.Add_SelectionChanged({
    param($s, $e)
    try {
        if ($script:SuppressSupportThemeEvent) { return }
        $selItem = $s.SelectedItem
        if ($null -ne $selItem -and $null -ne $selItem.Tag) {
            $tKey = [string]$selItem.Tag
            Set-SLTTheme $tKey
            if ($null -ne $script:ThemeSelector -and $script:ThemeSelector.SelectedIndex -ne $s.SelectedIndex) {
                $script:ThemeSelector.SelectedIndex = $s.SelectedIndex
            }
        }
    } catch {}
})
$themeRight.Children.Add($themeLbl)|Out-Null
$themeRight.Children.Add($script:SupportThemeCombo)|Out-Null
$themeRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
$supGrid.Children.Add($themeRight)|Out-Null

$supportCard.Child = $supGrid
$mainStack.Children.Add($supportCard)|Out-Null

# ==============================================================================
# LICENSE: ONLY 1 LINE
# ==============================================================================
$licCard = New-Object Windows.Controls.Border
$licCard.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$licCard.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$licCard.BorderThickness = [Windows.Thickness]::new(1)
$licCard.CornerRadius = [Windows.CornerRadius]::new(12)
$licCard.Padding = [Windows.Thickness]::new(18, 12, 18, 12)
$licCard.Margin = [Windows.Thickness]::new(4, 0, 4, 8)
$licTxt = New-Object Windows.Controls.TextBlock
$licTxt.Text = '100% Original Smart Life Teck Software - Developed by Shahzad Babar'
$licTxt.FontSize = 13; $licTxt.FontWeight = 'Bold'; $licTxt.HorizontalAlignment = 'Center'
$licTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$licCard.Child = $licTxt
$mainStack.Children.Add($licCard)|Out-Null

$page.Children.Add($mainStack)|Out-Null

$page.Add_IsVisibleChanged({
    try {
        if ($page.IsVisible -and $null -ne $script:SupportThemeCombo) {
            for ($idx = 0; $idx -lt $script:SupportThemeCombo.Items.Count; $idx++) {
                $it = $script:SupportThemeCombo.Items[$idx]
                if ($null -ne $it -and [string]$it.Tag -eq [string]$script:CurrentTheme) {
                    if ($script:SupportThemeCombo.SelectedIndex -ne $idx) {
                        $script:SuppressSupportThemeEvent = $true
                        try { $script:SupportThemeCombo.SelectedIndex = $idx } finally { $script:SuppressSupportThemeEvent = $false }
                    }
                    break
                }
            }
        }
    } catch {}
})
