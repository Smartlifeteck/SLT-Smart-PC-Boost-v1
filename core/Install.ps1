# ==============================================================================
# core/Install.ps1
# SLT Smart PC Boost v1.0.0 - Smart Install Mode Logic & Worker Sync
# Powered by Smart Life Teck | Developed by Shahzad Babar (www.smartlifeteck.com)
# ==============================================================================

function Get-SLTVerifiedWingetIdMap {
    return @{
        'a_google_chrome'                     = 'Google.Chrome'
        'a_google_googledrive'                = 'Google.GoogleDrive'
        'a_piriform_ccleaner'                 = 'Piriform.CCleaner'
        'a_bytedance_capcut'                  = 'ByteDance.CapCut'
        'a_cisco_webexteams'                  = 'Cisco.Webex'
        'a_microsoft_xbox'                    = '9MV0B5HZVK9Z'
        'a_aomei_partitionassistant_standard' = 'AOMEI.PartitionAssistant'
        'a_apachefriends_xampp'               = 'ApacheFriends.Xampp.8.2'
        'a_files_community_files'             = 'FilesCommunity.Files'
        'a_gimp_gimp'                         = 'GIMP.GIMP.3'
        'a_easeus_datarecoverywizard'         = 'EaseUS.DataRecoveryWizard'
        'a_paramount_macriumreflect_free'     = 'Paramount.MacriumReflect.Free'
        'a_filezilla_client'                  = 'FileZilla.Client'
        'b_autoruns'                          = 'Microsoft.Sysinternals.Autoruns'
        'b_bleachbit'                         = 'BleachBit.BleachBit'
        'b_display_driver_uninstaller'        = 'Wagnardsoft.DisplayDriverUninstaller'
        'b_driver_booster'                    = 'IObit.DriverBooster'
        'b_filmora'                           = 'Wondershare.Filmora'
        'b_furmark'                           = 'Geeks3D.FurMark.2'
        'b_iobit_uninstaller'                 = 'IObit.Uninstaller'
        'b_minitool_partition_wizard'         = 'MiniTool.PartitionWizard.Free'
        'b_o_o_shutup10'                      = 'OO-Software.ShutUp10'
        'b_prime95'                           = 'MersenneResearch.Prime95'
        'b_process_explorer'                  = 'Microsoft.Sysinternals.ProcessExplorer'
        'b_retroarch'                         = 'Libretro.RetroArch'
        'b_snappy_driver_installer_origin'    = 'GlennDelahoy.SnappyDriverInstallerOrigin'
        'b_splashtop_business'                = 'Splashtop.SplashtopBusiness'
        'b_startallback'                      = 'StartIsBack.StartAllBack'
        'b_ultraviewer'                       = 'DucFabulous.UltraViewer'
        'b_visual_studio_community'           = 'Microsoft.VisualStudio.2022.Community'
        'b_winaero_tweaker'                   = 'Winaero.Tweaker'
    }
}

function Sync-SLTCatalogWingetIds {
    try {
        $idMap = Get-SLTVerifiedWingetIdMap
        if ($null -ne $script:AppRecords) {
            foreach ($rec in $script:AppRecords) {
                if ($null -eq $rec) { continue }
                $k = [string]$rec.Key
                if ($idMap.ContainsKey($k)) {
                    $rec.Winget = [string]$idMap[$k]
                }
            }
        }
        if ($null -ne $script:AppIndex) {
            foreach ($k in @($idMap.Keys)) {
                if ($script:AppIndex.ContainsKey($k)) {
                    $script:AppIndex[$k].Winget = [string]$idMap[$k]
                }
            }
        }
    } catch {}
}

function Sync-SLTPackageWorkerScript {
    # Worker script lives directly at tools/Run-SLT-Packages.ps1 in the clean Open Workspace
    return
}

function Test-SLTAppIsAlreadyInstalled([string]$Key) {
    if ($null -ne $script:ScannedInstalledApps -and $script:ScannedInstalledApps.ContainsKey($Key)) {
        return $true
    }
    return $false
}

function Get-SLTSelectedNewAppsList {
    $newKeys = New-Object System.Collections.Generic.List[string]
    foreach ($k in @($script:SelectedApps.Keys)) {
        if (-not $script:SelectedApps[[string]$k]) { continue }
        if ($script:WebOnlyKeys.ContainsKey([string]$k)) { continue }
        if (-not (Test-SLTAppIsAlreadyInstalled ([string]$k))) {
            $newKeys.Add([string]$k)
        }
    }
    return $newKeys.ToArray()
}

