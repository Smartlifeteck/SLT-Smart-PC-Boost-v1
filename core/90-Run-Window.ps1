# SLT Smart PC Boost v1.0.0 - Safe Main Window Runner with Null/Content/Init Guards & Emergency Fallback Window
$script:DevUnlockedSession = $true

function Show-SLTEmergencyFallbackWindow([string]$ErrorDetails, [string]$ErrorFile) {
    try {
        Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction SilentlyContinue
        $emWin = New-Object Windows.Window
        $emWin.Title = 'SLT Smart PC Boost v1.0.0 - Emergency Recovery Window (Smart Life Teck)'
        $emWin.Width = 720
        $emWin.Height = 460
        $emWin.WindowStartupLocation = 'CenterScreen'
        $emWin.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#0E2A22')
        $emWin.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#F4EAD7')
        $emWin.FontFamily = 'Segoe UI'

        $sp = New-Object Windows.Controls.StackPanel
        $sp.Margin = [Windows.Thickness]::new(24)

        $h1 = New-Object Windows.Controls.TextBlock
        $h1.Text = 'SLT Smart PC Boost v1.0.0 - Startup Diagnostic & Recovery'
        $h1.FontSize = 20
        $h1.FontWeight = 'Bold'
        $h1.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#E4C158')
        $sp.Children.Add($h1) | Out-Null

        $sub = New-Object Windows.Controls.TextBlock
        $sub.Text = 'An unexpected UI error occurred. Diagnostic log has been saved to C:\ProgramData\SmartLifeTeck\PCCarePro\Logs.'
        $sub.FontSize = 12.5
        $sub.Margin = [Windows.Thickness]::new(0,6,0,12)
        $sub.TextWrapping = 'Wrap'
        $sp.Children.Add($sub) | Out-Null

        $tb = New-Object Windows.Controls.TextBox
        $tb.Text = $ErrorDetails
        $tb.Height = 250
        $tb.IsReadOnly = $true
        $tb.TextWrapping = 'Wrap'
        $tb.VerticalScrollBarVisibility = 'Auto'
        $tb.FontFamily = 'Consolas'
        $tb.FontSize = 11.5
        $tb.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#0A1F18')
        $tb.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#ECFDF5')
        $tb.Padding = [Windows.Thickness]::new(10)
        $sp.Children.Add($tb) | Out-Null

        $btnRow = New-Object Windows.Controls.StackPanel
        $btnRow.Orientation = 'Horizontal'
        $btnRow.HorizontalAlignment = 'Right'
        $btnRow.Margin = [Windows.Thickness]::new(0,14,0,0)

        $openLogsBtn = New-Object Windows.Controls.Button
        $openLogsBtn.Content = 'Open Logs Folder'
        $openLogsBtn.Padding = [Windows.Thickness]::new(14,6,14,6)
        $openLogsBtn.Margin = [Windows.Thickness]::new(0,0,10,0)
        $openLogsBtn.Add_Click({
            try { Start-Process explorer.exe 'C:\ProgramData\SmartLifeTeck\PCCarePro\Logs' } catch {}
        })
        $btnRow.Children.Add($openLogsBtn) | Out-Null

        $closeBtn = New-Object Windows.Controls.Button
        $closeBtn.Content = 'Close'
        $closeBtn.Padding = [Windows.Thickness]::new(18,6,18,6)
        $closeBtn.Add_Click({ $emWin.Close() }.GetNewClosure())
        $btnRow.Children.Add($closeBtn) | Out-Null

        $sp.Children.Add($btnRow) | Out-Null
        $emWin.Content = $sp
        [void]$emWin.ShowDialog()
    } catch {}
}

