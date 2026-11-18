# ==============================================================================
# TAB 3 (Index 2): Smart Tools Hub (104 Tools Hub) - Single Variable Theme Engine
# 100% bound to Window.Resources DynamicResources (--bg, --card, --sidebar, --text,
# --text-dim, --btn-bg, --btn-text, --btn-border, --btn-hover-bg, --btn-hover-text,
# --btn-selected-bg, --btn-selected-text, --btn-radius = 12px).
# Zero permanently highlighted buttons: Search, Reset, Category Pills, Smart Life Teck
# bottom buttons, and all 104 Tool Cards only highlight when clicked/selected!
# ==============================================================================
$page = New-SLTPage 2
$page.Margin = [Windows.Thickness]::new(0)

$emDash   = [char]0x2014
$bullet   = [char]0x2022
$neArrow  = ' ' + ([char]0x2197)
$heartChr = [char]0x2665
$copyChr  = [char]0x00A9

$hubJsonRaw = @'
[{"id": "productive", "title": "Productive Tools \u2014 Top 35", "count": 35, "tools": [{"name": "BMI Calculator", "url": "https://www.calculator.net/bmi-calculator.html", "icon": "\ud83e\uddee"}, {"name": "Age Calculator", "url": "https://www.calculator.net/age-calculator.html", "icon": "\ud83c\udf82"}, {"name": "Percentage Calc", "url": "https://www.calculator.net/percent-calculator.html", "icon": "%"}, {"name": "Loan EMI Calc", "url": "https://www.calculator.net/loan-calculator.html", "icon": "\ud83c\udfe6"}, {"name": "Scientific Calc", "url": "https://www.calculator.net/scientific-calculator.html", "icon": "\ud83d\udd2c"}, {"name": "Unit Converter", "url": "https://www.unitconverters.net/", "icon": "\u2194\ufe0f"}, {"name": "Currency Converter", "url": "https://www.xe.com/currencyconverter/", "icon": "\ud83d\udcb1", "tags": "sar riyal usd pkr exchange rate money xe"}, {"name": "PairDrop File Share", "url": "https://pairdrop.net/", "icon": "\ud83d\udce1", "tags": "airdrop file transfer wifi share phone pc local"}, {"name": "World Clock", "url": "https://www.timeanddate.com/worldclock/", "icon": "\ud83c\udf0d"}, {"name": "Gold & Silver Price", "url": "https://goldprice.org/", "icon": "\ud83e\udd47"}, {"name": "Crypto Prices", "url": "https://coinmarketcap.com/", "icon": "\u20bf"}, {"name": "Stock Market", "url": "https://finance.yahoo.com/", "icon": "\ud83d\udcc8"}, {"name": "TradingView", "url": "https://www.tradingview.com/", "icon": "\ud83d\udcca"}, {"name": "Google Drive", "url": "https://drive.google.com/", "icon": "\ud83d\udcbe"}, {"name": "Google Docs", "url": "https://docs.google.com/", "icon": "\ud83d\udcc4"}, {"name": "PDF Tools", "url": "https://www.ilovepdf.com/", "icon": "\ud83d\udcd1", "tags": "merge split compress convert pdf word excel"}, {"name": "Image Compressor", "url": "https://tinypng.com/", "icon": "\ud83d\udddc\ufe0f"}, {"name": "Background Remover", "url": "https://www.remove.bg/", "icon": "\u2702\ufe0f"}, {"name": "QR Code Generator", "url": "https://www.qr-code-generator.com/", "icon": "\ud83d\udd33"}, {"name": "File Converter", "url": "https://cloudconvert.com/", "icon": "\ud83d\udd04"}, {"name": "Password Generator", "url": "https://passwordsgenerator.net/", "icon": "\ud83d\udd10"}, {"name": "Virus Scanner", "url": "https://www.virustotal.com/", "icon": "\ud83d\udee1\ufe0f", "tags": "virustotal malware security scan file url"}, {"name": "Speed Test", "url": "https://www.speedtest.net/", "icon": "\u26a1", "tags": "internet wifi ping bandwidth ookla"}, {"name": "Google Maps", "url": "https://maps.google.com/", "icon": "\ud83d\uddfa\ufe0f"}, {"name": "Weather", "url": "https://www.accuweather.com/", "icon": "\u26c5"}, {"name": "Prayer Times", "url": "https://www.islamicfinder.org/prayer-times/", "icon": "\ud83d\udd4c", "tags": "namaz salah makkah madinah riyadh duba yanbu"}, {"name": "Hijri Converter", "url": "https://www.islamicfinder.org/islamic-date-converter/", "icon": "\ud83c\udf19", "tags": "islamic calendar ramadan eid date"}, {"name": "Google Translate", "url": "https://translate.google.com/", "icon": "\ud83c\udf10"}, {"name": "Grammarly", "url": "https://www.grammarly.com/", "icon": "\u270d\ufe0f"}, {"name": "Canva", "url": "https://www.canva.com/", "icon": "\ud83c\udfa8"}, {"name": "Notion", "url": "https://www.notion.so/", "icon": "\ud83d\udcd3"}, {"name": "Todoist", "url": "https://todoist.com/", "icon": "\u2705"}, {"name": "Resume Builder", "url": "https://www.resume.com/", "icon": "\ud83d\udcdd"}, {"name": "TinyWow Free Suite", "url": "https://tinywow.com/", "icon": "\ud83e\uddf0", "tags": "pdf video image converter ai free tools"}, {"name": "Photopea Photoshop", "url": "https://www.photopea.com/", "icon": "\ud83c\udfa8", "tags": "photoshop psd image photo editor design"}]}, {"id": "ai", "title": "Top 25 AI Tools \u2014 World Top 2025-2026", "count": 25, "tools": [{"name": "ChatGPT", "url": "https://chatgpt.com/", "icon": "\ud83e\udd16", "tags": "openai gpt4 o1 chat writing code"}, {"name": "Claude AI", "url": "https://claude.ai/", "icon": "\ud83e\udde0"}, {"name": "Google Gemini", "url": "https://gemini.google.com/", "icon": "\u2728"}, {"name": "Grok xAI", "url": "https://grok.com/", "icon": "\ud83d\ude80"}, {"name": "Perplexity", "url": "https://www.perplexity.ai/", "icon": "\ud83d\udd0d"}, {"name": "Microsoft Copilot", "url": "https://copilot.microsoft.com/", "icon": "\ud83d\udca1"}, {"name": "Meta AI", "url": "https://www.meta.ai/", "icon": "\u267e\ufe0f"}, {"name": "DeepSeek", "url": "https://chat.deepseek.com/", "icon": "\ud83d\udc0b", "tags": "deepseek r1 v3 reasoning coding math chat"}, {"name": "Mistral Le Chat", "url": "https://chat.mistral.ai/", "icon": "\ud83c\udf2c\ufe0f"}, {"name": "GitHub Copilot", "url": "https://github.com/features/copilot", "icon": "\ud83d\udc68\u200d\ud83d\udcbb"}, {"name": "Hugging Face", "url": "https://huggingface.co/", "icon": "\ud83e\udd17"}, {"name": "Midjourney", "url": "https://www.midjourney.com/", "icon": "\ud83c\udfad"}, {"name": "Google NotebookLM", "url": "https://notebooklm.google.com/", "icon": "\ud83d\udcda", "tags": "research study notes audio podcast summary pdf google"}, {"name": "Stable Diffusion", "url": "https://stability.ai/", "icon": "\ud83c\udfa8"}, {"name": "Leonardo AI", "url": "https://leonardo.ai/", "icon": "\ud83e\udd81"}, {"name": "Runway ML", "url": "https://runwayml.com/", "icon": "\ud83c\udfac"}, {"name": "ElevenLabs", "url": "https://elevenlabs.io/", "icon": "\ud83c\udf99\ufe0f"}, {"name": "Notion AI", "url": "https://www.notion.so/product/ai", "icon": "\ud83d\udcdd"}, {"name": "Google AI Studio", "url": "https://aistudio.google.com/", "icon": "\ud83e\uddea", "tags": "gemini pro api prompt developer free google"}, {"name": "Canva Magic Studio", "url": "https://www.canva.com/magic/", "icon": "\ud83e\ude84"}, {"name": "Cursor AI Code", "url": "https://www.cursor.com/", "icon": "\u2328\ufe0f", "tags": "ide programming coding editor developer"}, {"name": "Replit AI", "url": "https://replit.com/", "icon": "\u2699\ufe0f"}, {"name": "Character.AI", "url": "https://character.ai/", "icon": "\ud83d\udc65"}, {"name": "Poe by Quora", "url": "https://poe.com/", "icon": "\ud83d\udcac"}, {"name": "Suno AI Music", "url": "https://suno.com/", "icon": "\ud83c\udfb5", "tags": "audio song music voice generator creator"}]}, {"id": "social", "title": "Top 20 Social Tools \u2014 Most Used", "count": 20, "tools": [{"name": "YouTube", "url": "https://www.youtube.com/", "icon": "\u25b6\ufe0f"}, {"name": "TikTok", "url": "https://www.tiktok.com/", "icon": "\ud83c\udfb5"}, {"name": "X Twitter", "url": "https://x.com/", "icon": "\ud835\udd4f"}, {"name": "LinkedIn", "url": "https://www.linkedin.com/", "icon": "in"}, {"name": "Snapchat", "url": "https://www.snapchat.com/", "icon": "\ud83d\udc7b"}, {"name": "WhatsApp Web", "url": "https://web.whatsapp.com/", "icon": "\ud83d\udcac"}, {"name": "Telegram", "url": "https://web.telegram.org/", "icon": "\u2708\ufe0f"}, {"name": "Pinterest", "url": "https://www.pinterest.com/", "icon": "\ud83d\udccc"}, {"name": "Reddit", "url": "https://www.reddit.com/", "icon": "\ud83e\udd16"}, {"name": "Discord", "url": "https://discord.com/", "icon": "\ud83c\udfae"}, {"name": "Twitch", "url": "https://www.twitch.tv/", "icon": "\ud83d\udcfa"}, {"name": "Hootsuite", "url": "https://www.hootsuite.com/", "icon": "\ud83e\udd89"}, {"name": "Buffer", "url": "https://buffer.com/", "icon": "\ud83d\udce6"}, {"name": "CapCut", "url": "https://www.capcut.com/", "icon": "\u2702\ufe0f"}, {"name": "Metricool Social", "url": "https://metricool.com/", "icon": "\ud83d\udcca", "tags": "analytics scheduler social media marketing smart life teck"}, {"name": "Haraj KSA Market", "url": "https://haraj.com.sa/", "icon": "\ud83d\uded2", "tags": "saudi marketplace laptops cars electronics buy sell ksa"}, {"name": "Later", "url": "https://later.com/", "icon": "\ud83d\udd53"}, {"name": "YouTube Studio", "url": "https://studio.youtube.com/", "icon": "\ud83c\udfac"}, {"name": "Google Meet", "url": "https://meet.google.com/", "icon": "\ud83d\udcf9"}, {"name": "Zoom", "url": "https://zoom.us/", "icon": "\ud83d\udd35"}]}, {"id": "jobs", "title": "Jobs & Career \u2014 Very Useful", "count": 8, "tools": [{"name": "LinkedIn Jobs", "url": "https://www.linkedin.com/jobs/", "icon": "\ud83d\udcbc"}, {"name": "Indeed", "url": "https://www.indeed.com/", "icon": "\ud83d\udd0e"}, {"name": "Glassdoor", "url": "https://www.glassdoor.com/", "icon": "\ud83c\udfe2"}, {"name": "Naukri Gulf", "url": "https://www.naukrigulf.com/", "icon": "\ud83c\udf0d"}, {"name": "Bayt.com", "url": "https://www.bayt.com/", "icon": "\ud83c\uddf8\ud83c\udde6"}, {"name": "Coursera", "url": "https://www.coursera.org/", "icon": "\ud83c\udf93"}, {"name": "Udemy", "url": "https://www.udemy.com/", "icon": "\ud83d\udcda"}, {"name": "Khan Academy", "url": "https://www.khanacademy.org/", "icon": "\ud83e\uddd1\u200d\ud83c\udfeb"}]}, {"id": "learning", "title": "Learning & Saudi Services", "count": 8, "tools": [{"name": "Qiwa KSA Portal", "url": "https://qiwa.sa/", "icon": "\ud83d\udcbc", "tags": "saudi labor work visa iqama contract hr ministry"}, {"name": "Absher", "url": "https://www.absher.sa/", "icon": "\ud83e\udeaa", "tags": "saudi iqama passport traffic visa moi jawazat"}, {"name": "MOI", "url": "https://www.moi.gov.sa/", "icon": "\ud83c\udfdb\ufe0f"}, {"name": "MOH", "url": "https://www.moh.gov.sa/", "icon": "\u2695\ufe0f"}, {"name": "MyGov Saudi", "url": "https://www.my.gov.sa/", "icon": "\ud83c\uddf8\ud83c\udde6"}, {"name": "SPL Tracking", "url": "https://splonline.com.sa/", "icon": "\ud83d\udce6", "tags": "saudi post parcel shipment national address delivery"}, {"name": "Google Classroom", "url": "https://classroom.google.com/", "icon": "\ud83c\udfeb"}, {"name": "Duolingo", "url": "https://www.duolingo.com/", "icon": "\ud83e\udd89"}]}, {"id": "news", "title": "News \u2014 Saudi, Pakistan & World", "count": 8, "tools": [{"name": "Arab News Saudi", "url": "https://www.arabnews.com/", "icon": "\ud83c\uddf8\ud83c\udde6"}, {"name": "Saudi Gazette", "url": "https://saudigazette.com.sa/", "icon": "\ud83d\uddde\ufe0f"}, {"name": "Dawn News Pakistan", "url": "https://www.dawn.com/", "icon": "\ud83c\uddf5\ud83c\uddf0"}, {"name": "Geo News Pakistan", "url": "https://www.geo.tv/", "icon": "\ud83d\udcfa"}, {"name": "Jang Urdu Pakistan", "url": "https://jang.com.pk/", "icon": "\ud83d\udcf0"}, {"name": "BBC World News", "url": "https://www.bbc.com/news", "icon": "\ud83c\udf10"}, {"name": "Reuters World", "url": "https://www.reuters.com/", "icon": "\ud83c\udf0d"}, {"name": "Al Jazeera English", "url": "https://www.aljazeera.com/", "icon": "\ud83d\udce1"}]}]
'@
$parsedHub = $hubJsonRaw | ConvertFrom-Json
if ($parsedHub -is [array] -and $parsedHub.Count -eq 1 -and $parsedHub[0] -is [array]) {
    $parsedHub = $parsedHub[0]
}
$script:UltimateHubSections = $parsedHub
$script:UltimateHubFilter = 'all'
$script:UltimateHubSectionBlocks = @{}
$script:UltimateHubPillButtons = @{}
$script:UltimateHubCountBadges = @{}
$script:UltimateHubCardList = New-Object System.Collections.Generic.List[object]