function Select-SLTEssentialNewApps {
    try {
        if ($null -eq $script:AppRecords) { return 0 }
        $added = 0
        foreach ($rec in $script:AppRecords) {
            if ($null -eq $rec -or -not $rec.Essential) { continue }
            $k = [string]$rec.Key
            if ($script:WebOnlyKeys.ContainsKey($k)) { continue }
            if (-not (Test-SLTAppIsAlreadyInstalled $k)) {
                $script:SelectedApps[$k] = $true
                $added++
            }
        }
        if (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue) { Render-SLTAppCatalog }
        if (Get-Command Update-SLTInstallCounter -ErrorAction SilentlyContinue) { Update-SLTInstallCounter }
        return $added
    } catch {
        return 0
    }
}

function Add-SLTInstalledToMemory([object[]]$Packages) {
    # Updates in-memory installed state immediately after verified installation
    try {
        if ($null -eq $script:ScannedInstalledApps) { $script:ScannedInstalledApps = @{} }
        foreach ($pk in @($Packages)) {
            if ($null -eq $pk) { continue }
            $k = if ($pk -is [hashtable]) { [string]$pk['key'] } elseif ($pk.PSObject.Properties['key']) { [string]$pk.key } else { '' }
            $n = if ($pk -is [hashtable]) { [string]$pk['name'] } elseif ($pk.PSObject.Properties['name']) { [string]$pk.name } else { '' }
            if (-not [string]::IsNullOrWhiteSpace($k)) {
                $appRec = if ($null -ne $script:AppIndex -and $script:AppIndex.ContainsKey($k)) { $script:AppIndex[$k] } else { $null }
                $script:ScannedInstalledApps[$k] = @{ Item = $appRec; Version = 'Latest'; Source = 'WinGet' }
                if ($null -ne $script:SelectedApps -and $script:SelectedApps.ContainsKey($k)) {
                    $null = $script:SelectedApps.Remove($k)
                }
                if ($null -ne $appRec) {
                    $rowId = ('SLT_' + $k)
                    $alreadyInScan = $false
                    foreach ($existing in @($script:RealScanAllApps)) {
                        if ($null -ne $existing -and ([string]$existing.SltKey -eq $k -or [string]$existing.RowId -eq $rowId)) {
                            $alreadyInScan = $true
                            break
                        }
                    }
                    if (-not $alreadyInScan) {
                        $pubTxt = if (-not [string]::IsNullOrWhiteSpace([string]$appRec.Publisher)) { [string]$appRec.Publisher } else { 'Verified Official' }
                        $newRow = [pscustomobject]@{
                            RowId           = $rowId
                            Name            = [string]$appRec.Name
                            Publisher       = $pubTxt
                            Version         = 'Latest'
                            CategoryName    = [string]$appRec.Category
                            AppCategory     = 'SLT'
                            BadgeText       = 'SLT App'
                            SltKey          = $k
                            WingetId        = [string]$appRec.Winget
                            SltAction       = [string]$appRec.SltAction
                            UninstallString = ''
                            QuietUninstall  = ''
                            AppxName        = ''
                            ChildName       = ''
                            SizeMb          = [int]$appRec.SizeMb
                            EtaMin          = [double]$appRec.EtaMin
                            MatchKeywords   = @($appRec.MatchKeywords)
                        }
                        $script:RealScanSltApps = @((@($script:RealScanSltApps) + @($newRow)) | Sort-Object Name)
                    }
                }
            }
        }
        $script:RealScanAllApps = @(@($script:RealScanWindowsApps) + @($script:RealScanCustomerApps) + @($script:RealScanSltApps))
        $script:TotalPcInstalledCount = $script:RealScanAllApps.Count
        if (Get-Command Invoke-SLTUpdateAllScanUIs -ErrorAction SilentlyContinue) { Invoke-SLTUpdateAllScanUIs }
        if (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue) { Render-SLTAppCatalog }
        if (Get-Command Update-SLTInstallCounter -ErrorAction SilentlyContinue) { Update-SLTInstallCounter }
        if (Get-Command Update-SLTStatusLine -ErrorAction SilentlyContinue) { Update-SLTStatusLine }
    } catch {}
}

