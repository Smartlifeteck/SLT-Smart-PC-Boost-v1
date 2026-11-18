# ==============================================================================
# core/Notification.ps1
# SLT Smart PC Boost v1.0.0 - Real + Persistent Status Result Banner & Sound Engine
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# ==============================================================================

function Play-SLTSuccessChime {
    # Audible 4-note ascending chime (523Hz -> 659Hz -> 784Hz -> 1046Hz) - played ONLY when $OkCount -gt 0
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
    try {
        $psAudio = [PowerShell]::Create()
        [void]$psAudio.AddScript({
            try {
                [Console]::Beep(523, 160)
                [Console]::Beep(659, 160)
                [Console]::Beep(784, 160)
                [Console]::Beep(1046, 240)
            } catch {}
            try {
                $sampleRate = 22050
                $notes = @(
                    @{ Freq = 523.25; DurMs = 120 },
                    @{ Freq = 659.25; DurMs = 120 },
                    @{ Freq = 783.99; DurMs = 120 },
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
                        $env = [Math]::Exp(-3.6 * ([double]$i / [double]$sCount))
                        $val = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * $env * 0.7
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
        try { [Console]::Beep(523,160); [Console]::Beep(659,160); [Console]::Beep(784,160); [Console]::Beep(1046,240) } catch {}
    }
}
Set-Item -Path Function:\global:Play-SLTSuccessChime -Value ${function:Play-SLTSuccessChime}

function Play-SLTUninstallTone {
    # Audible 2-note descending tone (659Hz -> 523Hz) - played ONLY when $OkCount -gt 0
    try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
    try {
        $psAudio = [PowerShell]::Create()
        [void]$psAudio.AddScript({
            try {
                [Console]::Beep(659, 160)
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
                        $env = [Math]::Exp(-3.6 * ([double]$i / [double]$sCount))
                        $val = [Math]::Sin(2.0 * [Math]::PI * $freq * $t) * $env * 0.7
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
        try { [Console]::Beep(659,160); [Console]::Beep(523,240) } catch {}
    }
}
Set-Item -Path Function:\global:Play-SLTUninstallTone -Value ${function:Play-SLTUninstallTone}

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
                if ($OkCount -gt 0) {
                    $headline = if ($FailCount -eq 0) {
                        "$sparkle WOW! $OkCount Apps Successfully Uninstalled - Thanks for Smart Life Teck | Shahzad Babar www.smartlifeteck.com"
                    } else {
                        "$chkIcon $OkCount Apps Successfully Uninstalled | $crossIcon $FailCount Failed"
                    }
                    $detailLines = New-Object System.Collections.Generic.List[string]
                    $detailLines.Add("$chkIcon $OkCount Apps Successfully Uninstalled")
                    if ($FailCount -gt 0) { $detailLines.Add("$crossIcon $FailCount Apps Failed - Try Again") }
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
                    $detailLines.Add("$crossIcon $FailCount Apps Failed to Uninstall")
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
                # Install Mode
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