function Attach-SLTHubBtnBehavior([Windows.Controls.Border]$Bdr, [Windows.Controls.TextBlock]$Lbl, [double]$LiftY=-2) {
    $Bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
    $Bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
    $Bdr.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty, 'BtnRadius')
    $Bdr.BorderThickness = [Windows.Thickness]::new(1)
    $Bdr.Cursor = [Windows.Input.Cursors]::Hand
    $Bdr.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)
    if ($null -ne $Lbl) {
        $Lbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
    }
    $Bdr.Add_MouseEnter({
        param($s, $e)
        $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, -2)
        if ($script:SelectedBorderBtn -ne $s) {
            $s.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnHoverBg')
            $s.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            if ($null -ne $s.Tag -and $s.Tag -is [hashtable] -and $null -ne $s.Tag.Label) {
                $s.Tag.Label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnHoverText')
            }
        }
    })
    $Bdr.Add_MouseLeave({
        param($s, $e)
        $s.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)
        if ($script:SelectedBorderBtn -ne $s) {
            $s.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
            $s.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            if ($null -ne $s.Tag -and $s.Tag -is [hashtable] -and $null -ne $s.Tag.Label) {
                $s.Tag.Label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
            }
        }
    })
}

function Open-SLTHubWebViewWindow {
    $htmlFile = Join-Path $script:Root 'assets\slt-ultimate-hub-final.html'
    if (-not (Test-Path -LiteralPath $htmlFile)) { return }
    $fileUri = ([System.Uri]$htmlFile).AbsoluteUri + '?theme=' + [string]$script:CurrentTheme
    $edgeCandidates = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($ep in $edgeCandidates) {
        if (Test-Path -LiteralPath $ep) {
            Start-Process -FilePath $ep -ArgumentList ('--app="' + $fileUri + '" --window-size=1320,880')
            Log-SLT 'Opened SLT Smart Tools in Edge WebView2 App Mode.'
            return
        }
    }
    Start-Process -FilePath $htmlFile
}