function Install-NewAppsOnly {
    Sync-SLTCatalogWingetIds
    $newIds = @(Get-SLTSelectedNewAppsList)
    if ($newIds.Count -eq 0) {
        [Windows.MessageBox]::Show('Please select one or more NOT-installed applications below first, then click Install Complete Package.', 'Smart Install Mode', 'OK', 'Information') | Out-Null
        return
    }
    $idMap = Get-SLTVerifiedWingetIdMap
    $packages = New-Object System.Collections.Generic.List[object]
    foreach ($key in $newIds) {
        if (-not $script:AppIndex.ContainsKey([string]$key)) { continue }
        $app = $script:AppIndex[[string]$key]
        $wid = if ($idMap.ContainsKey([string]$key)) { [string]$idMap[[string]$key] } else { ([string]$app.Winget).Trim() }
        $tSec = if ($wid -eq 'Google.GoogleDrive' -or [int]$app.SizeMb -ge 200) { 300 } else { 100 }
        $catType = if ([bool]$app.Essential -or -not [string]::IsNullOrWhiteSpace([string]$app.SltAction)) { 'SLT' } else { 'CUSTOMER' }
        if (-not [string]::IsNullOrWhiteSpace($wid) -and $wid -notin @('na','N/A')) {
            $packages.Add(@{
                key            = $app.Key
                name           = $app.Name
                winget         = $wid
                choco          = 'na'
                url            = $app.Url
                slt_action     = $app.SltAction
                app_category   = $catType
                size_mb        = $app.SizeMb
                eta_min        = $app.EtaMin
                match_keywords = $app.MatchKeywords
                timeout_sec    = $tSec
            })
        }
    }
    if ($packages.Count -gt 0) {
        $useCache = ($null -ne $script:InstallOfflineCacheCb -and [bool]$script:InstallOfflineCacheCb.IsChecked)
        Start-SLTQueue -Packages @($packages.ToArray()) -Verb 'Install' -Manager 'WinGet' -OfflineCache $useCache -AutoUpgrade $false
    }
}

Set-Item -Path Function:\global:Get-SLTVerifiedWingetIdMap -Value ${function:Get-SLTVerifiedWingetIdMap}
Set-Item -Path Function:\global:Sync-SLTCatalogWingetIds -Value ${function:Sync-SLTCatalogWingetIds}
Set-Item -Path Function:\global:Sync-SLTPackageWorkerScript -Value ${function:Sync-SLTPackageWorkerScript}
Set-Item -Path Function:\global:Test-SLTAppIsAlreadyInstalled -Value ${function:Test-SLTAppIsAlreadyInstalled}
Set-Item -Path Function:\global:Get-SLTSelectedNewAppsList -Value ${function:Get-SLTSelectedNewAppsList}

function Select-SLTOfficeStudyBundle {
    try {
        $officeKeys = @(
            'a_google_chrome','a_thedocumentfoundation_libreoffice','a_pdfgear_pdfgear',
            'a_7zip_7zip','a_videolan_vlc','a_9nksqgp7f2nh','a_zoom_zoom',
            'a_telegram_telegramdesktop','a_sharex_sharex','a_slt_arabic_language_pack',
            'a_slt_smart_tools_hub'
        )
        $added = 0
        foreach ($k in $officeKeys) {
            if ($script:AppIndex.ContainsKey($k) -and (-not $script:WebOnlyKeys.ContainsKey($k)) -and (-not (Test-SLTAppIsAlreadyInstalled $k))) {
                $script:SelectedApps[$k] = $true
                $added++
            }
        }
        if (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue) { Render-SLTAppCatalog }
        if (Get-Command Update-SLTInstallCounter -ErrorAction SilentlyContinue) { Update-SLTInstallCounter }
        return $added
    } catch { return 0 }
}

function Select-SLTRuntimesDriversBundle {
    try {
        $rtKeys = @(
            'a_microsoft_vcredist_2015_x64','a_microsoft_vcredist_2015_x86',
            'a_microsoft_dotnet_desktopruntime_8','a_microsoft_dotnet_desktopruntime_9',
            'a_microsoft_directx','a_microsoft_edgewebview2runtime',
            'a_oracle_javaruntimeenvironment','a_intel_dsa'
        )
        $added = 0
        foreach ($k in $rtKeys) {
            if ($script:AppIndex.ContainsKey($k) -and (-not $script:WebOnlyKeys.ContainsKey($k)) -and (-not (Test-SLTAppIsAlreadyInstalled $k))) {
                $script:SelectedApps[$k] = $true
                $added++
            }
        }
        if (Get-Command Render-SLTAppCatalog -ErrorAction SilentlyContinue) { Render-SLTAppCatalog }
        if (Get-Command Update-SLTInstallCounter -ErrorAction SilentlyContinue) { Update-SLTInstallCounter }
        return $added
    } catch { return 0 }
}

Set-Item -Path Function:\global:Select-SLTEssentialNewApps -Value ${function:Select-SLTEssentialNewApps}
Set-Item -Path Function:\global:Select-SLTOfficeStudyBundle -Value ${function:Select-SLTOfficeStudyBundle}
Set-Item -Path Function:\global:Select-SLTRuntimesDriversBundle -Value ${function:Select-SLTRuntimesDriversBundle}
Set-Item -Path Function:\global:Add-SLTInstalledToMemory -Value ${function:Add-SLTInstalledToMemory}
Set-Item -Path Function:\global:Install-NewAppsOnly -Value ${function:Install-NewAppsOnly}