try {
    $logDir = 'C:\ProgramData\SmartLifeTeck\PCCarePro\Logs'
    try {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    if ($null -eq $script:Root -or [string]::IsNullOrWhiteSpace($script:Root)) {
        $script:Root = Split-Path -Parent $PSScriptRoot
    }
    if ($null -eq $script:Window) {
        Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction SilentlyContinue
        $xamlPath = Join-Path $script:Root 'ui\Main.xaml'
        if (Test-Path -LiteralPath $xamlPath) {
            [xml]$xamlFallback = Get-Content -LiteralPath $xamlPath -Raw
            $readerFallback = New-Object System.Xml.XmlNodeReader $xamlFallback
            $script:Window = [Windows.Markup.XamlReader]::Load($readerFallback)
        }
    }

    $window = $script:Window
    if ($null -eq $window) {
        throw 'XAML Load null'
    }
    if ($null -eq $window.Content) {
        throw 'XAML Window.Content is null'
    }
    if (-not $window.IsInitialized) {
        if ($window.PSObject.Methods['InitializeComponent']) {
            try { $window.InitializeComponent() } catch {}
        }
        try { $window.UpdateLayout() } catch {}
    }

    try {
        $window.Dispatcher.Add_UnhandledException({
            param($sender, $ev)
            try {
                Log-SLT ('Dispatcher guarded UI exception: ' + $ev.Exception.Message)
            } catch {}
            $ev.Handled = $true
        })
    } catch {}

    Switch-SLTPage 0
    $window.WindowState = 'Maximized'
    $window.Add_ContentRendered({
        if (-not $script:SLTStartupForegroundDone) {
            $script:SLTStartupForegroundDone = $true
            try { if (Get-Command Invoke-SLTMainWindowForeground -ErrorAction SilentlyContinue) { Invoke-SLTMainWindowForeground } } catch {}
            try { if (Get-Command Close-SLTSplash -ErrorAction SilentlyContinue) { Close-SLTSplash } } catch {}
            try { $script:Window.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Background, [action]{ try { if (Get-Command Invoke-SLTMainWindowForeground -ErrorAction SilentlyContinue) { Invoke-SLTMainWindowForeground } } catch {} }) | Out-Null } catch {}
        }
        try {
            if (Get-Command Invoke-SLTDashboardLiveRefresh -ErrorAction SilentlyContinue) {
                Invoke-SLTDashboardLiveRefresh
            }
        } catch {
            Log-SLT ('Initial system info unavailable: ' + $_.Exception.Message)
        }
    })
    $window.Add_Closing({
        try {
            if (($script:BoostScannedOnce -or $script:BoostHealthRestored) -and (-not $script:HealthIsFixing)) {
                if (Get-Command Save-SLTBoostHealthResult -ErrorAction SilentlyContinue) { Save-SLTBoostHealthResult }
            }
        } catch {}
    })

    Log-SLT 'SLT Smart PC Boost v1.0.0 started - Powered by Smart Life Teck (www.smartlifeteck.com) | Developed by Shahzad Babar.'
    if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'Main window verified non-null - showing (ShowDialog)' }

    # Final null check before ShowDialog
    if ($null -eq $window -or $null -eq $window.Content) {
        throw 'Final check failed: Window or Window.Content is null before ShowDialog'
    }
    [void]$window.ShowDialog()

    if (Get-Command Add-SLTStartupStage -ErrorAction SilentlyContinue) { Add-SLTStartupStage 'Main window closed normally' }
} catch {
    $err = $_
    try { if (Get-Command Close-SLTSplash -ErrorAction SilentlyContinue) { Close-SLTSplash } } catch {}
    $logDir = 'C:\ProgramData\SmartLifeTeck\PCCarePro\Logs'
    $errFile = ''
    $errText = "SLT Smart PC Boost Window Error`r`nWhen: $((Get-Date).ToString('s'))`r`nMessage: $($err.Exception.Message)`r`nSource: $($err.InvocationInfo.ScriptName)`r`nLine: $($err.InvocationInfo.ScriptLineNumber)`r`nStack: $($err.ScriptStackTrace)"
    try {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
        $errFile = Join-Path $logDir ('STARTUP_ERROR_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
        [IO.File]::WriteAllText($errFile, $errText, [Text.Encoding]::UTF8)
    } catch {}
    Show-SLTEmergencyFallbackWindow -ErrorDetails $errText -ErrorFile $errFile
}