function New-SLTHubDesktopShortcut {
    try {
        $htmlFile = Join-Path $script:Root 'assets\slt-ultimate-hub-final.html'
        $targetUrl = if (Test-Path -LiteralPath $htmlFile) { $htmlFile } else { 'https://www.smartlifeteck.com' }
        $deskDir = [Environment]::GetFolderPath('Desktop')
        $lnkPath = Join-Path $deskDir 'SLT Smart Tools Hub (104 Tools).lnk'
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnkPath)
        $edgePath = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        if (-not (Test-Path -LiteralPath $edgePath)) {
            $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        }
        if ((Test-Path -LiteralPath $edgePath) -and (Test-Path -LiteralPath $htmlFile)) {
            $fileUri = ([System.Uri]$htmlFile).AbsoluteUri + '?theme=' + [string]$script:CurrentTheme
            $sc.TargetPath = $edgePath
            $sc.Arguments  = ('--app="' + $fileUri + '" --window-size=1320,880')
        } else {
            $sc.TargetPath = $targetUrl
        }
        $icoFile = Join-Path $script:Root 'assets\SLT_PC_CARE_PRO.ico'
        if (-not (Test-Path -LiteralPath $icoFile)) { $icoFile = Join-Path $script:Root 'SLT_PC_CARE_PRO.ico' }
        if (Test-Path -LiteralPath $icoFile) {
            $sc.IconLocation = ($icoFile + ',0')
        }
        $sc.Description = 'SLT Smart Tools Hub - 104 Curated AI, Productive & Saudi Tools by Smart Life Teck'
        $sc.Save()
        [Windows.MessageBox]::Show('Desktop shortcut "SLT Smart Tools Hub (104 Tools)" has been created on your Desktop!', 'Smart Tools Hub', 'OK', 'Information') | Out-Null
    } catch {
        Log-SLT ('New-SLTHubDesktopShortcut error: ' + $_.Exception.Message)
    }
}

function Update-SLTHubFilterAndSearch {
    $q = if ($null -ne $script:UltimateHubSearchBox -and $null -ne $script:UltimateHubSearchBox.Text) {
        $script:UltimateHubSearchBox.Text.Trim().ToLowerInvariant()
    } else { '' }

    if ($null -ne $script:UltimateHubSearchPlaceholder) {
        $hasFocus = ($null -ne $script:UltimateHubSearchBox -and $script:UltimateHubSearchBox.IsKeyboardFocused)
        $script:UltimateHubSearchPlaceholder.Visibility = $(if ([string]::IsNullOrEmpty($q) -and (-not $hasFocus)) { 'Visible' } else { 'Collapsed' })
    }

    $activeCat = if (-not [string]::IsNullOrWhiteSpace($script:UltimateHubFilter)) { $script:UltimateHubFilter } else { 'all' }

    $secCounts = @{}
    foreach ($secKey in $script:UltimateHubSectionBlocks.Keys) {
        $secCounts[$secKey] = 0
    }

    $totalVisible = 0
    foreach ($cardRec in $script:UltimateHubCardList) {
        $sId = [string]$cardRec.SectionId
        $catMatch = ($activeCat -eq 'all' -or $sId -eq $activeCat)
        $qMatch = ($q -eq '' -or $cardRec.NameLower.Contains($q) -or $cardRec.SecTitleLower.Contains($q) -or $cardRec.UrlLower.Contains($q) -or $cardRec.TagsLower.Contains($q))
        if ($catMatch -and $qMatch) {
            $cardRec.Card.Visibility = 'Visible'
            $secCounts[$sId] = [int]$secCounts[$sId] + 1
            $totalVisible++
        } else {
            $cardRec.Card.Visibility = 'Collapsed'
        }
    }

    if ($q -ne '' -and $totalVisible -eq 0 -and $activeCat -ne 'all') {
        $script:UltimateHubFilter = 'all'
        Update-SLTHubFilterAndSearch
        return
    }

    foreach ($secKey in $script:UltimateHubSectionBlocks.Keys) {
        $secBlock = $script:UltimateHubSectionBlocks[$secKey]
        $cnt = [int]$secCounts[$secKey]
        if ($null -ne $secBlock) {
            $secBlock.Visibility = $(if ($cnt -gt 0) { 'Visible' } else { 'Collapsed' })
        }
        if ($script:UltimateHubCountBadges.ContainsKey($secKey)) {
            $script:UltimateHubCountBadges[$secKey].Text = [string]$cnt
        }
    }

    if ($null -ne $script:UltimateHubSearchInfo) {
        if ($q -ne '') {
            if ($totalVisible -gt 0) {
                $script:UltimateHubSearchInfo.Text = ('Found {0} matching tool(s) for "{1}"' -f $totalVisible, $script:UltimateHubSearchBox.Text.Trim())
            } else {
                $script:UltimateHubSearchInfo.Text = ('No tools found matching "{0}" - Click Reset to view all 104 tools' -f $script:UltimateHubSearchBox.Text.Trim())
            }
            $script:UltimateHubSearchInfo.Visibility = 'Visible'
        } elseif ($activeCat -ne 'all') {
            $script:UltimateHubSearchInfo.Text = ('Showing {0} tools in selected category (Click "All 104" or "Reset" to view all)' -f $totalVisible)
            $script:UltimateHubSearchInfo.Visibility = 'Visible'
        } else {
            $script:UltimateHubSearchInfo.Text = ''
            $script:UltimateHubSearchInfo.Visibility = 'Collapsed'
        }
    }
}

function Set-SLTHubCategoryFilter([string]$SectionId) {
    $script:UltimateHubFilter = $SectionId
    if ($script:UltimateHubPillButtons.ContainsKey($SectionId)) {
        $pi = $script:UltimateHubPillButtons[$SectionId]
        Select-SLTBorderButton $pi.Border $pi.Label
    }
    Update-SLTHubFilterAndSearch
}

function Update-SLTHubThemeVisuals {
    Update-SLTHubFilterAndSearch
}

