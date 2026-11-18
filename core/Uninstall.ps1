# ==============================================================================
# core/Uninstall.ps1
# SLT Smart PC Boost v1.0.0 - Verified Background Uninstall (Zero Fake Success, Zero UI Hang)
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# ==============================================================================

function Confirm-SLTUninstallModal([string]$TitleText, [string]$MessageText) {
    # Mandatory Confirmation Modal: "Are you sure?" + App Name + [Cancel] [Uninstall]
    $script:ConfirmDialogResult = $false
    try {
        $dlg = New-Object Windows.Window
        $dlg.Title = $TitleText
        $dlg.Width = 520
        $dlg.Height = 250
        $dlg.WindowStartupLocation = 'CenterOwner'
        try {
            if ($null -ne $script:Window -and $script:Window.IsVisible) {
                $dlg.Owner = $script:Window
            }
        } catch {}
        $dlg.ResizeMode = 'NoResize'
        $dlg.Topmost = $true
        Apply-SLTDialogTheme $dlg

        $conv = [Windows.Media.BrushConverter]::new()
        $outer = New-Object Windows.Controls.Grid
        $outer.Margin = [Windows.Thickness]::new(22, 18, 22, 16)
        $r0 = New-Object Windows.Controls.RowDefinition; $r0.Height = [Windows.GridLength]::Auto
        $r1 = New-Object Windows.Controls.RowDefinition; $r1.Height = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $r2 = New-Object Windows.Controls.RowDefinition; $r2.Height = [Windows.GridLength]::Auto
        $outer.RowDefinitions.Add($r0) | Out-Null
        $outer.RowDefinitions.Add($r1) | Out-Null
        $outer.RowDefinitions.Add($r2) | Out-Null

        $hdr = New-Object Windows.Controls.TextBlock
        $hdr.Text = $TitleText
        $hdr.FontSize = 16.5
        $hdr.FontWeight = 'Bold'
        $hdr.Foreground = $conv.ConvertFromString('#F87171')
        $hdr.TextTrimming = 'CharacterEllipsis'
        $hdr.SetValue([Windows.Controls.Grid]::RowProperty, 0)
        $outer.Children.Add($hdr) | Out-Null

        $msgBdr = New-Object Windows.Controls.Border
        $msgBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
        $msgBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $msgBdr.BorderThickness = [Windows.Thickness]::new(1)
        $msgBdr.CornerRadius = [Windows.CornerRadius]::new(10)
        $msgBdr.Padding = [Windows.Thickness]::new(14, 12, 14, 12)
        $msgBdr.Margin = [Windows.Thickness]::new(0, 10, 0, 12)
        $msgTb = New-Object Windows.Controls.TextBlock
        $msgTb.Text = $MessageText
        $msgTb.FontSize = 13
        $msgTb.TextWrapping = 'Wrap'
        $msgTb.VerticalAlignment = 'Center'
        $msgTb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
        $msgBdr.Child = $msgTb
        $msgBdr.SetValue([Windows.Controls.Grid]::RowProperty, 1)
        $outer.Children.Add($msgBdr) | Out-Null

        $btnRow = New-Object Windows.Controls.StackPanel
        $btnRow.Orientation = 'Horizontal'
        $btnRow.HorizontalAlignment = 'Right'

        $btnCancel = New-Object Windows.Controls.Button
        $btnCancel.Content = 'Cancel'
        $btnCancel.Style = $script:Window.FindResource('OutlineButton')
        $btnCancel.Width = 115
        $btnCancel.Height = 38
        $btnCancel.MinHeight = 38
        $btnCancel.FontWeight = 'SemiBold'
        $btnCancel.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
        $btnCancel.Background = $conv.ConvertFromString('#334155')
        $btnCancel.Foreground = $conv.ConvertFromString('#F8FAFC')
        $btnCancel.BorderBrush = $conv.ConvertFromString('#64748B')
        $btnCancel.IsCancel = $true
        $btnCancel.Tag = $dlg
        $btnCancel.Add_Click({
            param($s, $e)
            $script:ConfirmDialogResult = $false
            try { $s.Tag.Close() } catch {}
        })

        $btnUninstall = New-Object Windows.Controls.Button
        $btnUninstall.Content = 'Uninstall'
        $btnUninstall.Style = $script:Window.FindResource('ActionButton')
        $btnUninstall.Width = 130
        $btnUninstall.Height = 38
        $btnUninstall.MinHeight = 38
        $btnUninstall.FontWeight = 'Bold'
        $btnUninstall.Background = $conv.ConvertFromString('#DC2626')
        $btnUninstall.Foreground = $conv.ConvertFromString('#FFFFFF')
        $btnUninstall.BorderBrush = $conv.ConvertFromString('#EF4444')
        $btnUninstall.IsDefault = $true
        $btnUninstall.Tag = $dlg
        $btnUninstall.Add_Click({
            param($s, $e)
            $script:ConfirmDialogResult = $true
            try { $s.Tag.Close() } catch {}
        })

        $btnRow.Children.Add($btnCancel) | Out-Null
        $btnRow.Children.Add($btnUninstall) | Out-Null
        $btnRow.SetValue([Windows.Controls.Grid]::RowProperty, 2)
        $outer.Children.Add($btnRow) | Out-Null

        $dlg.Add_KeyDown({
            param($s, $e)
            try {
                if ($e.Key -eq 'Escape') {
                    $script:ConfirmDialogResult = $false
                    $s.Close()
                }
            } catch {}
        })

        $dlg.Content = $outer
        [void]$dlg.ShowDialog()
        return [bool]$script:ConfirmDialogResult
    } catch {
        try {
            $res = [Windows.MessageBox]::Show($MessageText, $TitleText, 'YesNo', 'Warning')
            return ($res -eq 'Yes')
        } catch {
            return $false
        }
    }
}
Set-Item -Path Function:\global:Confirm-SLTUninstallModal -Value ${function:Confirm-SLTUninstallModal}