# Root container (transparent so WorkspaceGrid's DynamicResource WindowBg + RadialGlow shines through!)
$hubRootGrid = New-Object Windows.Controls.Grid
$hubRootGrid.Background = [Windows.Media.Brushes]::Transparent
$hubRootGrid.HorizontalAlignment = 'Stretch'

$mainVertStack = New-Object Windows.Controls.StackPanel
$mainVertStack.HorizontalAlignment = 'Stretch'

# Inner Centered Container (maxWidth: 1150px, padding: 32px 22px)
$innerContainer = New-Object Windows.Controls.StackPanel
$innerContainer.MaxWidth = 1150
$innerContainer.HorizontalAlignment = 'Stretch'
$innerContainer.Margin = [Windows.Thickness]::new(22,30,22,20)

# ========================== HEADER ==========================
$headerStack = New-Object Windows.Controls.StackPanel
$headerStack.HorizontalAlignment = 'Center'
$headerStack.Margin = [Windows.Thickness]::new(0,0,0,26)

# Top Badge: [dot] ULTIMATE EDITION - 104 TOOLS
$topBadgeBdr = New-Object Windows.Controls.Border
$topBadgeBdr.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty, 'BtnRadius')
$topBadgeBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$topBadgeBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$topBadgeBdr.BorderThickness = [Windows.Thickness]::new(1)
$topBadgeBdr.Padding = [Windows.Thickness]::new(14,5,14,5)
$topBadgeBdr.HorizontalAlignment = 'Center'
$topBadgeBdr.Margin = [Windows.Thickness]::new(0,0,0,14)
$topBadgeRow = New-Object Windows.Controls.StackPanel
$topBadgeRow.Orientation = 'Horizontal'; $topBadgeRow.VerticalAlignment = 'Center'
$goldDot = New-Object Windows.Controls.Border
$goldDot.Width = 8; $goldDot.Height = 8; $goldDot.CornerRadius = [Windows.CornerRadius]::new(4)
$goldDot.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'TextAccent')
$goldDot.Margin = [Windows.Thickness]::new(0,0,8,0); $goldDot.VerticalAlignment = 'Center'
$topBadgeTxt = New-Object Windows.Controls.TextBlock
$topBadgeTxt.Text = "ULTIMATE EDITION  $bullet  104 TOOLS"
$topBadgeTxt.FontSize = 11; $topBadgeTxt.FontWeight = 'SemiBold'
$topBadgeTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$topBadgeRow.Children.Add($goldDot)|Out-Null; $topBadgeRow.Children.Add($topBadgeTxt)|Out-Null
$topBadgeBdr.Child = $topBadgeRow
$headerStack.Children.Add($topBadgeBdr)|Out-Null

# H1 Title: SLT Smart Tools - Ultimate AI & Web Hub (bound to TextAccent)
$h1Title = New-Object Windows.Controls.TextBlock
$h1Title.Text = "Smart Tools Hub $emDash Ultimate AI & Web Hub"
$h1Title.FontSize = 35; $h1Title.FontWeight = 'Bold'
$h1Title.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$h1Title.HorizontalAlignment = 'Center'
$h1Title.TextAlignment = 'Center'
$h1Title.Margin = [Windows.Thickness]::new(0,0,0,10)
$headerStack.Children.Add($h1Title)|Out-Null

# Subtitle (Exact Final Selected Description + Smooth Fade-In Transition)
$subTitleTb = New-Object Windows.Controls.TextBlock
$subTitleTb.FontSize = 14.2; $subTitleTb.TextAlignment = 'Center'; $subTitleTb.TextWrapping = 'Wrap'
$subTitleTb.MaxWidth = 760; $subTitleTb.HorizontalAlignment = 'Center'
$subTitleTb.Text = "Smart Life Teck brings your entire digital toolbox hub together in one clean window $emDash no install, no load, just pure productivity. Use daily, work smarter. Smart Your Digital Life $emDash by Shahzad Babar"
$subTitleTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
$subTitleTb.Opacity = 1.0
$script:ToolsHubDescBlock = $subTitleTb

$headerStack.Children.Add($subTitleTb)|Out-Null

# ========================== SEARCH BAR (Normal .slt-btn Search & Reset - NOT permanently highlighted!) ==========================
$hubSearchRow = New-Object Windows.Controls.WrapPanel
$hubSearchRow.HorizontalAlignment = 'Center'
$hubSearchRow.Margin = [Windows.Thickness]::new(0,18,0,4)

$hubSearchGrid = New-Object Windows.Controls.Grid
$hubSearchGrid.Margin = [Windows.Thickness]::new(0,0,8,0)
$hubSearchGrid.VerticalAlignment = 'Center'

$script:UltimateHubSearchBox = New-Object Windows.Controls.TextBox
$script:UltimateHubSearchBox.Width = 340
$script:UltimateHubSearchBox.Height = 38
$script:UltimateHubSearchBox.VerticalContentAlignment = 'Center'
$script:UltimateHubSearchBox.Padding = [Windows.Thickness]::new(12,5,12,5)
$script:UltimateHubSearchBox.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'InputBg')
$script:UltimateHubSearchBox.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'TextPrimary')
$script:UltimateHubSearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'InputBorder')
$script:UltimateHubSearchBox.BorderThickness = [Windows.Thickness]::new(1)
$script:UltimateHubSearchBox.SetResourceReference([Windows.Controls.TextBox]::CaretBrushProperty, 'TextAccent')
$script:UltimateHubSearchBox.FontSize = 12.5

$script:UltimateHubSearchPlaceholder = New-Object Windows.Controls.TextBlock
$script:UltimateHubSearchPlaceholder.Text = 'Search 104 tools (e.g. ChatGPT, Currency, Absher, Canva)...'
$script:UltimateHubSearchPlaceholder.FontSize = 12
$script:UltimateHubSearchPlaceholder.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$script:UltimateHubSearchPlaceholder.Opacity = 0.78
$script:UltimateHubSearchPlaceholder.VerticalAlignment = 'Center'
$script:UltimateHubSearchPlaceholder.Margin = [Windows.Thickness]::new(14,0,10,0)
$script:UltimateHubSearchPlaceholder.IsHitTestVisible = $false

$hubSearchGrid.Children.Add($script:UltimateHubSearchBox)|Out-Null
$hubSearchGrid.Children.Add($script:UltimateHubSearchPlaceholder)|Out-Null
$hubSearchRow.Children.Add($hubSearchGrid)|Out-Null

# Search Button (Normal .slt-btn by default; only highlights when clicked!)
$hubSearchBtn = New-Object Windows.Controls.Border
$hubSearchBtn.Padding = [Windows.Thickness]::new(18,8,18,8)
$hubSearchBtn.Margin = [Windows.Thickness]::new(0,0,6,0)
$hubSearchBtn.VerticalAlignment = 'Center'
$hubSearchBtnTxt = New-Object Windows.Controls.TextBlock
$hubSearchBtnTxt.Text = 'Search'; $hubSearchBtnTxt.FontSize = 12.5; $hubSearchBtnTxt.FontWeight = 'SemiBold'
$hubSearchBtn.Child = $hubSearchBtnTxt
$hubSearchBtn.Tag = @{ Label = $hubSearchBtnTxt }
Attach-SLTHubBtnBehavior $hubSearchBtn $hubSearchBtnTxt
$hubSearchBtn.Add_MouseLeftButtonUp({
    param($s, $e)
    Select-SLTBorderButton $s $s.Tag.Label
    if ([string]::IsNullOrWhiteSpace($script:UltimateHubSearchBox.Text)) {
        try { [void]$script:UltimateHubSearchBox.Focus() } catch {}
    }
    Update-SLTHubFilterAndSearch
})
$hubSearchRow.Children.Add($hubSearchBtn)|Out-Null

# Reset Button (Normal .slt-btn by default; only highlights when clicked!)
$hubResetBtn = New-Object Windows.Controls.Border
$hubResetBtn.Padding = [Windows.Thickness]::new(16,8,16,8)
$hubResetBtn.VerticalAlignment = 'Center'
$hubResetBtnTxt = New-Object Windows.Controls.TextBlock
$hubResetBtnTxt.Text = 'Reset'; $hubResetBtnTxt.FontSize = 12.5; $hubResetBtnTxt.FontWeight = 'SemiBold'
$hubResetBtn.Child = $hubResetBtnTxt
$hubResetBtn.Tag = @{ Label = $hubResetBtnTxt }
Attach-SLTHubBtnBehavior $hubResetBtn $hubResetBtnTxt
$hubResetBtn.Add_MouseLeftButtonUp({
    param($s, $e)
    Select-SLTBorderButton $s $s.Tag.Label
    $script:UltimateHubFilter = 'all'
    if ($null -ne $script:UltimateHubSearchBox) { $script:UltimateHubSearchBox.Text = '' }
    if ($null -ne $script:UltimateHubSearchPlaceholder) { $script:UltimateHubSearchPlaceholder.Visibility = 'Visible' }
    Update-SLTHubFilterAndSearch
})
$hubSearchRow.Children.Add($hubResetBtn)|Out-Null

$headerStack.Children.Add($hubSearchRow)|Out-Null

# Category Filter Pills Row (All normal .slt-btn by default; ONLY clicked pill highlights!)
$pillsWrap = New-Object Windows.Controls.WrapPanel
$pillsWrap.HorizontalAlignment = 'Center'
$pillsWrap.Margin = [Windows.Thickness]::new(0,12,0,0)

$pillDefs = @(
    @{id='all';        label='All 104'},
    @{id='productive'; label='Productive 35'},
    @{id='ai';         label='AI 25'},
    @{id='social';     label='Social 20'},
    @{id='news';       label='News 8'},
    @{id='jobs';       label='Jobs 8'},
    @{id='learning';   label='Saudi 8'}
)

foreach ($pd in $pillDefs) {
    $pBdr = New-Object Windows.Controls.Border
    $pBdr.Padding = [Windows.Thickness]::new(14,7,14,7)
    $pBdr.Margin = [Windows.Thickness]::new(4,3,4,3)
    $pLbl = New-Object Windows.Controls.TextBlock
    $pLbl.Text = [string]$pd.label; $pLbl.FontSize = 12; $pLbl.FontWeight = 'SemiBold'
    $pBdr.Child = $pLbl
    $pBdr.Tag = @{ Id = [string]$pd.id; Label = $pLbl }
    Attach-SLTHubBtnBehavior $pBdr $pLbl
    $pBdr.Add_MouseLeftButtonUp({
        param($sender, $e)
        Set-SLTHubCategoryFilter ([string]$sender.Tag.Id)
    })
    $script:UltimateHubPillButtons[[string]$pd.id] = @{ Border = $pBdr; Label = $pLbl }
    $pillsWrap.Children.Add($pBdr)|Out-Null
}

# WebView2 App Mode Launch Pill (Normal .slt-btn, only highlights when clicked!)
$wvBtnBdr = New-Object Windows.Controls.Border
$wvBtnBdr.Padding = [Windows.Thickness]::new(14,7,14,7)
$wvBtnBdr.Margin = [Windows.Thickness]::new(8,3,4,3)
$wvBtnBdr.ToolTip = 'Open SLT Smart Tools in standalone Edge WebView2 App Window'
$wvBtnTxt = New-Object Windows.Controls.TextBlock
$wvBtnTxt.Text = ('WebView2 App Mode' + $neArrow); $wvBtnTxt.FontSize = 12; $wvBtnTxt.FontWeight = 'SemiBold'
$wvBtnBdr.Child = $wvBtnTxt
$wvBtnBdr.Tag = @{ Label = $wvBtnTxt }
Attach-SLTHubBtnBehavior $wvBtnBdr $wvBtnTxt
$wvBtnBdr.Add_MouseLeftButtonUp({
    param($s, $e)
    Select-SLTBorderButton $s $s.Tag.Label
    Open-SLTHubWebViewWindow
})
$pillsWrap.Children.Add($wvBtnBdr)|Out-Null

$deskHubBtnBdr = New-Object Windows.Controls.Border
$deskHubBtnBdr.Padding = [Windows.Thickness]::new(14,7,14,7)
$deskHubBtnBdr.Margin = [Windows.Thickness]::new(4,3,4,3)
$deskHubBtnBdr.ToolTip = 'Create a 1-click Desktop shortcut for SLT Smart Tools Hub (104 Tools)'
$deskHubBtnTxt = New-Object Windows.Controls.TextBlock
$deskHubBtnTxt.Text = 'Pin Hub to Desktop'; $deskHubBtnTxt.FontSize = 12; $deskHubBtnTxt.FontWeight = 'SemiBold'
$deskHubBtnBdr.Child = $deskHubBtnTxt
$deskHubBtnBdr.Tag = @{ Label = $deskHubBtnTxt }
Attach-SLTHubBtnBehavior $deskHubBtnBdr $deskHubBtnTxt
$deskHubBtnBdr.Add_MouseLeftButtonUp({
    param($s, $e)
    Select-SLTBorderButton $s $s.Tag.Label
    New-SLTHubDesktopShortcut
})
$pillsWrap.Children.Add($deskHubBtnBdr)|Out-Null

$headerStack.Children.Add($pillsWrap)|Out-Null

# Live Filter/Search Status Line
$script:UltimateHubSearchInfo = New-Object Windows.Controls.TextBlock
$script:UltimateHubSearchInfo.FontSize = 12.2
$script:UltimateHubSearchInfo.FontWeight = 'SemiBold'
$script:UltimateHubSearchInfo.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$script:UltimateHubSearchInfo.HorizontalAlignment = 'Center'
$script:UltimateHubSearchInfo.Margin = [Windows.Thickness]::new(0,10,0,0)
$script:UltimateHubSearchInfo.Visibility = 'Collapsed'
$headerStack.Children.Add($script:UltimateHubSearchInfo)|Out-Null

$innerContainer.Children.Add($headerStack)|Out-Null

# Shared Tool Card Event Delegates (eliminates 309 per-card scriptblock allocations)
$script:SLTHubCardMouseEnter = {
    param($sender, $e)
    try {
        $sender.RenderTransform = New-Object Windows.Media.TranslateTransform(0, -3)
        if ($script:SelectedBorderBtn -ne $sender) {
            $sender.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnHoverBg')
            $sender.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnSelectedBg')
            if ($null -ne $sender.Tag -and $null -ne $sender.Tag.OpenLbl) {
                $sender.Tag.OpenLbl.Opacity = 1.0
                $sender.Tag.OpenLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnHoverText')
            }
        }
        $sender.Effect = New-SLTCabinShadow 22 5 0.30 '#000000'
    } catch {}
}
$script:SLTHubCardMouseLeave = {
    param($sender, $e)
    try {
        $sender.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)
        if ($script:SelectedBorderBtn -ne $sender) {
            $sender.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
            $sender.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
            if ($null -ne $sender.Tag -and $null -ne $sender.Tag.OpenLbl) {
                $sender.Tag.OpenLbl.Opacity = 0.78
                $sender.Tag.OpenLbl.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
            }
        }
        $sender.Effect = $null
    } catch {}
}
$script:SLTHubCardMouseUp = {
    param($sender, $e)
    if ($null -ne $sender.Tag) {
        Select-SLTBorderButton $sender $sender.Tag.Label
        if (-not [string]::IsNullOrWhiteSpace([string]$sender.Tag.Url)) {
            Open-SLTLink ([string]$sender.Tag.Url)
            Log-SLT ('SLT Smart Tools opened: ' + [string]$sender.Tag.Name + ' (' + [string]$sender.Tag.Url + ')')
        }
    }
}