function Invoke-SLTForceKillProcesses([string]$TargetAppName = '') {
    # Fast, non-blocking process kill before uninstall
    $lockProcs = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($TargetAppName)) {
        $cleanT = ($TargetAppName -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
        if ($cleanT.Length -ge 3) { $lockProcs.Add($cleanT) }
        if ($cleanT -match 'anydesk')   { $lockProcs.Add('AnyDesk') }
        if ($cleanT -match 'rufus')     { $lockProcs.Add('rufus') }
        if ($cleanT -match 'ccleaner')  { $lockProcs.Add('CCleaner'); $lockProcs.Add('CCleaner64'); $lockProcs.Add('CCleanerAgent') }
        if ($cleanT -match 'chrome')    { $lockProcs.Add('chrome') }
        if ($cleanT -match 'brave')     { $lockProcs.Add('brave') }
        if ($cleanT -match 'firefox')   { $lockProcs.Add('firefox') }
        if ($cleanT -match 'vlc')       { $lockProcs.Add('vlc') }
        if ($cleanT -match 'filezilla') { $lockProcs.Add('filezilla') }
        if ($cleanT -match 'teams')     { $lockProcs.Add('Teams'); $lockProcs.Add('ms-teams'); $lockProcs.Add('Update') }
        if ($cleanT -match 'xbox')      { $lockProcs.Add('XboxPcApp'); $lockProcs.Add('XboxPcAppFT'); $lockProcs.Add('GameBar') }
        if ($cleanT -match 'discord')   { $lockProcs.Add('Discord'); $lockProcs.Add('Update') }
        if ($cleanT -match 'telegram')  { $lockProcs.Add('Telegram') }
        if ($cleanT -match 'whatsapp')  { $lockProcs.Add('WhatsApp') }
        if ($cleanT -match 'zoom')      { $lockProcs.Add('Zoom'); $lockProcs.Add('CptHost') }
        if ($cleanT -match 'steam')     { $lockProcs.Add('steam'); $lockProcs.Add('steamwebhelper') }
        if ($cleanT -match 'spotify')   { $lockProcs.Add('Spotify') }
    }
    foreach ($pName in $lockProcs) {
        try {
            Get-Process -Name ($pName + '*') -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}
Set-Item -Path Function:\global:Invoke-SLTForceKillProcesses -Value ${function:Invoke-SLTForceKillProcesses}

function Remove-SLTUninstalledFromMemory([object[]]$Packages) {
    # Removes ONLY verified uninstalled packages from memory lists and updates UI counts immediately
    try {
        $removedNames = @{}
        $removedKeys  = @{}
        $removedRowIds = @{}
        foreach ($pk in @($Packages)) {
            if ($null -eq $pk) { continue }
            $k = if ($pk -is [hashtable]) { [string]$pk['key'] } elseif ($pk.PSObject.Properties['key']) { [string]$pk.key } else { '' }
            $n = if ($pk -is [hashtable]) { [string]$pk['name'] } elseif ($pk.PSObject.Properties['name']) { [string]$pk.name } else { '' }
            $rId = if ($pk -is [hashtable] -and $pk.ContainsKey('row_id')) { [string]$pk['row_id'] } elseif ($pk.PSObject.Properties['row_id']) { [string]$pk.row_id } else { '' }
            if ($rId) {
                $removedRowIds[$rId] = $true
                if ($null -ne $script:UninstallSelectedMap -and $script:UninstallSelectedMap.ContainsKey($rId)) {
                    $null = $script:UninstallSelectedMap.Remove($rId)
                }
            }
            if ($k) {
                $removedKeys[$k] = $true
                if ($null -ne $script:ScannedInstalledApps -and $script:ScannedInstalledApps.ContainsKey($k)) {
                    $null = $script:ScannedInstalledApps.Remove($k)
                }
            }
            if ($n) { $removedNames[$n.ToLowerInvariant()] = $true }
        }
        $script:RealScanWindowsApps  = @($script:RealScanWindowsApps  | Where-Object { $_ -and (-not $removedRowIds.ContainsKey([string]$_.RowId)) -and (-not $removedNames.ContainsKey(([string]$_.Name).ToLowerInvariant())) })
        $script:RealScanCustomerApps = @($script:RealScanCustomerApps | Where-Object { $_ -and (-not $removedRowIds.ContainsKey([string]$_.RowId)) -and (-not $removedNames.ContainsKey(([string]$_.Name).ToLowerInvariant())) })
        $script:RealScanSltApps      = @($script:RealScanSltApps      | Where-Object { $_ -and (-not $removedRowIds.ContainsKey([string]$_.RowId)) -and (-not $removedNames.ContainsKey(([string]$_.Name).ToLowerInvariant())) -and (-not $removedKeys.ContainsKey([string]$_.SltKey)) })
        $script:RealScanAllApps      = @($script:RealScanWindowsApps + $script:RealScanCustomerApps + $script:RealScanSltApps)
        $script:TotalPcInstalledCount = $script:RealScanAllApps.Count

        if (Get-Command Invoke-SLTUpdateAllScanUIs -ErrorAction SilentlyContinue) {
            Invoke-SLTUpdateAllScanUIs
        }
        if (Get-Command Render-SLTUninstallModeView -ErrorAction SilentlyContinue) {
            Render-SLTUninstallModeView
        }
        if (Get-Command Update-SLTUninstallCounter -ErrorAction SilentlyContinue) {
            Update-SLTUninstallCounter
        }
        if (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue) {
            Render-SLTAppCatalog
        }
        if (Get-Command Update-SLTStatusLine -ErrorAction SilentlyContinue) {
            Update-SLTStatusLine
        }
    } catch {}
}
Set-Item -Path Function:\global:Remove-SLTUninstalledFromMemory -Value ${function:Remove-SLTUninstalledFromMemory}

function BulkUninstallForce([object[]]$Packages) {
    if ($null -eq $Packages -or @($Packages).Count -eq 0) { return $false }
    $pkgArr = @($Packages)
    $cnt = $pkgArr.Count
    $nameList = New-Object System.Collections.Generic.List[string]
    foreach ($item in ($pkgArr | Select-Object -First 6)) {
        $nm = if ($item -is [hashtable]) { [string]$item['name'] } elseif ($item.PSObject.Properties['name']) { [string]$item.name } else { 'App' }
        if (-not [string]::IsNullOrWhiteSpace($nm)) { $nameList.Add($nm) }
    }
    $firstNames = ($nameList -join ', ')
    if ($cnt -gt 6) { $firstNames += " + $($cnt - 6) more" }

    $confirmed = Confirm-SLTUninstallModal -TitleText "Are you sure? - Uninstall $cnt Selected App(s)" -MessageText "Are you sure you want to uninstall $cnt selected application(s) from this PC?`n`n$firstNames"
    if (-not $confirmed) { return $false }

    # Do NOT pre-remove apps from memory before verification!
    # The background worker uninstalls each app (60s timeout) and verifies Registry + WinGet + Appx removal first.
    if (Get-Command Sync-SLTPackageWorkerScript -ErrorAction SilentlyContinue) { Sync-SLTPackageWorkerScript }
    Start-SLTQueue -Packages $pkgArr -Verb 'Uninstall' -Manager 'WinGet' -OfflineCache $false -AutoUpgrade $false
    return $true
}
Set-Item -Path Function:\global:BulkUninstallForce -Value ${function:BulkUninstallForce}