# ========================== 6 SECTIONS (104 TOOLS - ALL DYNAMICALLY THEMED!) ==========================
foreach ($sec in $script:UltimateHubSections) {
    $secId    = [string]$sec.id
    $secTitle = [string]$sec.title
    $secCount = [int]$sec.count

    $secStack = New-Object Windows.Controls.StackPanel
    $secStack.Margin = [Windows.Thickness]::new(0,0,0,34)

    # Section Header: Accent H2 + Count Badge + Divider Line
    $secHdrGrid = New-Object Windows.Controls.Grid
    $secHdrGrid.Margin = [Windows.Thickness]::new(4,0,4,12)
    $cTitle = New-Object Windows.Controls.ColumnDefinition; $cTitle.Width = [Windows.GridLength]::Auto
    $cBadge = New-Object Windows.Controls.ColumnDefinition; $cBadge.Width = [Windows.GridLength]::Auto
    $cLine  = New-Object Windows.Controls.ColumnDefinition; $cLine.Width  = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $secHdrGrid.ColumnDefinitions.Add($cTitle)|Out-Null
    $secHdrGrid.ColumnDefinitions.Add($cBadge)|Out-Null
    $secHdrGrid.ColumnDefinitions.Add($cLine)|Out-Null

    $h2Tb = New-Object Windows.Controls.TextBlock
    $h2Tb.Text = $secTitle.ToUpperInvariant()
    $h2Tb.FontSize = 15.5; $h2Tb.FontWeight = 'Bold'
    $h2Tb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
    $h2Tb.VerticalAlignment = 'Center'
    $h2Tb.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $cntBadge = New-Object Windows.Controls.Border
    $cntBadge.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty, 'BtnRadius')
    $cntBadge.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
    $cntBadge.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
    $cntBadge.BorderThickness = [Windows.Thickness]::new(1)
    $cntBadge.Padding = [Windows.Thickness]::new(9,2,9,2)
    $cntBadge.Margin = [Windows.Thickness]::new(10,0,12,0)
    $cntBadge.VerticalAlignment = 'Center'
    $cntBadge.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $cntTxt = New-Object Windows.Controls.TextBlock
    $cntTxt.Text = [string]$secCount
    $cntTxt.FontSize = 11; $cntTxt.FontWeight = 'Bold'
    $cntTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
    $cntBadge.Child = $cntTxt
    $script:UltimateHubCountBadges[$secId] = $cntTxt

    $gradLine = New-Object Windows.Controls.Border
    $gradLine.Height = 1
    $gradLine.VerticalAlignment = 'Center'
    $gradLine.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardBorder')
    $gradLine.SetValue([Windows.Controls.Grid]::ColumnProperty, 2)

    $secHdrGrid.Children.Add($h2Tb)|Out-Null
    $secHdrGrid.Children.Add($cntBadge)|Out-Null
    $secHdrGrid.Children.Add($gradLine)|Out-Null
    $secStack.Children.Add($secHdrGrid)|Out-Null

    # 4-Column Grid of 92px Tool Cards (gap 12px -> Margin 6px around each card)
    $toolsGrid = New-Object Windows.Controls.Primitives.UniformGrid
    $toolsGrid.Columns = 4
    $toolsGrid.HorizontalAlignment = 'Stretch'

    $toolsArr = $sec.tools
    if ($toolsArr -is [array] -and $toolsArr.Count -eq 1 -and $toolsArr[0] -is [array]) {
        $toolsArr = $toolsArr[0]
    }

    foreach ($tool in $toolsArr) {
        $tName = [string]$tool.name
        $tUrl  = [string]$tool.url
        $tIcon = [string]$tool.icon

        $cardBdr = New-Object Windows.Controls.Border
        $cardBdr.MinHeight = 94
        $cardBdr.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty, 'BtnRadius')
        $cardBdr.Margin = [Windows.Thickness]::new(6)
        $cardBdr.Padding = [Windows.Thickness]::new(12,11,12,11)
        $cardBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'BtnBg')
        $cardBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BtnBorder')
        $cardBdr.BorderThickness = [Windows.Thickness]::new(1)
        $cardBdr.Cursor = [Windows.Input.Cursors]::Hand
        $cardBdr.ToolTip = "$tName`nDirect Link: $tUrl"
        $cardBdr.RenderTransform = New-Object Windows.Media.TranslateTransform(0, 0)

        $cardStack = New-Object Windows.Controls.StackPanel
        $cardStack.HorizontalAlignment = 'Center'
        $cardStack.VerticalAlignment = 'Center'

        # 36x36 Rounded [9px] Icon Box
        $icBox = New-Object Windows.Controls.Border
        $icBox.Width = 36; $icBox.Height = 36
        $icBox.CornerRadius = [Windows.CornerRadius]::new(9)
        $icBox.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
        $icBox.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $icBox.BorderThickness = [Windows.Thickness]::new(1)
        $icBox.HorizontalAlignment = 'Center'
        $icBox.Margin = [Windows.Thickness]::new(0,0,0,8)

        $icTxt = New-Object Windows.Controls.TextBlock
        $icTxt.Text = $tIcon
        $icTxt.HorizontalAlignment = 'Center'; $icTxt.VerticalAlignment = 'Center'
        $icTxt.TextAlignment = 'Center'
        if ($tIcon.Length -le 2 -and $tIcon -match '^[A-Za-z%]+$') {
            $icTxt.FontSize = 13
            $icTxt.FontWeight = 'Bold'
            $icTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
        } else {
            $icTxt.FontSize = 17.5
            $icTxt.FontWeight = 'SemiBold'
            $icTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        }
        $icBox.Child = $icTxt

        # Tool Name (12.5px SemiBold)
        $nameTb = New-Object Windows.Controls.TextBlock
        $nameTb.Text = $tName
        $nameTb.FontSize = 12.5; $nameTb.FontWeight = 'SemiBold'
        $nameTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'BtnText')
        $nameTb.HorizontalAlignment = 'Center'; $nameTb.TextAlignment = 'Center'
        $nameTb.TextTrimming = 'CharacterEllipsis'

        # "Open ->" Sub-label
        $openTb = New-Object Windows.Controls.TextBlock
        $openTb.Text = ('Open' + $neArrow)
        $openTb.FontSize = 10
        $openTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
        $openTb.Opacity = 0.78
        $openTb.HorizontalAlignment = 'Center'
        $openTb.Margin = [Windows.Thickness]::new(0,3,0,0)

        $cardStack.Children.Add($icBox)|Out-Null
        $cardStack.Children.Add($nameTb)|Out-Null
        $cardStack.Children.Add($openTb)|Out-Null
        $cardBdr.Child = $cardStack

        $cardBdr.Tag = @{ Url = $tUrl; Name = $tName; Label = $nameTb; OpenLbl = $openTb }

        $tTags = if ($null -ne $tool.PSObject.Properties['tags'] -and $tool.tags) { [string]$tool.tags } else { '' }
        $cardBdr.Add_MouseEnter($script:SLTHubCardMouseEnter)
        $cardBdr.Add_MouseLeave($script:SLTHubCardMouseLeave)
        $cardBdr.Add_MouseLeftButtonUp($script:SLTHubCardMouseUp)

        $toolsGrid.Children.Add($cardBdr)|Out-Null
        $script:UltimateHubCardList.Add([pscustomobject]@{
            SectionId     = $secId
            SecTitleLower = $secTitle.ToLowerInvariant()
            NameLower     = $tName.ToLowerInvariant()
            UrlLower      = $tUrl.ToLowerInvariant()
            TagsLower     = $tTags.ToLowerInvariant()
            Card          = $cardBdr
        })
    }

    $secStack.Children.Add($toolsGrid)|Out-Null
    $script:UltimateHubSectionBlocks[$secId] = $secStack
    $innerContainer.Children.Add($secStack)|Out-Null
}

# Wire Search Box Events
$script:UltimateHubSearchBox.Add_GotFocus({
    if ($null -ne $script:UltimateHubSearchPlaceholder) { $script:UltimateHubSearchPlaceholder.Visibility = 'Collapsed' }
    try { $script:UltimateHubSearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BtnSelectedBg') } catch {}
})
$script:UltimateHubSearchBox.Add_LostFocus({
    if ($null -ne $script:UltimateHubSearchPlaceholder -and [string]::IsNullOrEmpty($script:UltimateHubSearchBox.Text)) {
        $script:UltimateHubSearchPlaceholder.Visibility = 'Visible'
    }
    try { $script:UltimateHubSearchBox.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'InputBorder') } catch {}
})
$script:UltimateHubSearchBox.Add_TextChanged({
    Update-SLTHubFilterAndSearch
})
$script:UltimateHubSearchBox.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq 'Return' -or $e.Key -eq 'Enter') {
        $e.Handled = $true
        Update-SLTHubFilterAndSearch
    } elseif ($e.Key -eq 'Escape') {
        $e.Handled = $true
        $script:UltimateHubFilter = 'all'
        $script:UltimateHubSearchBox.Text = ''
        Update-SLTHubFilterAndSearch
    }
})

# ========================== BOTTOM CALLOUT CARD (Normal .slt-btn buttons - NOT permanently highlighted!) ==========================
$calloutInner = New-Object Windows.Controls.Border
$calloutInner.SetResourceReference([Windows.Controls.Border]::CornerRadiusProperty, 'CardRadius')
$calloutInner.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
$calloutInner.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$calloutInner.BorderThickness = [Windows.Thickness]::new(1.2)
$calloutInner.Padding = [Windows.Thickness]::new(24,18,24,18)
$calloutInner.Margin = [Windows.Thickness]::new(6,8,6,14)

$calloutGrid = New-Object Windows.Controls.Grid
$cc0 = New-Object Windows.Controls.ColumnDefinition; $cc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$cc1 = New-Object Windows.Controls.ColumnDefinition; $cc1.Width = [Windows.GridLength]::Auto
$calloutGrid.ColumnDefinitions.Add($cc0)|Out-Null; $calloutGrid.ColumnDefinitions.Add($cc1)|Out-Null

$calloutLeft = New-Object Windows.Controls.StackPanel; $calloutLeft.VerticalAlignment = 'Center'
$coTitle = New-Object Windows.Controls.TextBlock
$coTitle.Text = "SLT Smart Tools $emDash 104 Instant Direct Links Ready"
$coTitle.FontSize = 15.5; $coTitle.FontWeight = 'Bold'
$coTitle.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$coSub = New-Object Windows.Controls.TextBlock
$coSub.Text = 'Click any card above to open directly in your default browser (Unit Converter, Live XE Currency, BMI, Top 25 AI, Saudi Services & News).'
$coSub.FontSize = 12.5
$coSub.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$coSub.Margin = [Windows.Thickness]::new(0,4,0,0); $coSub.TextWrapping = 'Wrap'
$calloutLeft.Children.Add($coTitle)|Out-Null; $calloutLeft.Children.Add($coSub)|Out-Null
$calloutLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$calloutRight = New-Object Windows.Controls.StackPanel
$calloutRight.Orientation = 'Horizontal'; $calloutRight.VerticalAlignment = 'Center'

# Smart Life Teck Button (Normal .slt-btn by default, NOT permanently highlighted!)
$sltBrandBtn = New-Object Windows.Controls.Border
$sltBrandBtn.Padding = [Windows.Thickness]::new(15,7,15,7); $sltBrandBtn.Margin = [Windows.Thickness]::new(0,0,8,0)
$sltBrandTxt = New-Object Windows.Controls.TextBlock; $sltBrandTxt.Text = 'Smart Life Teck'; $sltBrandTxt.FontSize = 12; $sltBrandTxt.FontWeight = 'SemiBold'
$sltBrandBtn.Child = $sltBrandTxt
$sltBrandBtn.Tag = @{ Label = $sltBrandTxt }
Attach-SLTHubBtnBehavior $sltBrandBtn $sltBrandTxt
$sltBrandBtn.Add_MouseLeftButtonUp({
    param($s, $e)
    Select-SLTBorderButton $s $s.Tag.Label
    Open-SLTLink 'https://www.smartlifeteck.com'
})

# @smartlifeteck Button (Normal .slt-btn by default, NOT permanently highlighted!)
$sltHandlePill = New-Object Windows.Controls.Border
$sltHandlePill.Padding = [Windows.Thickness]::new(15,7,15,7)
$sltHandleTxt = New-Object Windows.Controls.TextBlock; $sltHandleTxt.Text = '@smartlifeteck'; $sltHandleTxt.FontSize = 12; $sltHandleTxt.FontWeight = 'SemiBold'
$sltHandlePill.Child = $sltHandleTxt
$sltHandlePill.Tag = @{ Label = $sltHandleTxt }
Attach-SLTHubBtnBehavior $sltHandlePill $sltHandleTxt
$sltHandlePill.Add_MouseLeftButtonUp({
    param($s, $e)
    Select-SLTBorderButton $s $s.Tag.Label
    Open-SLTLink 'https://www.smartlifeteck.com'
})

$calloutRight.Children.Add($sltBrandBtn)|Out-Null; $calloutRight.Children.Add($sltHandlePill)|Out-Null
$calloutRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

$calloutGrid.Children.Add($calloutLeft)|Out-Null; $calloutGrid.Children.Add($calloutRight)|Out-Null
$calloutInner.Child = $calloutGrid
$innerContainer.Children.Add($calloutInner)|Out-Null

$mainVertStack.Children.Add($innerContainer)|Out-Null

# ========================== FULL-WIDTH DYNAMIC FOOTER ==========================
$footerBorder = New-Object Windows.Controls.Border
$footerBorder.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'FooterBg')
$footerBorder.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$footerBorder.BorderThickness = [Windows.Thickness]::new(0,1,0,0)
$footerBorder.Padding = [Windows.Thickness]::new(22,24,22,28)
$footerBorder.Margin = [Windows.Thickness]::new(0,18,0,0)
$footerBorder.HorizontalAlignment = 'Stretch'

$footerInner = New-Object Windows.Controls.StackPanel
$footerInner.MaxWidth = 1150
$footerInner.HorizontalAlignment = 'Stretch'

# Line 1: Powered by Smart Life Teck - SLT AI Hub
$ftLine1 = New-Object Windows.Controls.TextBlock
$ftLine1.Text = "Powered by Smart Life Teck $emDash SLT AI Hub"
$ftLine1.FontSize = 16; $ftLine1.FontWeight = 'Bold'
$ftLine1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextAccent')
$ftLine1.HorizontalAlignment = 'Center'; $ftLine1.TextAlignment = 'Center'
$footerInner.Children.Add($ftLine1)|Out-Null

# Line 2: Smarter your digital life - 100+ Tools for Everyone - Saudi | Pakistan | World
$ftLine2 = New-Object Windows.Controls.TextBlock
$ftLine2.Text = "Smarter your digital life $emDash 100+ Tools for Everyone $bullet Saudi | Pakistan | World"
$ftLine2.FontSize = 13; $ftLine2.HorizontalAlignment = 'Center'; $ftLine2.TextAlignment = 'Center'
$ftLine2.Margin = [Windows.Thickness]::new(0,6,0,0)
$ftLine2.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$footerInner.Children.Add($ftLine2)|Out-Null

# Line 3: Website, WhatsApp, Email Direct Links
$contactRow = New-Object Windows.Controls.WrapPanel
$contactRow.HorizontalAlignment = 'Center'
$contactRow.Margin = [Windows.Thickness]::new(0,16,0,0)

$contactItems = @(
    @{ icon=([char]::ConvertFromUtf32(0x1F310)); text='Website: www.smartlifeteck.com';  url='https://www.smartlifeteck.com' },
    @{ icon=([char]::ConvertFromUtf32(0x1F4AC)); text='WhatsApp: +966 55 376 0854';      url='https://wa.me/966553760854' },
    @{ icon=([char]0x2709);                      text='Email: info@smartlifeteck.com';   url='mailto:info@smartlifeteck.com' }
)

foreach ($ci in $contactItems) {
    $cWrap = New-Object Windows.Controls.Border
    $cWrap.Padding = [Windows.Thickness]::new(14,7,14,7)
    $cWrap.Margin = [Windows.Thickness]::new(5,3,5,3)
    $cTb = New-Object Windows.Controls.TextBlock
    $cTb.Text = ([string]$ci.icon + '  ' + [string]$ci.text)
    $cTb.FontSize = 12.2; $cTb.FontWeight = 'SemiBold'
    $cWrap.Child = $cTb
    $cWrap.Tag = @{ Url = [string]$ci.url; Label = $cTb }
    Attach-SLTHubBtnBehavior $cWrap $cTb
    $cWrap.Add_MouseLeftButtonUp({
        param($sender, $e)
        Select-SLTBorderButton $sender $sender.Tag.Label
        $u = [string]$sender.Tag.Url
        if ($u -match '^mailto:') { Start-Process $u } else { Open-SLTLink $u }
    })
    $contactRow.Children.Add($cWrap)|Out-Null
}
$footerInner.Children.Add($contactRow)|Out-Null

# Line 4: ALL 5 Social Pills Clickable (YouTube, TikTok, X, Instagram, Facebook - Unified .slt-btn!)
$socialRow = New-Object Windows.Controls.WrapPanel
$socialRow.HorizontalAlignment = 'Center'
$socialRow.Margin = [Windows.Thickness]::new(0,12,0,0)

$socialLinks = @(
    @{ badge=([char]0x25B6); name='YouTube @smartlifeteck';   url='https://www.youtube.com/@smartlifeteck' },
    @{ badge=([char]0x266A); name='TikTok @smartlifeteck';    url='https://www.tiktok.com/@smartlifeteck' },
    @{ badge=([char]0x25C6); name='Snapchat @smartlifeteck';  url='https://www.snapchat.com/add/smartlifeteck' },
    @{ badge=([char]0x25CE); name='Instagram @smartlifeteck'; url='https://www.instagram.com/smartlifeteck/' },
    @{ badge='f';            name='Facebook @smartlifeteck';  url='https://www.facebook.com/SmartLIfeTeck' },
    @{ badge='X';            name='X @smartlifeteck';         url='https://x.com/smartlifeteck' }
)

foreach ($sl in $socialLinks) {
    $sPill = New-Object Windows.Controls.Border
    $sPill.Padding = [Windows.Thickness]::new(14,7,14,7)
    $sPill.Margin = [Windows.Thickness]::new(5,4,5,4)
    $sPill.ToolTip = ('Open ' + [string]$sl.name + ' (' + [string]$sl.url + ')')
    $sLbl = New-Object Windows.Controls.TextBlock
    $sLbl.Text = ([string]$sl.badge + '  ' + [string]$sl.name)
    $sLbl.FontSize = 12.2; $sLbl.FontWeight = 'SemiBold'
    $sPill.Child = $sLbl
    $sPill.Tag = @{ Url = [string]$sl.url; Label = $sLbl }
    Attach-SLTHubBtnBehavior $sPill $sLbl
    $sPill.Add_MouseLeftButtonUp({
        param($s, $e)
        Select-SLTBorderButton $s $s.Tag.Label
        Open-SLTLink ([string]$s.Tag.Url)
    })
    $socialRow.Children.Add($sPill)|Out-Null
}
$footerInner.Children.Add($socialRow)|Out-Null

# Line 5: Bottom Copyright Row
$copyBorder = New-Object Windows.Controls.Border
$copyBorder.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
$copyBorder.BorderThickness = [Windows.Thickness]::new(0,1,0,0)
$copyBorder.Margin = [Windows.Thickness]::new(0,20,0,0)
$copyBorder.Padding = [Windows.Thickness]::new(4,14,4,0)

$copyGrid = New-Object Windows.Controls.Grid
$cg0 = New-Object Windows.Controls.ColumnDefinition; $cg0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
$cg1 = New-Object Windows.Controls.ColumnDefinition; $cg1.Width = [Windows.GridLength]::Auto
$copyGrid.ColumnDefinitions.Add($cg0)|Out-Null; $copyGrid.ColumnDefinitions.Add($cg1)|Out-Null

$copyLeft = New-Object Windows.Controls.TextBlock
$copyLeft.Text = "$copyChr 2026 Smart Life Teck $emDash All tools open directly, no login required."
$copyLeft.FontSize = 11.2
$copyLeft.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$copyLeft.VerticalAlignment = 'Center'
$copyLeft.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

$copyRight = New-Object Windows.Controls.StackPanel; $copyRight.Orientation = 'Horizontal'; $copyRight.VerticalAlignment = 'Center'
$smDot = New-Object Windows.Controls.Border; $smDot.Width = 6; $smDot.Height = 6; $smDot.CornerRadius = [Windows.CornerRadius]::new(3)
$smDot.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'TextAccent')
$smDot.Margin = [Windows.Thickness]::new(0,0,7,0); $smDot.VerticalAlignment = 'Center'
$copyRightTxt = New-Object Windows.Controls.TextBlock
$copyRightTxt.Text = "Built with $heartChr for Saudi, Pakistan & World Users $bullet 104 Tools Live"
$copyRightTxt.FontSize = 11.2
$copyRightTxt.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextSecondary')
$copyRightTxt.VerticalAlignment = 'Center'
$copyRight.Children.Add($smDot)|Out-Null; $copyRight.Children.Add($copyRightTxt)|Out-Null
$copyRight.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)

$copyGrid.Children.Add($copyLeft)|Out-Null; $copyGrid.Children.Add($copyRight)|Out-Null
$copyBorder.Child = $copyGrid
$footerInner.Children.Add($copyBorder)|Out-Null

$footerBorder.Child = $footerInner
$mainVertStack.Children.Add($footerBorder)|Out-Null

$hubRootGrid.Children.Add($mainVertStack)|Out-Null
$page.Children.Add($hubRootGrid)|Out-Null

Set-Item -Path Function:\global:Attach-SLTHubBtnBehavior -Value ${function:Attach-SLTHubBtnBehavior}
Set-Item -Path Function:\global:Open-SLTHubWebViewWindow -Value ${function:Open-SLTHubWebViewWindow}
Set-Item -Path Function:\global:New-SLTHubDesktopShortcut -Value ${function:New-SLTHubDesktopShortcut}
Set-Item -Path Function:\global:Update-SLTHubFilterAndSearch -Value ${function:Update-SLTHubFilterAndSearch}
Set-Item -Path Function:\global:Set-SLTHubCategoryFilter -Value ${function:Set-SLTHubCategoryFilter}
Set-Item -Path Function:\global:Update-SLTHubThemeVisuals -Value ${function:Update-SLTHubThemeVisuals}
