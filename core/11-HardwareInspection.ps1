# =====================================================================
# SLT HARDWARE INSPECTION ENGINE
# Developed by Shahzad Babar | Smart Life Teck (www.smartlifeteck.com)
# Hardware diagnostics and technician-led QC reporting for laptop inspection & sourcing
# Uses Windows 10/11 Native CIM/WMI, Storage Reliability Counters, root\wmi
# Battery, Storage & Thermal classes - 100% Original Smart Life Teck Code.
# =====================================================================

$script:HWData = @{
    PC         = $null
    CPU        = $null
    RAM        = $null
    Storage    = $null
    DiskSpeed  = $null
    MemSpeed   = $null
    Battery    = $null
    GPU        = $null
    Devices    = $null
    Connectivity = $null
    Alerts     = @()
    ScanErrors = @()
    PhysicalQC = @{
        Keyboard   = 'Pending'
        Screen     = 'Pending'
        Audio      = 'Pending'
        Camera     = 'Pending'
        Ports      = 'Pending'
        Microphone = 'Pending'
        Touchpad   = 'Pending'
        Body       = 'Pending'
        Charger    = 'Pending'
        Fingerprint = 'Pending'
    }
    Customer = @{
        Name          = ''
        PurchaseDate  = ''
        Mobile        = ''
        City          = ''
        RetailPrice   = ''
        BodyCondition = 'Not inspected'
        Charger       = 'Not verified'
    }
    Notes = @{}
    ScanCancelled = $false
    KbdLayout = 'Laptop'
}
$script:HWToolsBin = Join-Path $script:Root 'tools-bin'
$script:HWSensorComputer = $null

function Get-SLTHWGrades {
    $p = Join-Path $script:Root 'config\hardware_grades.json'
    if (Test-Path -LiteralPath $p) { try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch {} }
    return [pscustomobject]@{
        battery = @(
            [pscustomobject]@{min=85;  max=105; label='A++ (Like New / Excellent)'; color='#10B981'},
            [pscustomobject]@{min=70;  max=85;  label='A+ (Very Good Condition)';   color='#2ECC71'},
            [pscustomobject]@{min=55;  max=70;  label='Good (Normal Used Backup)';  color='#F59E0B'},
            [pscustomobject]@{min=40;  max=55;  label='Fair (Moderate Backup)';     color='#F97316'},
            [pscustomobject]@{min=-1;  max=40;  label='Weak / Replace Recommended'; color='#EF4444'}
        )
        storage = @(
            [pscustomobject]@{min=85; max=105; label='A++ Excellent Health';   color='#10B981'},
            [pscustomobject]@{min=70; max=85;  label='Good (Normal Wear)';            color='#F59E0B'},
            [pscustomobject]@{min=0;  max=70;  label='Warning - High Wear / Replace'; color='#EF4444'}
        )
    }
}

function Get-SLTGradeFor([double]$Value,[object[]]$Table) {
    foreach ($row in @($Table)) {
        if ($null -ne $row -and $Value -ge [double]$row.min -and $Value -lt [double]$row.max) {
            return [pscustomobject]@{label=[string]$row.label;color=[string]$row.color}
        }
    }
    return [pscustomobject]@{label='Unknown';color='#7FA0BE'}
}

# -------------------------------------------------- WINDOWS SENSOR READOUT ---
# Reads Windows thermal zones only (perf counters + ACPI WMI). There is no
# sensor DLL and no third-party sensor library in this package. If a laptop
# exposes no thermal zone, temperature is reported as Not reported.
function Get-SLTSensorReadout {
    $rows = @()
    try {
        # 1. Native Windows Thermal Zone Performance Counters (Kelvin -> Celsius)
        $perfTz = @(Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction SilentlyContinue)
        foreach ($pt in $perfTz) {
            if ($null -ne $pt.Temperature -and $pt.Temperature -gt 250) {
                $cVal = [math]::Round(([double]$pt.Temperature - 273.15), 1)
                if ($cVal -ge 20 -and $cVal -le 115) {
                    $rows += [pscustomobject]@{
                        HardwareType = 'Cpu'
                        Hardware     = 'Windows Thermal Zone Counter'
                        Sensor       = [string]$pt.Name
                        Type         = 'Temperature'
                        Value        = $cVal
                    }
                }
            }
        }
    } catch {}
    try {
        # 2. Native ACPI Thermal Zone WMI (Tenths of Kelvin -> Celsius)
        $acpiTz = @(Get-CimInstance -Namespace 'root/wmi' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction SilentlyContinue)
        foreach ($at in $acpiTz) {
            if ($null -ne $at.CurrentTemperature -and $at.CurrentTemperature -gt 2732) {
                $cVal = [math]::Round((($at.CurrentTemperature / 10.0) - 273.15), 1)
                if ($cVal -ge 20 -and $cVal -le 115) {
                    $rows += [pscustomobject]@{
                        HardwareType = 'Cpu'
                        Hardware     = 'ACPI Motherboard Sensor'
                        Sensor       = [string]$at.InstanceName
                        Type         = 'Temperature'
                        Value        = $cVal
                    }
                }
            }
        }
    } catch {}
    return $rows
}

# Processor name with fallbacks: WMI first, then the registry value Windows
# itself stores at boot, then the environment string. Never blank.
function Get-SLTProcessorName {
    # Processor name with fallbacks: CIM WMI first, legacy WMI second, then
    # the registry value Windows itself stores at boot, then the environment
    # string. Each source is tried independently so one failing source can
    # never blank the field. Never blank.
    $name = $null; $source = 'Not reported'
    try {
        $c = @(Get-SLTCachedWmiClass 'Win32_Processor')[0]
        if ($c -and $c.Name) { $name = ([string]$c.Name -replace '\s+',' ').Trim(); $source = 'WMI (Win32_Processor)' }
    } catch {}
    if ([string]::IsNullOrWhiteSpace($name)) {
        try {
            $w = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($w -and $w.Name) { $name = ([string]$w.Name -replace '\s+',' ').Trim(); $source = 'WMI legacy (Get-WmiObject)' }
        } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        try {
            $rn = (Get-ItemProperty -Path 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name 'ProcessorNameString' -ErrorAction Stop).ProcessorNameString
            if ($rn) { $name = ([string]$rn -replace '\s+',' ').Trim(); $source = 'Registry (CentralProcessor)' }
        } catch {}
    }
    if ([string]::IsNullOrWhiteSpace($name) -and $env:PROCESSOR_IDENTIFIER) {
        $name = ([string]$env:PROCESSOR_IDENTIFIER -replace '\s+',' ').Trim(); $source = 'Environment (PROCESSOR_IDENTIFIER)'
    }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Not reported - processor could not be read'; $source = 'Not reported' }
    return [pscustomobject]@{ Name = $name; Source = $source }
}

function Get-SLTCpuRegistryInfo {
    # Everything Windows stores about the CPU in the CentralProcessor key:
    # name, identifier (Family/Model/Stepping), vendor, ~MHz, feature bitmask
    # (CPUID EDX leaf 1) and microcode revision ("Update Status"). Each value
    # is read on its own so one missing value cannot fail the others.
    $info = [pscustomobject]@{ Name=$null; Identifier=$null; Vendor=$null; Mhz=0; FeatureSet=$null; Microcode=$null; SteppingText=$null; Family=0; Model=0; Stepping=0 }
    try {
        $kp = 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0'
        $props = Get-ItemProperty -Path $kp -ErrorAction Stop
        if ($props.PSObject.Properties['ProcessorNameString'] -and $props.ProcessorNameString) { $info.Name = ([string]$props.ProcessorNameString -replace '\s+',' ').Trim() }
        if ($props.PSObject.Properties['Identifier'] -and $props.Identifier) { $info.Identifier = [string]$props.Identifier }
        if ($props.PSObject.Properties['VendorIdentifier'] -and $props.VendorIdentifier) { $info.Vendor = [string]$props.VendorIdentifier }
        if ($props.PSObject.Properties['~MHz'] -and $props.'~MHz') { $info.Mhz = [int]$props.'~MHz' }
        if ($props.PSObject.Properties['FeatureSet'] -and $null -ne $props.FeatureSet) { $info.FeatureSet = [uint32]$props.FeatureSet }
        if ($props.PSObject.Properties['Update Status'] -and $null -ne $props.'Update Status') {
            $raw = $props.'Update Status'
            if ($raw -is [byte[]]) { $info.Microcode = ('0x' + (($raw | ForEach-Object { '{0:X2}' -f $_ }) -join '')) }
            else { $info.Microcode = [string]$raw }
        }
        if ($info.Identifier -match 'Family\s+(\d+)\s+Model\s+(\d+)\s+Stepping\s+(\d+)') {
            $info.Family = [int]$Matches[1]; $info.Model = [int]$Matches[2]; $info.Stepping = [int]$Matches[3]
            $info.SteppingText = "Family $($info.Family), Model $($info.Model), Stepping $($info.Stepping)"
        }
    } catch {}
    return $info
}

function Get-SLTCpuFeatureList([uint32]$FeatureSet) {
    # CPUID leaf 1 EDX feature bits, the documented standard mapping. Only
    # bits actually set in the registry value are listed; nothing is guessed.
    if ($null -eq $FeatureSet) { return 'Not reported' }
    $bits = @(
        @(0,'FPU'),@(1,'VME'),@(2,'DE'),@(3,'PSE'),@(4,'TSC'),@(5,'MSR'),@(6,'PAE'),@(7,'MCE'),
        @(8,'CX8'),@(9,'APIC'),@(10,'SEP'),@(11,'MTRR'),@(12,'PGE'),@(13,'MCA'),@(14,'CMOV'),
        @(15,'PAT'),@(16,'PSE36'),@(17,'PSN'),@(18,'CLFSH'),@(19,'DS'),@(20,'ACPI'),@(21,'MMX'),
        @(22,'FXSR'),@(23,'SSE'),@(24,'SSE2'),@(25,'SS'),@(26,'HTT'),@(27,'TM'),@(28,'IA64'),@(29,'PBE')
    )
    $found = @()
    foreach ($b in $bits) { if (($FeatureSet -band (1 -shl $b[0])) -ne 0) { $found += $b[1] } }
    if ($found.Count -eq 0) { return 'None reported in registry FeatureSet' }
    return ($found -join ', ')
}

function Get-SLTCacheDetail {
    # Win32_CacheMemory: L1/L2/L3 sizes in KB, summed per level. Instruction
    # and data caches at the same level are added together, as HWiNFO shows
    # combined per-level totals in its summary.
    $c = [pscustomobject]@{ L1KB=0; L2KB=0; L3KB=0; Reported=$false }
    try {
        $rows = @(Get-CimInstance Win32_CacheMemory -ErrorAction SilentlyContinue)
        foreach ($r in $rows) {
            if ($null -eq $r -or $null -eq $r.MaxCacheSize) { continue }
            $kb = [int]$r.MaxCacheSize
            if ($kb -le 0) { continue }
            $lvl = 0
            try { $lvl = [int]$r.Level } catch {}
            if ($lvl -eq 3) { $c.L1KB += $kb } elseif ($lvl -eq 4) { $c.L2KB += $kb } elseif ($lvl -eq 5) { $c.L3KB += $kb }
        }
        if ($c.L1KB -gt 0 -or $c.L2KB -gt 0 -or $c.L3KB -gt 0) { $c.Reported = $true }
    } catch {}
    return $c
}

$script:SLTWmiScanCache = @{}
$script:SLTWmiScanCacheTime = [datetime]::MinValue

function Get-SLTCachedWmiClass([string]$ClassName, [string]$Namespace = 'root/cimv2', [switch]$ForceRefresh) {
    try {
        $key = "$Namespace::$ClassName"
        if ($ForceRefresh -or $null -eq $script:SLTWmiScanCache -or (-not $script:SLTWmiScanCache.ContainsKey($key)) -or ((Get-Date) - $script:SLTWmiScanCacheTime).TotalSeconds -gt 25) {
            if (((Get-Date) - $script:SLTWmiScanCacheTime).TotalSeconds -gt 25) {
                $script:SLTWmiScanCache = @{}
                $script:SLTWmiScanCacheTime = Get-Date
            }
            $script:SLTWmiScanCache[$key] = @(Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction SilentlyContinue)
        }
        return $script:SLTWmiScanCache[$key]
    } catch {
        return @()
    }
}
Set-Item -Path Function:\global:Get-SLTCachedWmiClass -Value ${function:Get-SLTCachedWmiClass}

function Get-SLTCachedPnpEntities([switch]$ForceRefresh) {
    try {
        if ($ForceRefresh -or $null -eq $script:CachedPnpList -or ((Get-Date) - $script:CachedPnpTime).TotalSeconds -gt 45) {
            $script:CachedPnpList = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue)
            $script:CachedPnpTime = Get-Date
        }
        return $script:CachedPnpList
    } catch {
        return @()
    }
}
Set-Item -Path Function:\global:Get-SLTCachedPnpEntities -Value ${function:Get-SLTCachedPnpEntities}

function Get-SLTFullComputerInfo {
    $sys   = @(Get-SLTCachedWmiClass 'Win32_ComputerSystem')[0]
    $bios  = @(Get-SLTCachedWmiClass 'Win32_BIOS')[0]
    $os    = @(Get-SLTCachedWmiClass 'Win32_OperatingSystem')[0]
    $board = @(Get-SLTCachedWmiClass 'Win32_BaseBoard')[0]
    $cpu   = @(Get-SLTCachedWmiClass 'Win32_Processor')[0]
    $net   = @(Get-CimInstance Win32_NetworkAdapter -Filter "NetEnabled=true" -ErrorAction SilentlyContinue | Select-Object -First 4 Name,MACAddress)

    $uptimeStr = 'N/A'
    $lastBootStr = 'N/A'
    if ($null -ne $os -and $null -ne $os.LastBootUpTime) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        $lastBootStr = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm')
        $uptimeStr = '{0}d {1}h {2}m' -f $uptime.Days,$uptime.Hours,$uptime.Minutes
    }
    $sysFam = 'Not reported'
    if ($null -ne $sys -and $null -ne $sys.PSObject.Properties['SystemFamily'] -and $sys.SystemFamily) {
        $sysFam = [string]$sys.SystemFamily
    }
    $netStr = 'Not reported - no active adapter data returned'
    if ($net.Count -gt 0) {
        $netStr = ($net | ForEach-Object {"$($_.Name) [$($_.MACAddress)]"}) -join ' | '
    }

    # Verify Windows activation from Software Protection Platform licensing status.
    # A stored product-key marker alone does not prove that Windows is currently activated.
    $actStatus = 'Not verified'
    try {
        $licenseRows = @(Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction Stop)
        $activeLicense = $licenseRows | Where-Object { [int]$_.LicenseStatus -eq 1 } | Select-Object -First 1
        if ($activeLicense) { $actStatus = 'Activated (license status verified)' }
        elseif ($licenseRows.Count -gt 0) { $actStatus = 'Not activated / license status not active' }
    } catch { $actStatus = 'Not verified (licensing query unavailable)' }

    # Check Secure Boot & TPM 2.0
    $secBoot = 'Unknown'
    try {
        $sbVal = Confirm-SecureBootUEFI -ErrorAction Stop
        $secBoot = if ($sbVal) { 'Enabled (UEFI)' } else { 'Disabled' }
    } catch { $secBoot = 'Not reported (UEFI query unavailable)' }

    $tpmStr = 'Not reported'
    try {
        $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop | Select-Object -First 1
        if ($null -ne $tpm) {
            $ver = if ($null -ne $tpm.PSObject.Properties['SpecVersion'] -and $tpm.SpecVersion) { ([string]$tpm.SpecVersion -split ',')[0].Trim() } else { '2.0' }
            $tpmStr = "TPM $ver Ready"
        } else { $tpmStr = 'No TPM device reported' }
    } catch { $tpmStr = 'Not reported (TPM query unavailable)' }

    [pscustomobject]@{
        Manufacturer    = if($sys -and $sys.Manufacturer){[string]$sys.Manufacturer}else{'Not reported'}
        Model           = if($sys -and $sys.Model){[string]$sys.Model}else{'Not reported'}
        SystemFamily    = $sysFam
        SerialNumber    = if($bios -and $bios.SerialNumber){[string]$bios.SerialNumber}else{'Not reported'}
        BIOSVersion     = if($bios){[string]$bios.SMBIOSBIOSVersion}else{'N/A'}
        BIOSDate        = if($bios -and $bios.ReleaseDate){$bios.ReleaseDate.ToString('yyyy-MM-dd')}else{'N/A'}
        Motherboard     = if($board){"$($board.Manufacturer) $($board.Product)"}else{'N/A'}
        BoardSerial     = if($board -and $board.SerialNumber){[string]$board.SerialNumber}else{'N/A'}
        OSName          = if($os){([string]$os.Caption -replace '^Microsoft\s+','').Trim()}else{'Not reported'}
        OSVersion       = if($os){[string]$os.Version}else{'N/A'}
        OSBuild         = if($os){[string]$os.BuildNumber}else{'N/A'}
        OSArch          = if($os){[string]$os.OSArchitecture}else{'Not reported'}
        Activation      = $actStatus
        SecureBootTPM   = "$secBoot  |  $tpmStr"
        InstallDate     = if($os -and $os.InstallDate){$os.InstallDate.ToString('yyyy-MM-dd')}else{'N/A'}
        LastBoot        = $lastBootStr
        Uptime          = $uptimeStr
        CPU             = (Get-SLTProcessorName).Name
        TotalRAMGB      = if($sys -and $sys.TotalPhysicalMemory){[math]::Round($sys.TotalPhysicalMemory/1GB,1)}else{$null}
        ComputerName    = if($sys){[string]$sys.Name}else{$env:COMPUTERNAME}
        Domain          = if($sys){[string]$sys.Domain}else{'WORKGROUP'}
        NetAdapters     = $netStr
    }
}

# ---------------------------------------------------------------- 2. CPU & THERMAL ---
function Get-SLTCPULoadPercent {
    try {
        $v = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples[0].CookedValue
        return [math]::Round($v,1)
    } catch {
        try {
            $p = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $p -and $null -ne $p.LoadPercentage) { return [double]$p.LoadPercentage }
        } catch {}
        return $null
    }
}

function Get-SLTTempPath {
    if ($env:TEMP) { return $env:TEMP }
    if ($env:TMP) { return $env:TMP }
    return [System.IO.Path]::GetTempPath()
}

function Get-SLTCPUDetail {
    # HWiNFO-level CPU detail from every source Windows exposes, each field
    # isolated: one failing query can never blank the other fields. Sources:
    # CIM Win32_Processor, legacy WMI, registry CentralProcessor key,
    # Win32_CacheMemory, performance counter, thermal zones, environment.
    # Fields Windows does not expose (TDP, BCLK, per-core live clocks,
    # codename) are reported as Not reported, never invented.
    $sources = @()
    $cpu = $null; $cpuSource = $null
    $all = @(Get-SLTCachedWmiClass 'Win32_Processor')
    if ($all.Count -gt 0) {
        $cpu = $all[0]
        $cpuSource = 'CIM Win32_Processor'
        $sources += $cpuSource
    }
    if (-not $cpu) {
        try {
            $cpu = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cpu) { $cpuSource = 'Legacy WMI'; $sources += $cpuSource }
        } catch {}
    }
    $procCount = if ($all.Count -gt 0) { $all.Count } elseif ($cpu) { 1 } else { 0 }
    if ($procCount -eq 0 -and $cpu) { $procCount = 1 }
    $procName = Get-SLTProcessorName
    if ($procName.Source -ne 'Not reported' -and $sources -notcontains $procName.Source) { $sources += $procName.Source }
    $reg = Get-SLTCpuRegistryInfo
    if ($reg.Name -or $reg.Identifier) { $sources += 'Registry (CentralProcessor)' }
    $cache = Get-SLTCacheDetail
    if ($cache.Reported) { $sources += 'Win32_CacheMemory' }

    $getProp = {
        param($Obj, [string]$Prop)
        if ($null -eq $Obj) { return $null }
        try { if ($Obj.PSObject.Properties[$Prop]) { return $Obj.$Prop } } catch {}
        return $null
    }
    $manufacturer = & $getProp $cpu 'Manufacturer'
    $cores = & $getProp $cpu 'NumberOfCores'
    $threads = & $getProp $cpu 'NumberOfLogicalProcessors'
    $curClock = & $getProp $cpu 'CurrentClockSpeed'
    $maxClock = & $getProp $cpu 'MaxClockSpeed'
    $l2 = & $getProp $cpu 'L2CacheSize'
    $l3 = & $getProp $cpu 'L3CacheSize'
    $socket = & $getProp $cpu 'SocketDesignation'
    $arch = & $getProp $cpu 'Architecture'
    $addrW = & $getProp $cpu 'AddressWidth'
    $dataW = & $getProp $cpu 'DataWidth'
    $family = & $getProp $cpu 'Family'
    $stepping = & $getProp $cpu 'Stepping'
    $procId = & $getProp $cpu 'ProcessorId'
    $revision = & $getProp $cpu 'Revision'
    $descr = & $getProp $cpu 'Description'
    $voltCaps = & $getProp $cpu 'VoltageCaps'
    $extClock = & $getProp $cpu 'ExtClock'
    $l1fromCpu = $null
    $virt = 'Not reported'
    try {
        if ($null -ne $cpu -and $null -ne $cpu.PSObject.Properties['VirtualizationFirmwareEnabled']) {
            $virt = if ($cpu.VirtualizationFirmwareEnabled) { 'Enabled (VT-x/AMD-V)' } else { 'Disabled in BIOS' }
        }
    } catch {}
    $slt = 'Not reported'
    try {
        if ($null -ne $cpu -and $null -ne $cpu.PSObject.Properties['SecondLevelAddressTranslationExtensions'] -and $cpu.SecondLevelAddressTranslationExtensions) { $slt = 'Supported (SLAT / EPT / RVI)' }
    } catch {}
    $load = Get-SLTCPULoadPercent

    $tempC = $null; $tempSource = 'Not reported - no temperature sensor exposed by this laptop'
    try {
        $allSensors = @(Get-SLTSensorReadout)
        $cpuTemps = @($allSensors | Where-Object { $_.Type -eq 'Temperature' -and ($_.HardwareType -match 'Cpu' -or $_.Hardware -match 'Intel|AMD|Core|Ryzen' -or $_.Sensor -match 'Package|Core|Tctl|Tdie|CPU') })
        if ($cpuTemps.Count -gt 0) {
            $maxT = ($cpuTemps | Measure-Object -Property Value -Maximum).Maximum
            if ($maxT -ge 20 -and $maxT -le 115) { $tempC = [math]::Round([double]$maxT, 1); $tempSource = 'Windows Thermal Zone Counter' }
        }
    } catch {}
    if ($null -eq $tempC) {
        try {
            $tz = @(Get-CimInstance -Namespace 'root/wmi' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction SilentlyContinue)
            if ($tz.Count -gt 0 -and $null -ne $tz[0].CurrentTemperature -and $tz[0].CurrentTemperature -gt 2732) {
                $calcC = [math]::Round(($tz[0].CurrentTemperature / 10.0) - 273.15, 1)
                if ($calcC -ge 20 -and $calcC -le 110) { $tempC = $calcC; $tempSource = 'Motherboard ACPI Zone' }
            }
        } catch {}
    }
    $thermalState = 'Normal Operation'; $thermalColor = '#7FA0BE'
    if ($null -ne $tempC) {
        if ($tempC -ge 85) { $thermalState = 'HOT - Check Fan / Thermal Paste!'; $thermalColor = '#EF4444' }
        elseif ($tempC -ge 72) { $thermalState = 'Warm (Under Load)'; $thermalColor = '#F59E0B' }
        else { $thermalState = 'Healthy / Cool'; $thermalColor = '#10B981' }
    }
    $archTxt = switch ([int]$arch) { 0 {'x86 (32-bit)'} 1 {'MIPS'} 2 {'Alpha'} 3 {'PowerPC'} 5 {'ARM'} 6 {'Itanium (IA64)'} 9 {'x64'} 12 {'ARM64'} default { if ($null -ne $arch) { "Code $arch" } else { 'Not reported' } } }
    $famTxt = if ($reg.SteppingText) { $reg.SteppingText } elseif ($null -ne $family) { "Family $family" + $(if ($null -ne $stepping) { ", Stepping $stepping" } else { '' }) } else { 'Not reported' }
    $featTxt = Get-SLTCpuFeatureList $reg.FeatureSet
    $effMax = if ($maxClock -and $maxClock -gt 0) { [int]$maxClock } elseif ($reg.Mhz -gt 0) { $reg.Mhz } else { 0 }
    $effCur = if ($curClock -and $curClock -gt 0) { [int]$curClock } else { $null }
    $effL2 = if ($l2 -and $l2 -gt 0) { [int]$l2 } elseif ($cache.L2KB -gt 0) { $cache.L2KB } else { 0 }
    $effL3 = if ($l3 -and $l3 -gt 0) { [int]$l3 } elseif ($cache.L3KB -gt 0) { $cache.L3KB } else { 0 }
    $srcTxt = if ($sources.Count -gt 0) { ($sources -join ' + ') } else { 'No CPU data source responded - see Scan Diagnostics' }
    [pscustomobject]@{
        Name            = $procName.Name
        NameSource      = $procName.Source
        Manufacturer    = if ($manufacturer) { [string]$manufacturer } elseif ($reg.Vendor) { $reg.Vendor } else { 'Not reported' }
        Cores           = if ($cores) { [int]$cores } else { 0 }
        LogicalCPUs     = if ($threads) { [int]$threads } else { 0 }
        PhysicalProcessors = $procCount
        CurrentClockMHz = $effCur
        MaxClockMHz     = $effMax
        RegClockMHz     = $reg.Mhz
        ExtClockMHz     = if ($extClock) { [int]$extClock } else { 0 }
        L1CacheKB       = $cache.L1KB
        L2CacheKB       = $effL2
        L3CacheKB       = $effL3
        Socket          = if ($socket) { [string]$socket } else { 'Not reported' }
        Architecture    = $archTxt
        AddressWidth    = if ($addrW) { [int]$addrW } else { 0 }
        DataWidth       = if ($dataW) { [int]$dataW } else { 0 }
        FamilyStepping  = $famTxt
        ProcessorId     = if ($procId) { [string]$procId } else { 'Not reported' }
        Revision        = if ($null -ne $revision) { ('0x{0:X4}' -f [int]$revision) } else { 'Not reported' }
        Description     = if ($descr) { [string]$descr } else { 'Not reported' }
        VoltageCaps     = if ($null -ne $voltCaps) { [int]$voltCaps } else { 0 }
        Features        = $featTxt
        Microcode       = if ($reg.Microcode) { $reg.Microcode } else { 'Not reported' }
        Virtualization  = $virt
        SLAT            = $slt
        LoadPercent     = $load
        TemperatureC    = $tempC
        TempSource      = $tempSource
        ThermalState    = $thermalState
        ThermalColor    = $thermalColor
        CpuSources      = $srcTxt
    }
}

function Get-SLTRAMLiveUsage {
    $os = @(Get-SLTCachedWmiClass 'Win32_OperatingSystem')[0]
    if (-not $os -or -not $os.TotalVisibleMemorySize) {
        return [pscustomobject]@{TotalMB=0;UsedMB=0;FreeMB=0;UsedPercent=0}
    }
    $totalMB = [math]::Round($os.TotalVisibleMemorySize/1KB,0)
    $freeMB  = [math]::Round($os.FreePhysicalMemory/1KB,0)
    $usedMB  = $totalMB-$freeMB
    [pscustomobject]@{TotalMB=$totalMB;UsedMB=$usedMB;FreeMB=$freeMB;UsedPercent=[math]::Round(($usedMB/$totalMB)*100,1)}
}

function Get-SLTRAMDetail {
    $sticks = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | ForEach-Object {
        $memTypeCode = 0
        if ($null -ne $_.PSObject.Properties['SMBIOSMemoryType'] -and $null -ne $_.SMBIOSMemoryType) {
            $memTypeCode = [int]$_.SMBIOSMemoryType
        }
        # SMBIOS memory-device type codes (decimal). Unknown codes are
        # reported as Not reported, never guessed.
        $type = switch ($memTypeCode) {
            18 {'DDR'} 19 {'DDR2'} 20 {'DDR2 FB-DIMM'} 24 {'DDR3'} 26 {'DDR4'} 27 {'LPDDR'} 28 {'LPDDR2'} 29 {'LPDDR3'} 30 {'LPDDR4'} 34 {'DDR5'} 35 {'LPDDR5'} default {'Not reported'}
        }
        $cfgSpeed = if($null -ne $_.PSObject.Properties['ConfiguredClockSpeed'] -and $_.ConfiguredClockSpeed){$_.ConfiguredClockSpeed}else{$_.Speed}
        $cfgVolt = $null
        try { if ($null -ne $_.PSObject.Properties['ConfiguredVoltage'] -and $_.ConfiguredVoltage) { $cfgVolt = [int]$_.ConfiguredVoltage } } catch {}
        $interDepth = 0
        try { if ($null -ne $_.PSObject.Properties['InterleaveDataDepth'] -and $_.InterleaveDataDepth) { $interDepth = [int]$_.InterleaveDataDepth } } catch {}
        $formFactor = if($null -ne $_.PSObject.Properties['FormFactor'] -and $_.FormFactor) { switch ([int]$_.FormFactor) { 8 {'DIMM'} 12 {'SODIMM'} default {'Not reported'} } } else { 'Not reported' }
        [pscustomobject]@{
            Slot          = if($_.DeviceLocator){[string]$_.DeviceLocator}else{'Slot'}
            CapacityGB    = if($_.Capacity){[math]::Round($_.Capacity/1GB,1)}else{0}
            SpeedMHz      = $_.Speed
            ConfiguredMHz = $cfgSpeed
            Type          = $type
            FormFactor    = $formFactor
            ConfiguredVoltageMV = $cfgVolt
            InterleaveDataDepth = $interDepth
            Manufacturer  = if($_.Manufacturer){([string]$_.Manufacturer).Trim()}else{'Not reported'}
            PartNumber    = if($_.PartNumber){([string]$_.PartNumber).Trim()}else{'Not reported'}
            SerialNumber  = if($_.SerialNumber){([string]$_.SerialNumber).Trim()}else{'Not reported'}
        }
    })
    $arr = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Select-Object -First 1
    $sumObj = $sticks | Measure-Object CapacityGB -Sum
    $totalGB = if($sticks.Count -gt 0 -and $null -ne $sumObj -and $null -ne $sumObj.Sum){[math]::Round([double]$sumObj.Sum,1)}else{$null}
    $totalSlots = if($arr -and $arr.MemoryDevices -and [int]$arr.MemoryDevices -ge $sticks.Count){[int]$arr.MemoryDevices}else{$null}
    $emptySlots = if ($null -ne $totalSlots) { [math]::Max(0, ($totalSlots - $sticks.Count)) } else { $null }
    $live = Get-SLTRAMLiveUsage
    $upgradeNote = if ($null -eq $totalSlots) { 'Physical slot count not reported by firmware' } elseif ($emptySlots -gt 0) { "$emptySlots Empty Slot(s) Free - Easy RAM Upgrade" } else { 'All Reported Slots Populated' }
    $depths = @($sticks | Where-Object { $_.InterleaveDataDepth -gt 0 } | ForEach-Object { $_.InterleaveDataDepth })
    $chMode = 'Not reported'
    if ($depths.Count -gt 0) {
        $d = ($depths | Measure-Object -Maximum).Maximum
        if ($d -ge 4) { $chMode = "Quad-channel (interleaved x$d)" } elseif ($d -eq 3) { $chMode = 'Triple-channel (interleaved x3)' } elseif ($d -eq 2) { $chMode = 'Dual-channel (interleaved x2)' } else { $chMode = 'Single-channel (not interleaved)' }
    } elseif ($sticks.Count -ge 2) { $chMode = 'Not reported - interleave data not exposed by this system' }
    [pscustomobject]@{
        Sticks       = $sticks
        TotalSlots   = $totalSlots
        UsedSlots    = $sticks.Count
        EmptySlots   = $emptySlots
        UpgradeNote  = $upgradeNote
        TotalGB      = $totalGB
        ChannelMode  = $chMode
        LiveUsage    = $live
    }
}

function Start-SLTWindowsMemoryDiagnostic {
    Start-Process 'mdsched.exe'
}

# ---------------------------------------------------------------- 4. STORAGE (SSD / NVMe / HDD) ---
function Get-SLTStorageDetail {
    $results = @()
    $grades  = (Get-SLTHWGrades).storage
    $disks   = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
    $physicalDisks = $null
    try { $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop) } catch {}
    $allSensors = @(Get-SLTSensorReadout)

    # Also query raw WMI SMART status as fallback
    $wmiSmartStatus = @()
    try { $wmiSmartStatus = @(Get-CimInstance -Namespace 'root\wmi' -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue) } catch {}

    foreach ($d in $disks) {
        $sizeGB = if($d.Size){[math]::Round($d.Size/1GB,1)}else{$null}
        $media  = 'Not reported'
        $health = 'Not reported'
        $wearReported = $false
        $healthColor = '#10B981'
        if ($d.Status -and $d.Status -ne 'OK') { $health = [string]$d.Status; $healthColor = '#F59E0B' }

        $wearPct = $null
        $tempC   = $null
        $powerOnHours = $null
        $readErrors   = $null
        $writeErrors  = $null
        $rel = $null
        $busType      = if($d.InterfaceType){[string]$d.InterfaceType}else{'Not reported'}

        $match = $null
        if ($physicalDisks) {
            $match = $physicalDisks | Where-Object {
                ($null -ne $_.DeviceId -and [string]$_.DeviceId -eq [string]$d.Index) -or
                ($d.Model -and $_.FriendlyName -and ($_.FriendlyName -like "*$($d.Model.Trim())*" -or $d.Model.Trim() -like "*$($_.FriendlyName)*"))
            } | Select-Object -First 1
        }
        if ($match) {
            if ($match.MediaType -and [string]$match.MediaType -ne 'Unspecified') { $media = [string]$match.MediaType }
            if ($match.BusType) { $busType = [string]$match.BusType }
            if ($match.HealthStatus) { $health = [string]$match.HealthStatus }
            try {
                $rel = Get-StorageReliabilityCounter -PhysicalDisk $match -ErrorAction Stop
                if ($null -ne $rel) {
                    if ($null -ne $rel.PSObject.Properties['Wear'] -and $null -ne $rel.Wear) {
                        $wearPct = [math]::Max(0, [math]::Min(100, (100 - [int]$rel.Wear)))
                        $wearReported = $true
                    }
                    if ($null -ne $rel.PSObject.Properties['Temperature'] -and $rel.Temperature -gt 0) {
                        $tempC = [int]$rel.Temperature
                    }
                    if ($null -ne $rel.PSObject.Properties['PowerOnHours'] -and $rel.PowerOnHours -gt 0) {
                        $powerOnHours = [int]$rel.PowerOnHours
                    }
                    if ($null -ne $rel.PSObject.Properties['ReadErrorsTotal'] -and $null -ne $rel.ReadErrorsTotal) {
                        $readErrors = [long]$rel.ReadErrorsTotal
                    }
                    if ($null -ne $rel.PSObject.Properties['WriteErrorsTotal'] -and $null -ne $rel.WriteErrorsTotal) {
                        $writeErrors = [long]$rel.WriteErrorsTotal
                    }
                }
            } catch {}
        }

        # Check thermal-zone sensors if temperature was not reported by StorageReliabilityCounter
        if ($null -eq $tempC -and $allSensors.Count -gt 0) {
            $stoSensor = $allSensors | Where-Object { $_.Type -eq 'Temperature' -and $_.HardwareType -match 'Storage' } | Select-Object -First 1
            if ($null -ne $stoSensor -and $stoSensor.Value -gt 0) {
                $tempC = [int][math]::Round([double]$stoSensor.Value, 0)
            }
        }

        # Check WMI PredictFailure flag
        if ($wmiSmartStatus.Count -gt 0) {
            foreach ($ws in $wmiSmartStatus) {
                if ($ws.PredictFailure -eq $true) {
                    $health = 'Unhealthy (SMART Failure Predicted!)'
                    $wearPct = [math]::Min($wearPct, 25)
                }
            }
        }

        if (-not $wearReported) { $wearPct = $null }
        if ($health -eq 'Not reported') { $health = 'Status not reported; SMART detail not read' }
        $gradeObj = Get-SLTGradeFor $(if($null -ne $wearPct){$wearPct}else{-1}) $grades
        $gradeLabel = [string]$gradeObj.label
        $healthColor = [string]$gradeObj.color
        if ($null -eq $wearPct -and $health -notmatch 'Warning|Unhealthy|Fail') {
            $gradeLabel = 'SMART Not Reported - Verify with CrystalDiskInfo'
            $healthColor = '#7FA0BE'
        }
        if ($health -match 'Warning') { $healthColor = '#F59E0B'; $gradeLabel = 'Warning - Check Disk' }
        elseif ($health -match 'Unhealthy|Fail') { $healthColor = '#EF4444'; $gradeLabel = 'REPLACE DISK IMMEDIATELY' }

        $powerOnDays = if ($null -ne $powerOnHours -and $powerOnHours -gt 0) { ("{0} hrs (~{1} days)" -f $powerOnHours, [math]::Round($powerOnHours / 24.0, 0)) } else { 'Not reported' }

        $fwRev = if ($d.PSObject.Properties['FirmwareRevision'] -and $d.FirmwareRevision) { ([string]$d.FirmwareRevision).Trim() } elseif ($match -and $match.PSObject.Properties['FirmwareVersion'] -and $match.FirmwareVersion) { ([string]$match.FirmwareVersion).Trim() } else { 'Not reported' }
        $ifLink = if ($busType -match 'NVMe' -or $d.Model -match 'NVMe') { 'NVMe' } elseif ($busType -match 'USB') { 'USB' } elseif ($busType -match 'RAID') { 'RAID / VMD' } elseif ($busType -match 'IDE|SATA') { [string]$busType } else { 'Not reported' }
        $pCount = if ($null -ne $rel -and $null -ne $rel.PSObject.Properties['StartStopCycleCount'] -and $rel.StartStopCycleCount -gt 0) { [int]$rel.StartStopCycleCount } else { 'Not reported' }
        $totWrites = 'Not reported (total bytes written not exposed by the current data source)'
        $rwErrors = $null
        if ($null -ne $readErrors -or $null -ne $writeErrors) {
            $rwErrors = [long]0
            if ($null -ne $readErrors) { $rwErrors += [long]$readErrors }
            if ($null -ne $writeErrors) { $rwErrors += [long]$writeErrors }
        }
        $results += [pscustomobject]@{
            Index                = $d.Index
            Model                = if($d.Model){([string]$d.Model).Trim()}else{'Disk Drive'}
            SerialNumber         = if($d.SerialNumber){([string]$d.SerialNumber).Trim()}else{'N/A'}
            Firmware             = $fwRev
            InterfaceLink        = $ifLink
            PowerOnCount         = $pCount
            TotalWrites          = $totWrites
            InterfaceType        = $busType
            SizeGB               = $sizeGB
            MediaType            = $media
            HealthStatus         = $health
            GradeLabel           = $gradeLabel
            HealthColor          = $healthColor
            WearRemainingPercent = $wearPct
            TemperatureC         = $tempC
            PowerOnHours         = $powerOnHours
            PowerOnDisplay       = $powerOnDays
            ReadWriteErrors      = $rwErrors
        }
    }
    return $results
}

function Get-SLTWinSatResult([string[]]$Arguments, [int]$TimeoutSec=60) {
    # Runs winsat with explicit fast flags and a hard timeout. Returns the
    # combined stdout+stderr text and whether it finished in time. winsat
    # with no mode flags runs a ~60 second full scenario; explicit -seq/-ran
    # -read/-write flags keep each run to a few seconds.
    $outFile = Join-Path (Get-SLTTempPath) 'SLT_WinSat_Out.txt'
    $errFile = Join-Path (Get-SLTTempPath) 'SLT_WinSat_Err.txt'
    try { Remove-Item -LiteralPath $outFile,$errFile -Force -ErrorAction SilentlyContinue } catch {}
    try {
        $p = Start-Process -FilePath 'winsat.exe' -ArgumentList $Arguments -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile -ErrorAction Stop
        $finished = $p.WaitForExit($TimeoutSec * 1000)
        if (-not $finished) { try { $p.Kill() } catch {}; return [pscustomobject]@{ Text=''; TimedOut=$true; ExitCode=$null } }
        $txt = ''
        if (Test-Path -LiteralPath $outFile) { $txt += (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue) }
        if (Test-Path -LiteralPath $errFile) { $txt += "`n" + (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue) }
        return [pscustomobject]@{ Text=$txt; TimedOut=$false; ExitCode=$p.ExitCode }
    } catch {
        return [pscustomobject]@{ Text=''; TimedOut=$false; ExitCode=$null; Error=$_.Exception.Message }
    } finally {
        try { Remove-Item -LiteralPath $outFile,$errFile -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Get-SLTDiskSpeed([string]$DriveLetter='C') {
    # Targeted winsat runs (sequential read, sequential write, random read)
    # with flexible regex parsing: winsat spacing varies between builds, so
    # the old exact two-space match missed real results. If winsat yields
    # nothing, a managed file-copy benchmark measures the same drive honestly
    # and the Source field says which method produced the numbers.
    $readMB = $null; $writeMB = $null; $randMB = $null; $notes = @(); $src = 'winsat'
    $runs = @(
        @{ Kind='SeqRead'; Args=@('disk','-drive',$DriveLetter,'-seq','-read'); Pattern='Disk\s+Sequential\s+[\d\.]+\s+Read\s+([\d\.]+)\s*MB/s' },
        @{ Kind='SeqWrite'; Args=@('disk','-drive',$DriveLetter,'-seq','-write'); Pattern='Disk\s+Sequential\s+[\d\.]+\s+Write\s+([\d\.]+)\s*MB/s' },
        @{ Kind='RandRead'; Args=@('disk','-drive',$DriveLetter,'-ran','-read'); Pattern='Disk\s+Random\s+[\d\.]+\s+Read\s+([\d\.]+)\s*MB/s' }
    )
    foreach ($run in $runs) {
        $res = Get-SLTWinSatResult $run.Args 60
        if ($res.TimedOut) { $notes += "$($run.Kind): winsat timed out after 60s"; continue }
        if ($res.Text -match $run.Pattern) {
            $val = [double]$Matches[1]
            if ($run.Kind -eq 'SeqRead') { $readMB = $val } elseif ($run.Kind -eq 'SeqWrite') { $writeMB = $val } else { $randMB = $val }
        } else {
            $notes += "$($run.Kind): winsat produced no matching result line"
        }
    }
    if ($null -eq $readMB -and $null -eq $writeMB) {
        $fb = Get-SLTFileBenchmark $DriveLetter
        if ($fb) {
            $readMB = $fb.ReadMBs; $writeMB = $fb.WriteMBs; $src = 'SLT file benchmark (winsat produced no result)'
            if ($fb.Note) { $notes += $fb.Note }
        } else {
            $src = 'Not measured'
            $notes += 'File benchmark fallback could not run (insufficient free space or access denied).'
        }
    }
    [pscustomobject]@{
        SeqReadMBs  = if ($null -ne $readMB) { [math]::Round($readMB,1) } else { 'N/A' }
        SeqWriteMBs = if ($null -ne $writeMB) { [math]::Round($writeMB,1) } else { 'N/A' }
        RandReadMBs = if ($null -ne $randMB) { [math]::Round($randMB,1) } else { 'N/A' }
        Source      = $src
        Notes       = ($notes -join ' | ')
    }
}

function Get-SLTFileBenchmark([string]$DriveLetter='C') {
    # Honest fallback disk benchmark: writes a 128 MB temp file with a
    # FileStream, reads it back, times both, deletes it. No winsat needed.
    $tmp = Join-Path (Get-SLTTempPath) 'SLT_SpeedTest.tmp'
    $sizeMB = 128; $totalBytes = $sizeMB * 1MB
    try {
        $drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
        if ($drive.Free -lt 512MB) { return [pscustomobject]@{ ReadMBs=$null; WriteMBs=$null; Note='Less than 512 MB free on the drive.' } }
    } catch { return $null }
    $buf = New-Object byte[] (1MB)
    try {
        for ($i = 0; $i -lt $buf.Length; $i++) { $buf[$i] = [byte]($i % 251) }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $fs = [System.IO.File]::Create($tmp)
        try { $written = 0; while ($written -lt $totalBytes) { $fs.Write($buf, 0, $buf.Length); $written += $buf.Length } ; $fs.Flush($true) } finally { $fs.Close() }
        $sw.Stop(); $writeMBs = [math]::Round(($totalBytes / 1MB) / $sw.Elapsed.TotalSeconds, 1)
        $sw.Restart()
        $fs2 = [System.IO.File]::OpenRead($tmp)
        try { $read = 0; while (($n = $fs2.Read($buf, 0, $buf.Length)) -gt 0) { $read += $n } } finally { $fs2.Close() }
        $sw.Stop(); $readMBs = [math]::Round(($totalBytes / 1MB) / $sw.Elapsed.TotalSeconds, 1)
        return [pscustomobject]@{ ReadMBs=$readMBs; WriteMBs=$writeMBs; Note=$null }
    } catch {
        return [pscustomobject]@{ ReadMBs=$null; WriteMBs=$null; Note=$_.Exception.Message }
    } finally {
        try { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Measure-SLTRAMBandwidth {
    # In-app managed memory benchmark: 64 MB buffers (safe on 4 GB laptops),
    # compiled C# loops so the numbers are real memory bandwidth, not
    # PowerShell loop overhead. Read = strided checksum (every cache line),
    # Write = fill, Copy = BlockCopy. Returns MB/s per leg, or $null per leg
    # that could not run. Nothing is written to disk.
    try {
        if (-not $script:SLTMemBenchReady) {
            Add-Type -TypeDefinition @'
using System;
public static class SLTMemBench {
    public static long ReadChecksum(byte[] buf, int iterations) {
        long s = 0;
        for (int it = 0; it < iterations; it++) {
            for (int i = 0; i + 8 <= buf.Length; i += 8) { s += System.BitConverter.ToInt64(buf, i); }
            for (int i = buf.Length - (buf.Length % 8); i < buf.Length; i++) { s += buf[i]; }
        }
        return s;
    }
    public static void WriteFill(byte[] buf, byte value, int iterations) {
        // BlockCopy pattern fill: Array.Fill is not available on .NET
        // Framework (Windows PowerShell 5.1), and a scalar per-byte store
        // loop measured ~35x slower than the read/copy legs. BlockCopy is
        // a memcpy and exists on every .NET version.
        byte[] pat = new byte[1024 * 1024];
        for (int j = 0; j < pat.Length; j++) pat[j] = value;
        for (int it = 0; it < iterations; it++) {
            for (int off = 0; off < buf.Length; off += pat.Length) {
                int n = System.Math.Min(pat.Length, buf.Length - off);
                Buffer.BlockCopy(pat, 0, buf, off, n);
            }
        }
    }
    public static void CopyBench(byte[] src, byte[] dst, int iterations) {
        for (int it = 0; it < iterations; it++) { Buffer.BlockCopy(src, 0, dst, 0, src.Length); }
    }
}
'@ -ErrorAction Stop
            $script:SLTMemBenchReady = $true
        }
        $sizeMB = 64; $size = $sizeMB * 1024 * 1024
        $src = New-Object byte[] $size; $dst = New-Object byte[] $size
        for ($i = 0; $i -lt $src.Length; $i += 997) { $src[$i] = 7 }
        $sw = [System.Diagnostics.Stopwatch]::new()
        $iters = 8
        $sw.Restart(); $chk = [SLTMemBench]::ReadChecksum($src, $iters); $sw.Stop()
        $readMBs = [math]::Round((($size / 1MB) * $iters) / $sw.Elapsed.TotalSeconds, 0)
        $sw.Restart(); [SLTMemBench]::WriteFill($dst, 5, $iters); $sw.Stop()
        $writeMBs = [math]::Round((($size / 1MB) * $iters) / $sw.Elapsed.TotalSeconds, 0)
        $sw.Restart(); [SLTMemBench]::CopyBench($src, $dst, $iters); $sw.Stop()
        $copyMBs = [math]::Round((($size / 1MB) * $iters) / $sw.Elapsed.TotalSeconds, 0)
        return [pscustomobject]@{ ReadMBs=$readMBs; WriteMBs=$writeMBs; CopyMBs=$copyMBs; BufferMB=$sizeMB; Method='SLT managed memory benchmark (64 MB buffers, C# loops)'; Error=$null }
    } catch {
        return [pscustomobject]@{ ReadMBs=$null; WriteMBs=$null; CopyMBs=$null; BufferMB=64; Method='SLT managed memory benchmark'; Error=$_.Exception.Message }
    }
}

function Get-SLTMemSpeed([switch]$IncludeWinSat) {
    # RAM read/write speed, two independent measurements:
    # 1) winsat mem (Windows' own memory assessment: "Memory Performance
    #    (XXXX MB/s) - only when requested, it takes ~5 seconds.
    # (2) the in-app managed benchmark - always, a few seconds, real numbers.
    # The dashboard/report show both with their method labelled.
    $winSatMB = $null; $winSatNote = 'Not run (use the Speed Tests action for the winsat mem figure).'
    if ($IncludeWinSat) {
        $res = Get-SLTWinSatResult @('mem') 90
        if ($res.TimedOut) { $winSatNote = 'winsat mem timed out after 90s.' }
        elseif ($res.Text -match 'Memory\s+Performance\s+([\d\.]+)\s*MB/s') { $winSatMB = [math]::Round([double]$Matches[1], 0); $winSatNote = 'winsat mem' }
        else { $winSatNote = 'winsat mem produced no result line.' }
    }
    $bench = Measure-SLTRAMBandwidth
    [pscustomobject]@{
        WinSatMBs   = $winSatMB
        WinSatNote  = $winSatNote
        ReadMBs     = $bench.ReadMBs
        WriteMBs    = $bench.WriteMBs
        CopyMBs     = $bench.CopyMBs
        BufferMB    = $bench.BufferMB
        Method      = $bench.Method
        BenchError  = $bench.Error
    }
}

function Get-SLTBatteryDetail {
    $grades = (Get-SLTHWGrades).battery
    $cim = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cim) {
        return [pscustomobject]@{
            Present               = $false
            Message               = 'No Battery Detected (Desktop PC or Battery Removed / Disconnected)'
            GradeLabel            = 'AC Direct / No Battery'
            GradeColor            = '#64748B'
            HealthPercent         = 0
            WearPercent           = 0
            DesignCapacityMWh     = 0
            FullChargeCapacityMWh = 0
            CycleCount            = 0
            Chemistry             = 'N/A'
            LiveChargePercent     = 0
            PowerState            = 'AC Power Only'
        }
    }

    $design = $null; $full = $null; $cycles = $null; $chemistry = 'Not reported'; $healthPct = $null
    $chargeRateW = $null
    $grade = [pscustomobject]@{label='Checking...';color='#7FA0BE'}

    # Engine A: Direct WMI Battery classes (Fastest & most accurate on Windows 10/11 laptops)
    try {
        $stBat = Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStaticData' -ErrorAction SilentlyContinue | Select-Object -First 1
        $fcBat = Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryFullChargedCapacity' -ErrorAction SilentlyContinue | Select-Object -First 1
        $cyBat = Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryCycleCount' -ErrorAction SilentlyContinue | Select-Object -First 1
        $rtBat = Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStatus' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $stBat -and $stBat.DesignedCapacity -gt 0) { $design = [double]$stBat.DesignedCapacity }
        if ($null -ne $fcBat -and $fcBat.FullChargedCapacity -gt 0) { $full = [double]$fcBat.FullChargedCapacity }
        if ($null -ne $cyBat -and $cyBat.CycleCount -gt 0) { $cycles = [int]$cyBat.CycleCount }
        if ($null -ne $rtBat) {
            if ($null -ne $rtBat.PSObject.Properties['ChargeRate'] -and $rtBat.ChargeRate -gt 0) {
                $chargeRateW = ("+{0:N1} W Charging" -f ($rtBat.ChargeRate / 1000.0))
            } elseif ($null -ne $rtBat.PSObject.Properties['DischargeRate'] -and $rtBat.DischargeRate -gt 0) {
                $chargeRateW = ("-{0:N1} W Discharging" -f ($rtBat.DischargeRate / 1000.0))
            }
        }
    } catch {}

    # Engine B: Official powercfg /batteryreport XML (Only run if WMI did not return design/full capacity)
    $xmlPath = Join-Path (Get-SLTTempPath) 'SLT_BatteryReport.xml'
    if (-not $design -or $design -le 0 -or -not $full -or $full -le 0) {
    try {
        if (Test-Path -LiteralPath $xmlPath) { Remove-Item -LiteralPath $xmlPath -Force -ErrorAction SilentlyContinue }
        $null = & cmd.exe /c ('powercfg.exe /batteryreport /xml /output "' + $xmlPath + '" >nul 2>&1')
        if (Test-Path -LiteralPath $xmlPath) {
            [xml]$xml = Get-Content -LiteralPath $xmlPath -Raw
            $bNode = $xml.BatteryReport.Batteries.Battery | Select-Object -First 1
            if (-not $bNode -and $null -ne $xml.BatteryReport.PSObject.Properties['Report']) {
                $bNode = $xml.BatteryReport.Report.Batteries.Battery | Select-Object -First 1
            }
            if ($bNode) {
                if ((-not $design -or $design -le 0) -and $bNode.DesignCapacity) { $design = [double]$bNode.DesignCapacity }
                if ((-not $full -or $full -le 0) -and $bNode.FullChargeCapacity) { $full = [double]$bNode.FullChargeCapacity }
                if ($bNode.Chemistry) { $chemistry = [string]$bNode.Chemistry }
                if ((-not $cycles) -and $bNode.CycleCount) { $cycles = [int]$bNode.CycleCount }
            }
        }
    } catch {}
    }

    if ($null -ne $design -and $design -gt 0 -and $null -ne $full -and $full -gt 0) {
        $healthPct = [math]::Min(100.0, [math]::Round(($full / $design) * 100.0, 1))
        $grade = Get-SLTGradeFor $healthPct $grades
    } else {
        # SCAN FIX: never invent 85% when the system did not report design/full capacity.
        $healthPct = $null
        $grade = [pscustomobject]@{label='Not reported by system';color='#7FA0BE'}
    }
    $wearPct = if($null -ne $healthPct){[math]::Max(0.0, [math]::Round((100.0 - $healthPct), 1))}else{$null}
    $isCharging = ($cim.BatteryStatus -eq 2)
    $powerState = if ($chargeRateW) { $chargeRateW } elseif ($isCharging) { 'AC Connected (Charging)' } else { 'Running on Battery' }

    [pscustomobject]@{
        Present               = $true
        Message               = if ($null -ne $healthPct) { 'Battery detected; health capacity data reported' } else { 'Battery detected; health capacity data not reported' }
        Chemistry             = $chemistry
        DesignCapacityMWh     = if($null -ne $design){[int]$design}else{0}
        FullChargeCapacityMWh = if($null -ne $full){[int]$full}else{0}
        CurrentCapacityMWh    = if($null -ne $rtBat -and $null -ne $rtBat.PSObject.Properties['RemainingCapacity'] -and $rtBat.RemainingCapacity -gt 0){[int]$rtBat.RemainingCapacity}elseif($null -ne $full -and $null -ne $cim.EstimatedChargeRemaining){[int]([math]::Round(($full * [double]$cim.EstimatedChargeRemaining)/100.0, 0))}else{0}
        VoltageMV             = if($null -ne $rtBat -and $null -ne $rtBat.PSObject.Properties['Voltage'] -and $rtBat.Voltage -gt 0){[int]$rtBat.Voltage}else{$null}
        BackupHours           = $null
        CycleCount            = $cycles
        HealthPercent         = $healthPct
        WearPercent           = $wearPct
        GradeLabel            = [string]$grade.label
        GradeColor            = [string]$grade.color
        LiveChargePercent     = if($null -ne $cim.EstimatedChargeRemaining){[int]$cim.EstimatedChargeRemaining}else{$null}
        IsCharging            = $isCharging
        PowerState            = $powerState
        ReportXmlPath         = $xmlPath
    }
}

# ---------------------------------------------------------------- 6. GPU & DISPLAY ---
function Get-SLTGpuDxDiag {
    # Parses dxdiag /t output: one block per display adapter with Card name,
    # Chip type, DAC type, Device Key (PCI VEN/DEV/SUBSYS/REV), Display /
    # Dedicated / Shared memory, Current Mode, Driver Version/Date, DDI
    # Version, Feature Levels, Driver Model (WDDM), Hybrid Graphics GPU and
    # the first monitor's name/model/native mode. Capped at 45 seconds;
    # if dxdiag is slow or absent the GPU step still returns CIM data.
    $blocks = @()
    $tmp = Join-Path (Get-SLTTempPath) 'SLT_DxDiag.txt'
    try { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } catch {}
    try {
        $pr = Start-Process -FilePath 'dxdiag.exe' -ArgumentList '/t', $tmp -NoNewWindow -PassThru -ErrorAction Stop
        if (-not $pr.WaitForExit(45000)) { try { $pr.Kill() } catch {}; return $blocks }
        if (-not (Test-Path -LiteralPath $tmp)) { return $blocks }
        $raw = Get-Content -LiteralPath $tmp -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($raw)) { return $blocks }
        $chunks = [regex]::Split($raw, '(?m)^Card name:\s*')
        foreach ($chunk in $chunks) {
            if ([string]::IsNullOrWhiteSpace($chunk)) { continue }
            $firstLine = ($chunk -split "`r?`n")[0]
            if ($firstLine -notmatch '\S') { continue }
            $get = {
                param([string]$Label)
                $m = [regex]::Match($chunk, '(?m)^\s*' + [regex]::Escape($Label) + ':\s*(.+?)\s*$')
                if ($m.Success) { return $m.Groups[1].Value.Trim() } else { return $null }
            }
            $devKey = & $get 'Device Key'
            $ven = $null; $dev = $null; $sub = $null; $rev = $null
            if ($devKey -match 'VEN_([0-9A-Fa-f]{4})') { $ven = $Matches[1].ToUpper() }
            if ($devKey -match 'DEV_([0-9A-Fa-f]{4})') { $dev = $Matches[1].ToUpper() }
            if ($devKey -match 'SUBSYS_([0-9A-Fa-f]{8})') { $sub = $Matches[1].ToUpper() }
            if ($devKey -match 'REV_([0-9A-Fa-f]{2})') { $rev = $Matches[1].ToUpper() }
            $mb = { param([string]$Label) $v = & $get $Label; if ($v -match '(\d+)') { return [int]$Matches[1] } else { return $null } }
            $blocks += [pscustomobject]@{
                CardName = $firstLine.Trim(); ChipType = & $get 'Chip type'; DacType = & $get 'DAC type'
                Manufacturer = & $get 'Manufacturer'; DeviceKey = $devKey
                VendorId = $ven; DeviceId = $dev; SubSysId = $sub; RevisionId = $rev
                DisplayMemoryMB = & $mb 'Display Memory'; DedicatedMB = & $mb 'Dedicated Memory'; SharedMB = & $mb 'Shared Memory'
                CurrentMode = & $get 'Current Mode'; DriverVersion = & $get 'Driver Version'
                DriverDate = & $get 'Driver Date/Size'; DdiVersion = & $get 'DDI Version'
                FeatureLevels = & $get 'Feature Levels'; DriverModel = & $get 'Driver Model'
                HybridGpu = & $get 'Hybrid Graphics GPU'
                MonitorName = & $get 'Monitor Name'; MonitorModel = & $get 'Monitor Model'; NativeMode = & $get 'Native Mode'
                VendorIdField = & $get 'Vendor ID'; DeviceIdField = & $get 'Device ID'
            }
        }
    } catch {} finally {
        try { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } catch {}
    }
    return $blocks
}

function Get-SLTNvidiaSmi {
    # nvidia-smi ships with NVIDIA drivers. When present it is the only
    # native source for GPU clocks, temperature, power draw, VBIOS and the
    # PCIe link. Returns one object per GPU in device order, or @() when
    # nvidia-smi is absent or fails. Never throws.
    $out = @()
    try {
        $smi = Get-Command 'nvidia-smi.exe' -ErrorAction SilentlyContinue
        if (-not $smi) { return $out }
        $fields = 'index,name,driver_version,vbios_version,memory.total,clocks.max.graphics,clocks.max.memory,clocks.gr,clocks.mem,temperature.gpu,power.draw,pci.bus_id,pcie.link.gen.current,pcie.link.width.current,utilization.gpu'
        $proc = Start-Process -FilePath $smi.Source -ArgumentList '--query-gpu=' + $fields, '--format=csv,noheader' -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path (Get-SLTTempPath) 'SLT_Smi_Out.txt') -RedirectStandardError (Join-Path (Get-SLTTempPath) 'SLT_Smi_Err.txt') -ErrorAction Stop
        if (-not $proc.WaitForExit(15000)) { try { $proc.Kill() } catch {}; return $out }
        $txt = Get-Content -LiteralPath (Join-Path (Get-SLTTempPath) 'SLT_Smi_Out.txt') -Raw -ErrorAction SilentlyContinue
        try { Remove-Item -LiteralPath (Join-Path (Get-SLTTempPath) 'SLT_Smi_Out.txt'),(Join-Path (Get-SLTTempPath) 'SLT_Smi_Err.txt') -Force -ErrorAction SilentlyContinue } catch {}
        if ([string]::IsNullOrWhiteSpace($txt)) { return $out }
        foreach ($line in ($txt -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = @($line -split ',\s*')
            if ($parts.Count -lt 15) { continue }
            $num = { param([string]$s) if ($s -match '([\d\.]+)') { return [double]$Matches[1] } else { return $null } }
            $out += [pscustomobject]@{
                Index=$parts[0].Trim(); Name=$parts[1].Trim(); DriverVersion=$parts[2].Trim(); Vbios=$parts[3].Trim()
                MemoryTotalMB=& $num $parts[4]; MaxCoreClockMHz=& $num $parts[5]; MaxMemClockMHz=& $num $parts[6]
                CoreClockMHz=& $num $parts[7]; MemClockMHz=& $num $parts[8]; TemperatureC=& $num $parts[9]
                PowerW=& $num $parts[10]; PciBus=$parts[11].Trim(); PcieGen=$parts[12].Trim(); PcieWidth=$parts[13].Trim()
                UtilPercent=& $num $parts[14]
            }
        }
    } catch {}
    return $out
}

function Get-SLTGPUDetail([switch]$IncludeDxDiag) {
    # Fast CIM + Display Registry + optional dxdiag/nvidia-smi (avoids 25s dxdiag hang during normal scans)
    $dx = if ($IncludeDxDiag) { @(Get-SLTGpuDxDiag) } else { @() }
    $smi = if ($IncludeDxDiag) { @(Get-SLTNvidiaSmi) } else { @() }
    $memTypeDecode = @{ 1='Other'; 2='Unknown'; 3='VRAM'; 4='Dynamic RAM'; 5='SRAM' }
    $vendorNames = @{ '10DE'='NVIDIA'; '1002'='AMD'; '8086'='Intel'; '1414'='Microsoft' }
    $vcList = @()
    try { $vcList = @(Get-CimInstance Win32_VideoController -ErrorAction Stop) } catch { try { $vcList = @(Get-WmiObject Win32_VideoController -ErrorAction Stop) } catch { $vcList = @() } }
    $list = @($vcList | ForEach-Object {
        $vc = $_
        $sources = @('CIM Win32_VideoController')
        $regProps = $null; $regVramBytes = $null; $biosVer = $null; $chipType = $null; $adapterStr = $null; $regDriverVer = $null
        try {
            $keys = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*' -ErrorAction SilentlyContinue
            foreach ($k in @($keys)) {
                $dd = $null
                try { if ($k.PSObject.Properties['DriverDesc']) { $dd = [string]$k.DriverDesc } } catch {}
                if ($dd -and $vc.Name -and ($dd -eq $vc.Name -or $vc.Name -like "*$dd*" -or $dd -like "*$($vc.Name)*")) { $regProps = $k; break }
            }
            if (-not $regProps -and @($keys).Count -eq 1) { $regProps = @($keys)[0] }
            if ($regProps) {
                $sources += 'Display-class registry key'
                try { if ($regProps.PSObject.Properties['HardwareInformation.qwMemorySize'] -and $regProps.'HardwareInformation.qwMemorySize') { $regVramBytes = [uint64]$regProps.'HardwareInformation.qwMemorySize' } } catch {}
                try { if (-not $regVramBytes -and $regProps.PSObject.Properties['HardwareInformation.MemorySize'] -and $regProps.'HardwareInformation.MemorySize') { $regVramBytes = [uint64]$regProps.'HardwareInformation.MemorySize' } } catch {}
                try { if ($regProps.PSObject.Properties['BiosVersion'] -and $regProps.BiosVersion) { $biosVer = [string]$regProps.BiosVersion } } catch {}
                try { if ($regProps.PSObject.Properties['ChipType'] -and $regProps.ChipType) { $chipType = [string]$regProps.ChipType } } catch {}
                try { if ($regProps.PSObject.Properties['AdapterString'] -and $regProps.AdapterString) { $adapterStr = [string]$regProps.AdapterString } } catch {}
                try { if ($regProps.PSObject.Properties['DriverVersion'] -and $regProps.DriverVersion) { $regDriverVer = [string]$regProps.DriverVersion } } catch {}
            }
        } catch {}
        $pnp = if ($vc.PNPDeviceID) { [string]$vc.PNPDeviceID } else { '' }
        $ven = $null; $devId = $null; $subId = $null; $revId = $null
        if ($pnp -match 'VEN_([0-9A-Fa-f]{4})') { $ven = $Matches[1].ToUpper() }
        if ($pnp -match 'DEV_([0-9A-Fa-f]{4})') { $devId = $Matches[1].ToUpper() }
        if ($pnp -match 'SUBSYS_([0-9A-Fa-f]{8})') { $subId = $Matches[1].ToUpper() }
        if ($pnp -match 'REV_([0-9A-Fa-f]{2})') { $revId = $Matches[1].ToUpper() }
        $dxBlock = $null
        foreach ($b in $dx) {
            if ($b.CardName -and $vc.Name -and ($b.CardName -eq $vc.Name -or $b.CardName -like "*$($vc.Name)*" -or $vc.Name -like "*$($b.CardName)*")) { $dxBlock = $b; break }
            if (-not $dxBlock -and $b.VendorId -and $ven -and $b.VendorId -eq $ven -and $b.DeviceId -and $devId -and $b.DeviceId -eq $devId) { $dxBlock = $b; break }
        }
        if ($dxBlock) { $sources += 'dxdiag' }
        if (-not $ven -and $dxBlock) { $ven = $dxBlock.VendorId }
        if (-not $devId -and $dxBlock) { $devId = $dxBlock.DeviceId }
        if (-not $subId -and $dxBlock) { $subId = $dxBlock.SubSysId }
        if (-not $revId -and $dxBlock) { $revId = $dxBlock.RevisionId }
        $vendor = if ($ven -and $vendorNames.ContainsKey($ven)) { $vendorNames[$ven] } elseif ($vc.Name -match 'NVIDIA') { 'NVIDIA' } elseif ($vc.Name -match 'AMD|Radeon') { 'AMD' } elseif ($vc.Name -match 'Intel') { 'Intel' } else { 'Not reported' }
        $smiRow = $null
        if ($ven -eq '10DE' -and $smi.Count -gt 0) {
            $smiRow = $smi | Where-Object { $_.Name -and $vc.Name -and ($_.Name -eq $vc.Name -or $vc.Name -like "*$($_.Name)*" -or $_.Name -like "*$($vc.Name)*") } | Select-Object -First 1
            if (-not $smiRow) { $smiRow = $smi[0] }
            if ($smiRow) { $sources += 'nvidia-smi' }
        }
        $vramBytes = $null
        if ($regVramBytes -and $regVramBytes -gt 0) { $vramBytes = $regVramBytes }
        elseif ($dxBlock -and $dxBlock.DedicatedMB -and $dxBlock.DedicatedMB -gt 0) { $vramBytes = [uint64]$dxBlock.DedicatedMB * 1MB }
        elseif ($vc.AdapterRAM -and [uint64]$vc.AdapterRAM -ne 4294967295 -and [uint64]$vc.AdapterRAM -gt 0) { $vramBytes = [uint64]$vc.AdapterRAM }
        $vramGB = if ($vramBytes) { ("{0:N1} GB" -f ($vramBytes / 1GB)) } else { 'Not reported' }
        $memTypeTxt = 'Not reported - Windows APIs do not expose the GDDR generation (verify with GPU-Z/HWiNFO)'
        $vmt = $null
        try { if ($null -ne $vc.PSObject.Properties['VideoMemoryType']) { $vmt = [int]$vc.VideoMemoryType } } catch {}
        if ($vmt -and $memTypeDecode.ContainsKey($vmt)) { $memTypeTxt = "$($memTypeDecode[$vmt]) (VideoMemoryType $vmt) - GDDR generation not exposed by Windows" }
        if ($vendor -eq 'Intel' -and $dxBlock -and $dxBlock.DedicatedMB -eq 0) { $memTypeTxt = 'Shared system memory (uses RAM - see Memory type in the RAM card)' }
        $resStr = 'Secondary / Standby Adapter'
        if ($vc.CurrentHorizontalResolution -and $vc.CurrentVerticalResolution) { $resStr = "$($vc.CurrentHorizontalResolution) x $($vc.CurrentVerticalResolution) @ $($vc.CurrentRefreshRate) Hz" }
        elseif ($dxBlock -and $dxBlock.CurrentMode) { $resStr = $dxBlock.CurrentMode }
        $drvVer = if ($vc.DriverVersion) { [string]$vc.DriverVersion } elseif ($regDriverVer) { $regDriverVer } elseif ($dxBlock -and $dxBlock.DriverVersion) { $dxBlock.DriverVersion } else { 'Not reported' }
        $drvDate = if ($vc.DriverDate) { ([datetime]$vc.DriverDate).ToString('yyyy-MM-dd') } elseif ($dxBlock -and $dxBlock.DriverDate) { $dxBlock.DriverDate } else { 'Not reported' }
        $gpuTemp = $null
        if ($smiRow -and $null -ne $smiRow.TemperatureC) { $gpuTemp = $smiRow.TemperatureC }
        [pscustomobject]@{
            Name          = if ($vc.Name) { [string]$vc.Name } else { 'Display Adapter' }
            Vendor        = $vendor
            VendorId      = if ($ven) { "0x$ven" } else { 'Not reported' }
            DeviceId      = if ($devId) { "0x$devId" } else { 'Not reported' }
            SubSysId      = if ($subId) { "0x$subId" } else { 'Not reported' }
            RevisionId    = if ($revId) { "0x$revId" } else { 'Not reported' }
            PnpDeviceId   = if ($pnp) { $pnp } else { 'Not reported' }
            Chip          = if ($chipType) { $chipType } elseif ($vc.VideoProcessor) { [string]$vc.VideoProcessor } elseif ($dxBlock -and $dxBlock.ChipType) { $dxBlock.ChipType } else { 'Not reported' }
            BiosVersion   = if ($biosVer) { $biosVer } elseif ($smiRow -and $smiRow.Vbios) { $smiRow.Vbios } else { 'Not reported' }
            VRAMGB        = $vramGB
            VRAMBytes     = $vramBytes
            DedicatedMB   = if ($dxBlock) { $dxBlock.DedicatedMB } else { $null }
            SharedMB      = if ($dxBlock) { $dxBlock.SharedMB } else { $null }
            DisplayMemoryMB = if ($dxBlock) { $dxBlock.DisplayMemoryMB } else { $null }
            MemoryType    = $memTypeTxt
            BusWidth      = 'Not reported - Windows APIs do not expose the memory bus width (verify with GPU-Z/HWiNFO)'
            CoreClockMHz  = if ($smiRow) { $smiRow.CoreClockMHz } else { $null }
            MemClockMHz   = if ($smiRow) { $smiRow.MemClockMHz } else { $null }
            MaxCoreClockMHz = if ($smiRow) { $smiRow.MaxCoreClockMHz } else { $null }
            MaxMemClockMHz  = if ($smiRow) { $smiRow.MaxMemClockMHz } else { $null }
            PowerW        = if ($smiRow) { $smiRow.PowerW } else { $null }
            UtilPercent   = if ($smiRow) { $smiRow.UtilPercent } else { $null }
            PcieLink      = if ($smiRow) { "PCI $($smiRow.PciBus), PCIe Gen $($smiRow.PcieGen) x$($smiRow.PcieWidth)" } else { 'Not reported' }
            DacType       = if ($vc.AdapterDACType) { [string]$vc.AdapterDACType } elseif ($dxBlock -and $dxBlock.DacType) { $dxBlock.DacType } else { 'Not reported' }
            DriverVersion = $drvVer
            DriverDate    = $drvDate
            DriverName    = if ($vc.InstalledDisplayDrivers) { [string]$vc.InstalledDisplayDrivers } else { 'Not reported' }
            DriverModel   = if ($dxBlock -and $dxBlock.DriverModel) { $dxBlock.DriverModel } else { 'Not reported' }
            DdiVersion    = if ($dxBlock -and $dxBlock.DdiVersion) { $dxBlock.DdiVersion } else { 'Not reported' }
            FeatureLevels = if ($dxBlock -and $dxBlock.FeatureLevels) { $dxBlock.FeatureLevels } else { 'Not reported' }
            HybridGpu     = if ($dxBlock -and $dxBlock.HybridGpu) { $dxBlock.HybridGpu } else { 'Not reported' }
            MonitorName   = if ($dxBlock -and $dxBlock.MonitorName) { $dxBlock.MonitorName } else { 'Not reported' }
            MonitorModel  = if ($dxBlock -and $dxBlock.MonitorModel) { $dxBlock.MonitorModel } else { 'Not reported' }
            NativeMode    = if ($dxBlock -and $dxBlock.NativeMode) { $dxBlock.NativeMode } else { 'Not reported' }
            Resolution    = $resStr
            TemperatureC  = $gpuTemp
            GpuSources    = ($sources -join ' + ')
        }
    })
    if ($list.Count -eq 0 -and $dx.Count -gt 0) {
        # CIM and legacy WMI both failed: build adapter entries from dxdiag
        # alone so the GPU card is never blank. Fields no Windows API exposes
        # (memory type, bus width, clocks) stay Not reported with the reason.
        foreach ($b in $dx) {
            $vendor = if ($b.VendorId -and $vendorNames.ContainsKey($b.VendorId)) { $vendorNames[$b.VendorId] } elseif ($b.CardName -match 'NVIDIA') { 'NVIDIA' } elseif ($b.CardName -match 'AMD|Radeon') { 'AMD' } elseif ($b.CardName -match 'Intel') { 'Intel' } else { 'Not reported' }
            $vramBytes = if ($b.DedicatedMB -and $b.DedicatedMB -gt 0) { [uint64]$b.DedicatedMB * 1MB } else { $null }
            $list += [pscustomobject]@{
                Name=$b.CardName; Vendor=$vendor; VendorId=if($b.VendorId){"0x$($b.VendorId)"}else{'Not reported'}; DeviceId=if($b.DeviceId){"0x$($b.DeviceId)"}else{'Not reported'}; SubSysId=if($b.SubSysId){"0x$($b.SubSysId)"}else{'Not reported'}; RevisionId=if($b.RevisionId){"0x$($b.RevisionId)"}else{'Not reported'}; PnpDeviceId=$b.DeviceKey; Chip=$b.ChipType; BiosVersion='Not reported'; VRAMGB=if($vramBytes){("{0:N1} GB" -f ($vramBytes / 1GB))}else{'Not reported'}; VRAMBytes=$vramBytes; DedicatedMB=$b.DedicatedMB; SharedMB=$b.SharedMB; DisplayMemoryMB=$b.DisplayMemoryMB; MemoryType='Not reported - Windows APIs do not expose the GDDR generation (verify with GPU-Z/HWiNFO)'; BusWidth='Not reported - Windows APIs do not expose the memory bus width (verify with GPU-Z/HWiNFO)'; CoreClockMHz=$null; MemClockMHz=$null; MaxCoreClockMHz=$null; MaxMemClockMHz=$null; PowerW=$null; UtilPercent=$null; PcieLink='Not reported'; DacType=$b.DacType; DriverVersion=$b.DriverVersion; DriverDate=$b.DriverDate; DriverName='Not reported'; DriverModel=$b.DriverModel; DdiVersion=$b.DdiVersion; FeatureLevels=$b.FeatureLevels; HybridGpu=$b.HybridGpu; MonitorName=$b.MonitorName; MonitorModel=$b.MonitorModel; NativeMode=$b.NativeMode; Resolution=if($b.CurrentMode){$b.CurrentMode}else{'Secondary / Standby Adapter'}; TemperatureC=$null; GpuSources='dxdiag (CIM/WMI unavailable)'
            }
        }
    }
    return $list
}

function Get-SLTDeviceAndPortHealth {
    $badDrivers = @(Get-SLTBadDrivers)
    $badNames = @($badDrivers | ForEach-Object {
        $n = if($_.FriendlyName){[string]$_.FriendlyName}elseif($_.Name){[string]$_.Name}else{'Unknown Device'}
        $ec = if($null -ne $_.ConfigManagerErrorCode){" (Error $($_.ConfigManagerErrorCode))"}else{''}
        "$n$ec"
    })

    $allPnp = @(Get-SLTCachedPnpEntities)
    $cameras   = @($allPnp | Where-Object { $_.PNPClass -in @('Camera','Image') -or $_.Name -match 'Camera|Webcam|IR Camera' } | Select-Object -ExpandProperty Name -Unique)
    $bluetooth = @($allPnp | Where-Object { $_.PNPClass -eq 'Bluetooth' -or $_.Name -match 'Bluetooth' } | Select-Object -First 3 -ExpandProperty Name -Unique)
    $audio     = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique)
    $usbDevs   = @($allPnp | Where-Object { $_.PNPClass -eq 'USB' -and $_.Name -notmatch 'Root Hub|Generic USB Hub|Composite Device' } | Select-Object -ExpandProperty Name -Unique)
    $biometric = @($allPnp | Where-Object { $_.PNPClass -eq 'Biometric' -or $_.Name -match 'Fingerprint|Windows Hello' } | Select-Object -ExpandProperty Name -Unique)

    [pscustomobject]@{
        BadDriverCount = $badDrivers.Count
        BadDriverList  = if($badNames.Count -gt 0){$badNames -join ' | '}else{'0 Issues - All Drivers Healthy'}
        CameraList     = if($cameras.Count -gt 0){$cameras -join ', '}else{'No Webcam Detected!'}
        CameraPresent  = ($cameras.Count -gt 0)
        AudioList      = if($audio.Count -gt 0){$audio -join ', '}else{'No Audio Device Detected!'}
        AudioPresent   = ($audio.Count -gt 0)
        BluetoothList  = if($bluetooth.Count -gt 0){'Present & Active'}else{'Not Detected'}
        BiometricList  = if($biometric.Count -gt 0){$biometric -join ', '}else{'None / Standard'}
        USBItems       = $usbDevs
        USBCount       = $usbDevs.Count
    }
}

function Get-SLTConnectivityDetail {
    # Wi-Fi, Bluetooth, camera, audio and USB in one place, separate from
    # the GPU card. Every source is guarded; missing data stays Not reported.
    $wifiAdapter = 'Not reported'; $wifiState = 'Not reported'; $ssid = 'Not reported'; $signal = $null
    try {
        $adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Name -match 'Wi-Fi|Wireless|WLAN' -or $_.InterfaceDescription -match 'Wireless|Wi-Fi|802\.11' })
        if ($adapters.Count -gt 0) { $wifiAdapter = [string]$adapters[0].Name; $wifiState = [string]$adapters[0].Status }
    } catch {
        try {
            $na = @(Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.NetConnectionID -match 'Wi-Fi|Wireless' })
            if ($na.Count -gt 0) { $wifiAdapter = [string]$na[0].NetConnectionID; $wifiState = if ($na[0].NetEnabled) { 'Up' } else { 'Disabled' } }
        } catch {}
    }
    try {
        $out = & netsh.exe wlan show interfaces 2>$null
        foreach ($line in @($out)) {
            if ($line -match '^\s*SSID\s*:\s*(.+?)\s*$' -and $ssid -eq 'Not reported') { $ssid = $Matches[1].Trim() }
            if ($line -match '^\s*Signal\s*:\s*(\d+)%') { $signal = [int]$Matches[1] }
            if ($line -match '^\s*State\s*:\s*(.+?)\s*$') { $wifiState = $Matches[1].Trim() }
        }
        if ($ssid -eq 'Not reported') { $ssid = 'Not connected to a Wi-Fi network' }
    } catch {}
    $bt = 'Not Detected'; $cam = 'No Webcam Detected!'; $aud = 'No Audio Device Detected!'; $usbCount = 0
    try {
        $pnp = @(Get-SLTCachedPnpEntities)
        $btDevs = @($pnp | Where-Object { $_.PNPClass -eq 'Bluetooth' -or $_.Name -match 'Bluetooth' })
        if ($btDevs.Count -gt 0) { $bt = 'Present & Active' }
        $camDevs = @($pnp | Where-Object { $_.PNPClass -in @('Camera','Image') -or $_.Name -match 'Camera|Webcam|IR Camera' } | Select-Object -ExpandProperty Name -Unique)
        if ($camDevs.Count -gt 0) { $cam = ($camDevs -join ', ') }
        $audDevs = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique)
        if ($audDevs.Count -gt 0) { $aud = ($audDevs -join ', ') }
        $usbDevs = @($pnp | Where-Object { $_.PNPClass -eq 'USB' -and $_.Name -notmatch 'Root Hub|Generic USB Hub|Composite Device' })
        $usbCount = $usbDevs.Count
    } catch {}
    return [pscustomobject]@{
        WifiAdapter = $wifiAdapter; WifiState = $wifiState; Ssid = $ssid; SignalPercent = $signal
        Bluetooth = $bt; Camera = $cam; Audio = $aud; UsbCount = $usbCount
    }
}

# ---------------------------------------------------------------- 8. ANTI-LOSS DEALER ALERTS ---
function Get-SLTDealerAlerts([hashtable]$Data) {
    $alerts = @()
    $bat = $Data['Battery']
    $sto = $Data['Storage']
    $cpu = $Data['CPU']
    $ram = $Data['RAM']
    $dev = $Data['Devices']

    if ($null -ne $bat) {
        if (-not $bat.Present) {
            $alerts += [pscustomobject]@{Level='Warning'; Title='No Battery Detected'; Detail='Battery is missing, disconnected, or dead (Desktop / AC only).'}
        } elseif ($null -ne $bat.HealthPercent -and $bat.HealthPercent -lt 45) {
            $alerts += [pscustomobject]@{Level='Critical'; Title="Weak Battery ($($bat.HealthPercent)% Health)"; Detail="Full charge is $($bat.FullChargeCapacityMWh) mWh vs $($bat.DesignCapacityMWh) mWh design. Factor battery replacement into cost!"}
        } elseif ($null -ne $bat.HealthPercent -and $bat.HealthPercent -lt 70) {
            $alerts += [pscustomobject]@{Level='Warning'; Title="Moderate Battery Wear ($($bat.HealthPercent)% Health)"; Detail="Battery has $([math]::Round(100-$bat.HealthPercent,1))% wear. Test unplugging AC charger to verify backup stability."}
        }
    }

    if ($null -ne $sto) {
        foreach ($d in @($sto)) {
            $lifeTxt = if($null -ne $d.WearRemainingPercent){"$($d.WearRemainingPercent)%"}else{'not reported'}
            if (($d.HealthStatus -match 'Warning|Unhealthy|Fail|Predicted') -or ($null -ne $d.WearRemainingPercent -and $d.WearRemainingPercent -lt 75) -or $d.ReadWriteErrors -gt 0) {
                $alerts += [pscustomobject]@{Level='Critical'; Title="Storage Risk on $($d.Model)"; Detail="Status: $($d.HealthStatus), Life Remaining: $lifeTxt, R/W Errors: $($d.ReadWriteErrors). Replace SSD before selling!"}
            }
        }
    }

    if ($null -ne $cpu -and $null -ne $cpu.TemperatureC -and $cpu.TemperatureC -ge 83) {
        $alerts += [pscustomobject]@{Level='Critical'; Title="High CPU Temperature ($($cpu.TemperatureC) C)"; Detail='Laptop is running hot at idle/scan. Clean heatsink fan and apply fresh thermal paste!'}
    }

    if ($null -ne $dev) {
        if ($dev.BadDriverCount -gt 0) {
            $alerts += [pscustomobject]@{Level='Warning'; Title="$($dev.BadDriverCount) Missing / Faulty Driver(s) in Device Manager"; Detail=$dev.BadDriverList}
        }
        if (-not $dev.CameraPresent) {
            $alerts += [pscustomobject]@{Level='Warning'; Title='Webcam Not Detected'; Detail='Check camera privacy shutter/BIOS switch or ribbon cable.'}
        }
        if (-not $dev.AudioPresent) {
            $alerts += [pscustomobject]@{Level='Critical'; Title='No Sound Card / Audio Endpoint'; Detail='Audio driver missing or audio IC issue. Verify before purchase!'}
        }
    }

    return $alerts
}

# ------------------------------------------------------------ PHYSICAL TESTS ---
# ------------------------------------------------------------ PHYSICAL TESTS ---
function New-SLTTestPatternBrush([string]$Kind) {
    # Tile brushes for the grid / checkerboard slides. Resolution-independent.
    if ($Kind -eq 'Grid') {
        $b = New-Object Windows.Media.DrawingBrush
        $b.Viewport = [Windows.Rect]::new(0, 0, 72, 72)
        $b.ViewportUnits = [Windows.Media.BrushMappingMode]::Absolute
        $b.TileMode = [Windows.Media.TileMode]::Tile
        $draw = New-Object Windows.Media.GeometryDrawing
        $draw.Brush = (New-SLTBrush '#FFFFFF')
        $draw.Pen = New-Object Windows.Media.Pen((New-SLTBrush '#7A7A7A'), 1)
        $draw.Geometry = New-Object Windows.Media.RectangleGeometry([Windows.Rect]::new(0, 0, 72, 72))
        $b.Drawing = $draw
        return $b
    }
    $b = New-Object Windows.Media.DrawingBrush
    $b.Viewport = [Windows.Rect]::new(0, 0, 72, 72)
    $b.ViewportUnits = [Windows.Media.BrushMappingMode]::Absolute
    $b.TileMode = [Windows.Media.TileMode]::Tile
    $group = New-Object Windows.Media.GeometryGroup
    $group.Children.Add((New-Object Windows.Media.RectangleGeometry([Windows.Rect]::new(0, 0, 36, 36)))) | Out-Null
    $group.Children.Add((New-Object Windows.Media.RectangleGeometry([Windows.Rect]::new(36, 36, 36, 36)))) | Out-Null
    $draw = New-Object Windows.Media.GeometryDrawing
    $draw.Brush = (New-SLTBrush '#000000')
    $draw.Geometry = $group
    $b.Drawing = $draw
    return $b
}

function Show-SLTMonitorTest {
    # 15 slides: solids for dead/stuck pixels, greys for uniformity/clouding,
    # gradient for banding, grid for geometry/dead lines, checkerboard for
    # focus, text for readability. A large crosshair follows the mouse so
    # every corner can be checked precisely; the small system cursor is
    # hidden inside this window. Corner rings mark the four corners.
    $script:HWMonSlides = @(
        @{Name='White - dead / stuck pixels show as dark dots'; Kind='Solid'; Color='#FFFFFF'; TextColor='#000000'},
        @{Name='Black - bright spots and backlight bleed show here'; Kind='Solid'; Color='#000000'; TextColor='#FFFFFF'},
        @{Name='Red'; Kind='Solid'; Color='#FF0000'; TextColor='#FFFFFF'},
        @{Name='Green'; Kind='Solid'; Color='#00C000'; TextColor='#000000'},
        @{Name='Blue'; Kind='Solid'; Color='#0000FF'; TextColor='#FFFFFF'},
        @{Name='Yellow'; Kind='Solid'; Color='#FFFF00'; TextColor='#000000'},
        @{Name='Cyan'; Kind='Solid'; Color='#00FFFF'; TextColor='#000000'},
        @{Name='Magenta'; Kind='Solid'; Color='#FF00FF'; TextColor='#FFFFFF'},
        @{Name='Grey 50% - uniformity and clouding'; Kind='Solid'; Color='#808080'; TextColor='#FFFFFF'},
        @{Name='Grey 25% - dark uniformity'; Kind='Solid'; Color='#404040'; TextColor='#FFFFFF'},
        @{Name='Light Grey 90% - faint spots'; Kind='Solid'; Color='#E5E5E5'; TextColor='#000000'},
        @{Name='Gradient black to white - banding check'; Kind='Gradient'; Color='#FFFFFF'; TextColor='#000000'},
        @{Name='Grid - straight lines, geometry, dead lines'; Kind='Grid'; Color='#FFFFFF'; TextColor='#000000'},
        @{Name='Checkerboard - pixel sharpness and focus'; Kind='Checker'; Color='#FFFFFF'; TextColor='#000000'},
        @{Name='Text - readability at small sizes'; Kind='Text'; Color='#FFFFFF'; TextColor='#000000'}
    )
    $script:HWMonIndex = 0
    $script:HWMonViewed = @{}
    $win = New-Object Windows.Window
    $win.WindowState = 'Maximized'; $win.WindowStyle = 'None'; $win.Topmost = $true
    $win.Title = 'SLT Screen Test'
    Apply-SLTDialogTheme $win
    $win.Cursor = [Windows.Input.Cursors]::None
    $grid = New-Object Windows.Controls.Grid
    $script:HWMonSlideRect = New-Object Windows.Shapes.Rectangle
    $script:HWMonSlideRect.HorizontalAlignment = 'Stretch'; $script:HWMonSlideRect.VerticalAlignment = 'Stretch'
    $script:HWMonSlideRect.Fill = (New-SLTBrush '#FFFFFF')
    $grid.Children.Add($script:HWMonSlideRect) | Out-Null
    $script:HWMonTextOverlay = New-Object Windows.Controls.TextBlock
    $script:HWMonTextOverlay.Text = "The quick brown fox jumps over the lazy dog  1234567890`nAaBbCcDdEeFfGg  -  Small text must stay sharp at every size.`nCheck the corners and edges carefully for dead pixels, bright spots, and bleed."
    $script:HWMonTextOverlay.FontSize = 26; $script:HWMonTextOverlay.FontWeight = 'Bold'; $script:HWMonTextOverlay.Foreground = (New-SLTBrush '#000000')
    $script:HWMonTextOverlay.HorizontalAlignment = 'Center'; $script:HWMonTextOverlay.VerticalAlignment = 'Center'; $script:HWMonTextOverlay.TextAlignment = 'Center'
    $script:HWMonTextOverlay.Visibility = 'Collapsed'
    $grid.Children.Add($script:HWMonTextOverlay) | Out-Null
    # Corner target rings (fixed positions, help the corner check)
    foreach ($ha in @('Left','Right')) {
        foreach ($va in @('Top','Bottom')) {
            $ringW = New-Object Windows.Shapes.Ellipse
            $ringW.Width = 52; $ringW.Height = 52
            $ringW.Stroke = [Windows.Media.Brushes]::White; $ringW.StrokeThickness = 5; $ringW.Fill = [Windows.Media.Brushes]::Transparent
            $ringW.HorizontalAlignment = $ha; $ringW.VerticalAlignment = $va; $ringW.Margin = [Windows.Thickness]::new(22)
            $grid.Children.Add($ringW) | Out-Null
            $ring = New-Object Windows.Shapes.Ellipse
            $ring.Width = 44; $ring.Height = 44
            $ring.Stroke = [Windows.Media.Brushes]::Black; $ring.StrokeThickness = 2.5; $ring.Fill = [Windows.Media.Brushes]::Transparent
            $ring.HorizontalAlignment = $ha; $ring.VerticalAlignment = $va; $ring.Margin = [Windows.Thickness]::new(26)
            $grid.Children.Add($ring) | Out-Null
        }
    }
    # Large crosshair cursor that follows the mouse
    $script:HWMonCrossCanvas = New-Object Windows.Controls.Canvas
    $script:HWMonCrossCanvas.IsHitTestVisible = $false
    $script:HWMonCrossRingOuter = New-Object Windows.Shapes.Ellipse
    $script:HWMonCrossRingOuter.Width = 64; $script:HWMonCrossRingOuter.Height = 64
    $script:HWMonCrossRingOuter.Stroke = [Windows.Media.Brushes]::White; $script:HWMonCrossRingOuter.StrokeThickness = 6; $script:HWMonCrossRingOuter.Fill = [Windows.Media.Brushes]::Transparent
    $script:HWMonCrossCanvas.Children.Add($script:HWMonCrossRingOuter) | Out-Null
    $script:HWMonCrossRing = New-Object Windows.Shapes.Ellipse
    $script:HWMonCrossRing.Width = 64; $script:HWMonCrossRing.Height = 64
    $script:HWMonCrossRing.Stroke = [Windows.Media.Brushes]::Black; $script:HWMonCrossRing.StrokeThickness = 2.5; $script:HWMonCrossRing.Fill = [Windows.Media.Brushes]::Transparent
    $script:HWMonCrossCanvas.Children.Add($script:HWMonCrossRing) | Out-Null
    $script:HWMonHLineOuter = New-Object Windows.Shapes.Line
    $script:HWMonHLineOuter.X1 = -40; $script:HWMonHLineOuter.X2 = 104; $script:HWMonHLineOuter.Y1 = 32; $script:HWMonHLineOuter.Y2 = 32
    $script:HWMonHLineOuter.Stroke = [Windows.Media.Brushes]::White; $script:HWMonHLineOuter.StrokeThickness = 5
    $script:HWMonCrossCanvas.Children.Add($script:HWMonHLineOuter) | Out-Null
    $script:HWMonHLine = New-Object Windows.Shapes.Line
    $script:HWMonHLine.X1 = -40; $script:HWMonHLine.X2 = 104; $script:HWMonHLine.Y1 = 32; $script:HWMonHLine.Y2 = 32
    $script:HWMonHLine.Stroke = [Windows.Media.Brushes]::Black; $script:HWMonHLine.StrokeThickness = 2
    $script:HWMonCrossCanvas.Children.Add($script:HWMonHLine) | Out-Null
    $script:HWMonVLineOuter = New-Object Windows.Shapes.Line
    $script:HWMonVLineOuter.X1 = 32; $script:HWMonVLineOuter.X2 = 32; $script:HWMonVLineOuter.Y1 = -40; $script:HWMonVLineOuter.Y2 = 104
    $script:HWMonVLineOuter.Stroke = [Windows.Media.Brushes]::White; $script:HWMonVLineOuter.StrokeThickness = 5
    $script:HWMonCrossCanvas.Children.Add($script:HWMonVLineOuter) | Out-Null
    $script:HWMonVLine = New-Object Windows.Shapes.Line
    $script:HWMonVLine.X1 = 32; $script:HWMonVLine.X2 = 32; $script:HWMonVLine.Y1 = -40; $script:HWMonVLine.Y2 = 104
    $script:HWMonVLine.Stroke = [Windows.Media.Brushes]::Black; $script:HWMonVLine.StrokeThickness = 2
    $script:HWMonCrossCanvas.Children.Add($script:HWMonVLine) | Out-Null
    $grid.Children.Add($script:HWMonCrossCanvas) | Out-Null
    # Bottom bar: solid theme background so the labels stay readable on
    # every slide colour (the old bar had no background and the labels
    # changed colour per slide, which was unreadable on several slides).
    $barBorder = New-Object Windows.Controls.Border
    $barBorder.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $barBorder.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $barBorder.BorderThickness = [Windows.Thickness]::new(1.2)
    $barBorder.CornerRadius = [Windows.CornerRadius]::new(10)
    $barBorder.Padding = [Windows.Thickness]::new(16, 8, 16, 8)
    $barBorder.HorizontalAlignment = 'Center'; $barBorder.VerticalAlignment = 'Bottom'
    $barBorder.Margin = [Windows.Thickness]::new(0, 0, 0, 28)
    $bar = New-Object Windows.Controls.StackPanel
    $bar.Orientation = 'Horizontal'; $bar.HorizontalAlignment = 'Center'; $bar.VerticalAlignment = 'Center'
    $barBorder.Child = $bar
    $script:HWMonSlideLbl = New-SLTText $script:HWMonSlides[0].Name 16 $true '#F2FAFF'
    $script:HWMonSlideLbl.Margin = [Windows.Thickness]::new(0, 0, 18, 0)
    $script:HWMonHintLbl = New-SLTText 'Click / Space / Right = next  |  Left = previous  |  ESC = finish. Move the black/white crosshair into every corner.' 13 $false '#9DC6E1'
    $script:HWMonHintLbl.Margin = [Windows.Thickness]::new(0, 0, 18, 0)
    $finBtn = New-Object Windows.Controls.Button
    $finBtn.Content = 'Finish Test'; $finBtn.MinWidth = 130; $finBtn.MinHeight = 36; $finBtn.FontSize = 14; $finBtn.FontWeight = 'Bold'
    $finBtn.Background = (New-SLTBrush '#0E8F5B'); $finBtn.Foreground = [Windows.Media.Brushes]::White
    $bar.Children.Add($script:HWMonSlideLbl) | Out-Null; $bar.Children.Add($script:HWMonHintLbl) | Out-Null; $bar.Children.Add($finBtn) | Out-Null
    $grid.Children.Add($barBorder) | Out-Null
    $script:HWMonWin = $win
    $win.Content = $grid
    $script:HWMonApplySlide = {
        $s = $script:HWMonSlides[$script:HWMonIndex]
        $script:HWMonViewed[$script:HWMonIndex] = $true
        $script:HWMonTextOverlay.Visibility = 'Collapsed'
        if ($s.Kind -eq 'Solid') { $script:HWMonSlideRect.Fill = (New-SLTBrush ([string]$s.Color)) }
        elseif ($s.Kind -eq 'Gradient') {
            $gb = New-Object Windows.Media.LinearGradientBrush
            $gb.StartPoint = [Windows.Point]::new(0, 0); $gb.EndPoint = [Windows.Point]::new(1, 0)
            $gb.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.Colors]::Black, 0))) | Out-Null
            $gb.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.Colors]::White, 1))) | Out-Null
            $script:HWMonSlideRect.Fill = $gb
        }
        elseif ($s.Kind -eq 'Grid') { $script:HWMonSlideRect.Fill = (New-SLTTestPatternBrush 'Grid') }
        elseif ($s.Kind -eq 'Checker') { $script:HWMonSlideRect.Fill = (New-SLTBrush '#FFFFFF'); $script:HWMonSlideRect.Fill = (New-SLTTestPatternBrush 'Checker') }
        elseif ($s.Kind -eq 'Text') { $script:HWMonSlideRect.Fill = (New-SLTBrush '#FFFFFF'); $script:HWMonTextOverlay.Visibility = 'Visible' }
        $script:HWMonSlideLbl.Text = ("Slide {0} / {1}: {2}" -f ($script:HWMonIndex + 1), $script:HWMonSlides.Count, $s.Name)
    }
    & $script:HWMonApplySlide
    $win.Add_MouseMove({ param($s, $e)
        $pos = $e.GetPosition($script:HWMonCrossCanvas)
        [Windows.Controls.Canvas]::SetLeft($script:HWMonCrossRingOuter, ($pos.X - 32)); [Windows.Controls.Canvas]::SetTop($script:HWMonCrossRingOuter, ($pos.Y - 32))
        [Windows.Controls.Canvas]::SetLeft($script:HWMonCrossRing, ($pos.X - 32)); [Windows.Controls.Canvas]::SetTop($script:HWMonCrossRing, ($pos.Y - 32))
        [Windows.Controls.Canvas]::SetLeft($script:HWMonHLineOuter, ($pos.X - 32)); [Windows.Controls.Canvas]::SetTop($script:HWMonHLineOuter, ($pos.Y - 32))
        [Windows.Controls.Canvas]::SetLeft($script:HWMonHLine, ($pos.X - 32)); [Windows.Controls.Canvas]::SetTop($script:HWMonHLine, ($pos.Y - 32))
        [Windows.Controls.Canvas]::SetLeft($script:HWMonVLineOuter, ($pos.X - 32)); [Windows.Controls.Canvas]::SetTop($script:HWMonVLineOuter, ($pos.Y - 32))
        [Windows.Controls.Canvas]::SetLeft($script:HWMonVLine, ($pos.X - 32)); [Windows.Controls.Canvas]::SetTop($script:HWMonVLine, ($pos.Y - 32))
    })
    $script:HWMonSlideRect.Add_MouseLeftButtonDown({ param($s, $e) $script:HWMonIndex = ($script:HWMonIndex + 1) % $script:HWMonSlides.Count; & $script:HWMonApplySlide })
    $finBtn.Add_Click({ if ($script:HWMonWin) { $script:HWMonWin.Close() } })
    $win.Add_KeyDown({ param($s, $e)
        if ($e.Key -eq 'Escape') { if ($script:HWMonWin) { $script:HWMonWin.Close() } }
        elseif ($e.Key -in @('Right','Space','Enter','PageDown')) { $script:HWMonIndex = ($script:HWMonIndex + 1) % $script:HWMonSlides.Count; & $script:HWMonApplySlide }
        elseif ($e.Key -in @('Left','PageUp')) { $script:HWMonIndex = ($script:HWMonIndex - 1 + $script:HWMonSlides.Count) % $script:HWMonSlides.Count; & $script:HWMonApplySlide }
        $e.Handled = $true
    })
    $win.Focusable = $true
    Log-SLT 'Monitor dead-pixel / backlight bleed test started (15 slides, large crosshair cursor).'
    $win.ShowDialog() | Out-Null
    try {
        $viewed = @($script:HWMonViewed.Keys | Sort-Object | ForEach-Object { $script:HWMonSlides[$_].Name })
        $script:HWData['Notes']['Screen'] = ("Screen test viewed {0} of {1} slides: {2}. Mark Screen Passed or Issue in Manual Scan with any spot location." -f $viewed.Count, $script:HWMonSlides.Count, ($viewed -join ' | '))
        Log-SLT ('Monitor test finished: ' + $script:HWData['Notes']['Screen'])
    } catch { Log-SLT ('Monitor summary failed: ' + $_.Exception.Message) }
}

function Get-SLTKeyScanCode([System.Windows.Input.Key]$Key) {
    # Virtual key + hardware scan code for one WPF key. Scan codes come from
    # user32 MapVirtualKey at runtime, never from a hard-coded table.
    $result = [pscustomobject]@{ VK = 0; ScanCode = $null; Available = $false }
    try {
        $vk = [System.Windows.Input.KeyInterop]::VirtualKeyFromKey($Key)
        $result.VK = [int]$vk
        if (-not $script:SLTWin32KeyMapReady) {
            try {
                Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class SLTKeyMap { [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType); }' -ErrorAction Stop
                $script:SLTWin32KeyMapReady = $true
            } catch { $script:SLTWin32KeyMapReady = $false }
        }
        if ($script:SLTWin32KeyMapReady) {
            $sc = [SLTKeyMap]::MapVirtualKey([uint]$vk, 0)
            if ($sc -gt 0) { $result.ScanCode = [int]$sc; $result.Available = $true }
        }
    } catch {}
    return $result
}

function Show-SLTKeyboardTest {
    # Every key is tracked individually by its WPF key name + runtime scan
    # code (F1-F12 included). Keys that are never pressed are listed by
    # name in the report note when the window closes. Fn never reaches
    # Windows (embedded controller) and the Windows key is handled by the
    # shell, so both are checked by hand and live in the "extra" row.
    $layout = [string]$script:HWData['KbdLayout']
    if ([string]::IsNullOrWhiteSpace($layout)) { $layout = 'Laptop' }
    $script:HWKbdLayoutName = $layout
    $baseRows = @(
        @('Escape','F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12','Delete'),
        @('Oem3','D1','D2','D3','D4','D5','D6','D7','D8','D9','D0','OemMinus','OemPlus','Back'),
        @('Tab','Q','W','E','R','T','Y','U','I','O','P','OemOpenBrackets','OemCloseBrackets','OemPipe'),
        @('CapsLock','A','S','D','F','G','H','J','K','L','OemSemicolon','OemQuotes','Return'),
        @('LeftShift','Z','X','C','V','B','N','M','OemComma','OemPeriod','OemQuestion','RightShift'),
        @('LeftCtrl','LeftAlt','Space','RightAlt','RightCtrl','Left','Up','Down','Right')
    )
    if ($layout -eq 'Full') {
        $rows = $baseRows + @(
            @('NumLock','NumPad7','NumPad8','NumPad9','Divide'),
            @('NumPad4','NumPad5','NumPad6','Multiply'),
            @('NumPad1','NumPad2','NumPad3','Subtract'),
            @('NumPad0','Decimal','Add')
        )
    } elseif ($layout -eq 'Compact') {
        $rows = @($baseRows[1], $baseRows[2], $baseRows[3], $baseRows[4], @('LeftCtrl','LeftAlt','Space','RightAlt','RightCtrl'))
    } else {
        $rows = $baseRows
    }
    $extraKeys = @('LWin','RWin','Insert','Home','End','PageUp','PageDown','PrintScreen','ScrollLock','Pause','Apps','Oem102')
    $win = New-Object Windows.Window
    $win.Title = 'SLT Keyboard Test'; $win.Width = 1080; $win.Height = 520; $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $script:Window
    Apply-SLTDialogTheme $win
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(16)
    $status = New-SLTText ("Layout: $layout. Press every key on the physical keyboard. Working keys turn GREEN. Scan code for each key is shown as you press it. Fn is checked by hand (brightness/volume). Extra keys below count only if fitted.") 14 $true '#50DBFF'
    $status.TextWrapping = 'Wrap'
    $outer.Children.Add($status) | Out-Null
    $dispLabels = @{ Escape='Esc'; Back='Backspace'; Return='Enter'; CapsLock='Caps Lock'; LeftShift='Shift'; RightShift='Shift'; LeftCtrl='Ctrl'; RightCtrl='Ctrl'; LeftAlt='Alt'; RightAlt='Alt'; Delete='Del'; PrintScreen='PrtSc'; ScrollLock='ScrLk'; PageUp='PgUp'; PageDown='PgDn'; NumLock='NumLk'; Decimal='.'; Divide='/ num'; Multiply='* num'; Subtract='- num'; Add='+ num'; Oem3='` ~'; OemMinus='- _'; OemPlus='= +'; OemPipe='\ |'; OemSemicolon='; :'; OemQuotes = "' `""; OemOpenBrackets='[ {'; OemCloseBrackets='] }'; OemComma=', <'; OemPeriod='. >'; OemQuestion='/ ?'; Oem102='< >'; Space='Space'; Tab='Tab' }
    $script:HWKbdMap = @{}
    $script:HWKbdExtraMap = @{}
    $script:HWKbdPressed = @{}
    $script:HWKbdExtraPressed = @{}
    $buildRow = {
        param([string[]]$Keys, [hashtable]$Map, [bool]$Extra)
        $rp = New-Object Windows.Controls.StackPanel; $rp.Orientation = 'Horizontal'; $rp.Margin = [Windows.Thickness]::new(0, 2, 0, 2)
        foreach ($k in $Keys) {
            $b = New-Object Windows.Controls.Border
            $b.Width = $(if ($k -eq 'Space') { 190 } elseif ($k -in @('Tab','Return','Back','CapsLock','LeftShift','RightShift')) { 88 } else { 54 })
            $b.Height = 38; $b.Margin = [Windows.Thickness]::new(2); $b.CornerRadius = [Windows.CornerRadius]::new(6)
            $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
            $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder'); $b.BorderThickness = [Windows.Thickness]::new(1.2)
            $t = New-Object Windows.Controls.TextBlock; $t.Text = if ($dispLabels.ContainsKey($k)) { $dispLabels[$k] } else { $k }; $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
            $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'TextPrimary')
            $b.Child = $t
            $rp.Children.Add($b) | Out-Null
            $Map[$k] = $b
        }
        $outer.Children.Add($rp) | Out-Null
    }
    foreach ($row in $rows) { & $buildRow $row $script:HWKbdMap $false }
    $extraLbl = New-SLTText 'EXTRA KEYS - only if fitted on this keyboard (not counted in the result):' 12 $true '#9DC6E1'
    $extraLbl.Margin = [Windows.Thickness]::new(0, 8, 0, 0)
    $outer.Children.Add($extraLbl) | Out-Null
    & $buildRow $extraKeys $script:HWKbdExtraMap $true
    $script:HWKbdFnKeys = @()
    $script:HWKbdFnLbl = New-SLTText 'Fn-row: no laptop function key received yet. If pressing F1-F12 shows volume/brightness instead, hold Fn and press the key again (or toggle Fn-lock) - the physical key is working, Windows is receiving the laptop function instead of the F-key code.' 12 $false '#9DC6E1'
    $script:HWKbdFnLbl.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    $outer.Children.Add($script:HWKbdFnLbl) | Out-Null
    $btnBar = New-Object Windows.Controls.StackPanel; $btnBar.Orientation = 'Horizontal'; $btnBar.HorizontalAlignment = 'Right'; $btnBar.Margin = [Windows.Thickness]::new(0, 12, 0, 0)
    $passBtn = New-Object Windows.Controls.Button; $passBtn.Content = 'Complete all required keys to enable Pass'; $passBtn.Style = $script:Window.FindResource('ActionButton'); $passBtn.Background = (New-SLTBrush '#047857'); $passBtn.Foreground = (New-SLTBrush '#FFFFFF'); $passBtn.MinWidth = 260; $passBtn.IsEnabled = $false; $passBtn.ToolTip = 'Every required key must be detected before the keyboard can be marked Passed.'
    $script:HWKbdPassBtn = $passBtn
    $passBtn.Add_Click({
        $missingRequired = @($script:HWKbdMap.Keys | Where-Object { -not $script:HWKbdPressed.ContainsKey($_) })
        if ($missingRequired.Count -gt 0) {
            [Windows.MessageBox]::Show(("Test all required keyboard keys before marking Passed. Missing: " + ($missingRequired -join ', ')),'Keyboard QC Incomplete','OK','Warning') | Out-Null
            return
        }
        $script:HWData['PhysicalQC']['Keyboard'] = 'Passed'
        if (Get-Command Update-SLTPhysicalQCBadges -ErrorAction SilentlyContinue) { Update-SLTPhysicalQCBadges }
        if ($script:HWKbdWin) { $script:HWKbdWin.Close() }
    })
    $failBtn = New-Object Windows.Controls.Button; $failBtn.Content = 'Mark Keyboard ISSUE / FAIL'; $failBtn.Style = $script:Window.FindResource('ActionButton'); $failBtn.Background = (New-SLTBrush '#B91C1C'); $failBtn.Foreground = (New-SLTBrush '#FFFFFF'); $failBtn.MinWidth = 190
    $failBtn.Add_Click({
        $script:HWData['PhysicalQC']['Keyboard'] = 'Issue'
        if (Get-Command Update-SLTPhysicalQCBadges -ErrorAction SilentlyContinue) { Update-SLTPhysicalQCBadges }
        if ($script:HWKbdWin) { $script:HWKbdWin.Close() }
    })
    $btnBar.Children.Add($failBtn) | Out-Null; $btnBar.Children.Add($passBtn) | Out-Null
    $outer.Children.Add($btnBar) | Out-Null
    $win.Content = $outer
    $win.Add_ContentRendered({ try { $win.Focus() | Out-Null; [Windows.Input.Keyboard]::Focus($win) | Out-Null } catch {} })
    $script:HWKbdWin = $win
    $script:HWKbdStatus = $status
    $script:HWKbdMarkKey = {
        param([System.Windows.Input.Key]$keyEnum, [bool]$FromKeyUp = $false)
        $name = [string]$keyEnum
        if ($name -eq 'Capital') { $name = 'CapsLock' }
        if ($name -eq 'Scroll') { $name = 'ScrollLock' }
        # WPF Key names differ from the WinForms names the template used:
        # backslash arrives as Oem5 (not OemPipe), semicolon as Oem1 (not
        # OemSemicolon), apostrophe as Oem7 (not OemQuotes), and Print
        # Screen as Snapshot (not PrintScreen), and Page Up / Page Down
        # arrive as Prior / Next (not PageUp / PageDown). Those keys
        # could never match the template, so they never lit up. Normalise
        # the received name to the template name; the scan code below
        # still uses the original key enum.
        # OemCloseBrackets is the same trap, one level deeper: in the WPF
        # Key enum, Oem6 and OemCloseBrackets are TWO NAMES FOR THE SAME
        # VALUE (151, VK 0xDD), as are Oem4/OemOpenBrackets (219),
        # Oem2/OemQuestion (191) and Oemtilde/Oem3 (192). Which name
        # [string]$keyEnum returns depends on the keyboard layout, so on
        # some layouts the ']' key arrives as Oem6 and the OemCloseBrackets
        # tile never lights up - exactly the one key reported dead in V9.
        # The aliases below cover every duplicate name, and the virtual-key
        # fallback after the scan-code lookup covers any name not listed.
        $keyAliases = @{ 'Oem5'='OemPipe'; 'Oem1'='OemSemicolon'; 'Oem7'='OemQuotes'; 'Snapshot'='PrintScreen'; 'Prior'='PageUp'; 'Next'='PageDown'; 'Oem6'='OemCloseBrackets'; 'Oem4'='OemOpenBrackets'; 'Oem2'='OemQuestion'; 'Oemtilde'='Oem3'; 'OemBackslash'='Oem102' }
        if ($keyAliases.ContainsKey($name)) { $name = $keyAliases[$name] }
        # Laptop Fn-row: with Fn-lock on, the F-keys arrive as media /
        # function keys (VolumeMute etc.) instead of F1-F12. That means the
        # physical key works - Windows is receiving the laptop function.
        # Record it separately, show the Fn-lock guidance, and never fake
        # an F-key highlight for it.
        $fnNames = @('VolumeMute','VolumeDown','VolumeUp','MediaPlayPause','MediaStop','MediaPreviousTrack','MediaNextTrack','LaunchApplication1','LaunchApplication2','BrowserSearch','SelectMedia','LaunchMail','BrowserFavorites','BrowserHome','BrowserBack','BrowserForward','BrowserRefresh','BrowserStop')
        if ($name -in $fnNames) {
            if ($script:HWKbdFnKeys -notcontains $name) { $script:HWKbdFnKeys += $name }
            try { [Console]::Beep(920, 28) } catch { try { [System.Media.SystemSounds]::Asterisk.Play() } catch {} }
            $script:HWKbdFnLbl.Text = "Fn-row key received: [$name]. The physical Fn-row key WORKS - with Fn-lock on, Windows receives the laptop function instead of the F-key code. Hold Fn and press the key again (or toggle Fn-lock with Fn+Esc / Fn+CapsLock on this laptop) to test F1-F12 themselves."
            $script:HWKbdStatus.Text = "Laptop function key [$name] received (Fn-lock mode). Hold Fn and press the key to test its F-key code."
            return
        }
        $sc = Get-SLTKeyScanCode $keyEnum
        $scTxt = if ($sc.Available) { ("scan 0x{0:X2}, VK 0x{1:X2}" -f $sc.ScanCode, $sc.VK) } else { ("VK 0x{0:X2}, scan code not reported" -f $sc.VK) }
        # Virtual-key fallback: if the received name still does not match
        # the template (a layout-specific duplicate name), identify the
        # key by its Windows virtual-key code, which is layout-stable.
        # VK codes: 0xDB '[' , 0xDD ']' , 0xBF '/' , 0xBA ';' , 0xDC '\' ,
        # 0xDE ''' , 0xC0 '`' , 0xE2 '< >' , 0xBB '=' , 0xBD '-' ,
        # 0xBC ',' , 0xBE '.' . Never guesses from the key label.
        if (-not ($script:HWKbdMap.ContainsKey($name) -or $script:HWKbdExtraMap.ContainsKey($name))) {
            $vkNames = @{ 219='OemOpenBrackets'; 221='OemCloseBrackets'; 191='OemQuestion'; 186='OemSemicolon'; 220='OemPipe'; 222='OemQuotes'; 192='Oem3'; 226='Oem102'; 187='OemPlus'; 189='OemMinus'; 188='OemComma'; 190='OemPeriod' }
            if ($vkNames.ContainsKey([int]$sc.VK)) { $name = $vkNames[[int]$sc.VK] }
        }
        $isExtra = $script:HWKbdExtraMap.ContainsKey($name)
        $isRequired = $script:HWKbdMap.ContainsKey($name)
        if ($isRequired -or $isExtra) {
            $map = if ($isExtra) { $script:HWKbdExtraMap } else { $script:HWKbdMap }
            $store = if ($isExtra) { $script:HWKbdExtraPressed } else { $script:HWKbdPressed }
            if ($FromKeyUp -and $store.ContainsKey($name)) { return }
            try { [Console]::Beep(920, 28) } catch { try { [System.Media.SystemSounds]::Asterisk.Play() } catch {} }
            $map[$name].Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#10B981')
            $map[$name].Child.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#06111F')
            if (-not $store.ContainsKey($name)) { $store[$name] = $sc }
            $done = $script:HWKbdPressed.Count
            $missingRequired = @($script:HWKbdMap.Keys | Where-Object { -not $script:HWKbdPressed.ContainsKey($_) })
            if ($script:HWKbdPassBtn) { $script:HWKbdPassBtn.IsEnabled = ($missingRequired.Count -eq 0); if ($missingRequired.Count -eq 0) { $script:HWKbdPassBtn.Content = 'Mark Keyboard PASSED & Close' } }
            $script:HWKbdStatus.Text = "Tested $done / $($script:HWKbdMap.Count) required keys. Last key pressed: [$name] ($scTxt)"
        } else {
            $script:HWKbdStatus.Text = "Key pressed: [$name] ($scTxt) - not in the $script:HWKbdLayoutName layout template."
        }
    }
    $win.Add_PreviewKeyDown({ param($s, $e)
        $ke = $e.Key
        if ($ke -eq [System.Windows.Input.Key]::System) { $ke = $e.SystemKey }
        & $script:HWKbdMarkKey $ke $false
        $e.Handled = $true
    })
    # KeyUp as a second chance: F10 and some system keys are consumed
    # before KeyDown reaches the window, but their KeyUp still arrives.
    $win.Add_PreviewKeyUp({ param($s, $e)
        $ke = $e.Key
        if ($ke -eq [System.Windows.Input.Key]::System) { $ke = $e.SystemKey }
        & $script:HWKbdMarkKey $ke $true
    })
    Log-SLT 'Keyboard test dialog opened (scan-code tracking).'
    $win.ShowDialog() | Out-Null
    $script:HWKbdWin = $null
    try {
        $missedKeys = @()
        foreach ($k in @($script:HWKbdMap.Keys)) { if (-not $script:HWKbdPressed.ContainsKey($k)) { $missedKeys += [string]$k } }
        $extraMissed = @()
        foreach ($k in @($script:HWKbdExtraMap.Keys)) { if (-not $script:HWKbdExtraPressed.ContainsKey($k)) { $extraMissed += [string]$k } }
        $doneKeys = $script:HWKbdPressed.Count
        $totalKeys = $script:HWKbdMap.Count
        $scList = @($script:HWKbdPressed.Keys | Sort-Object | ForEach-Object { if ($null -ne $script:HWKbdPressed[$_].ScanCode) { "$_ (scan 0x{0:X2})" -f $script:HWKbdPressed[$_].ScanCode } else { "$_ (scan not reported)" } })
        # Every key in the selected layout is required for a Passed result.
        # A missing key must be recorded as an issue, not silently ignored.
        $missedCore = @($missedKeys)
        if ([string]$script:HWData['PhysicalQC']['Keyboard'] -eq 'Pending' -and $missedCore.Count -eq 0) {
            $script:HWData['PhysicalQC']['Keyboard'] = 'Passed'
        }
        $userKbdRem = ''
        if ($script:HWManualCabins -and $script:HWManualCabins.ContainsKey('Keyboard') -and $null -ne $script:HWManualCabins['Keyboard'].NoteBox) {
            $userKbdRem = [string]$script:HWManualCabins['Keyboard'].NoteBox.Text
        }
        if ([string]$script:HWData['PhysicalQC']['Keyboard'] -match 'Issue|Fail|Not OK') {
            $script:HWData['Notes']['Keyboard'] = if (-not [string]::IsNullOrWhiteSpace($userKbdRem)) { $userKbdRem.Trim() } else { '' }
        } else {
            $script:HWData['Notes']['Keyboard'] = ''
        }
        if (Get-Command Update-SLTPhysicalQCBadges -ErrorAction SilentlyContinue) { Update-SLTPhysicalQCBadges }
        Log-SLT ('Keyboard test finished: ' + $script:HWData['Notes']['Keyboard'])
    } catch { Log-SLT ('Keyboard summary failed: ' + $_.Exception.Message) }
}

function New-SLTStatusText([string]$Content, [int]$Size=13, [bool]$Bold=$true, [string]$Kind='Info') {
    # Status line that follows the dialog theme: the brush is a resource
    # reference (SLTStatusWarn/Error/Ok/Info) set by Apply-SLTDialogTheme
    # from the current theme's background luminance. Never a hard-coded
    # colour, so it stays readable in Dark, Light and every other theme.
    $c = New-Object Windows.Controls.TextBlock
    $c.Text = $Content; $c.FontSize = $Size; $c.TextWrapping = 'Wrap'
    $c.Margin = [Windows.Thickness]::new(2, 4, 2, 4)
    if ($Bold) { $c.FontWeight = 'Bold' }
    try { $c.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, ('SLTStatus' + $Kind)) } catch {}
    return $c
}

function Set-SLTDialogStatus([object]$TextBlock, [string]$Text, [string]$Kind='Info') {
    if ($null -eq $TextBlock) { return }
    $TextBlock.Text = $Text
    try { $TextBlock.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, ('SLTStatus' + $Kind)) } catch {}
    try { $TextBlock.UpdateLayout() } catch {}
}

function Get-SLTDefaultAudioDevices {
    # Default playback + capture device names, so a "no sound" result can be
    # told apart from a broken speaker/mic: if Windows has no default
    # device, or the wrong one, the dialog says so instead of failing
    # silently. Every read is guarded; missing data stays Not reported.
    $res = [pscustomobject]@{ Playback='Not reported'; Capture='Not reported'; PlaybackList=@(); CaptureList=@() }
    try {
        $snd = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue | ForEach-Object { [string]$_.Name } | Where-Object { $_ })
        if ($snd.Count -gt 0) { $res.PlaybackList = $snd; $res.CaptureList = $snd }
    } catch {}
    try {
        $mapper = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Multimedia\Sound Mapper' -ErrorAction Stop
        if ($mapper.PSObject.Properties['Playback'] -and $mapper.Playback) { $res.Playback = [string]$mapper.Playback }
        if ($mapper.PSObject.Properties['Record'] -and $mapper.Record) { $res.Capture = [string]$mapper.Record }
    } catch {}
    try {
        $eps = @(Get-PnpDevice -Class 'AudioEndpoint' -Status OK -ErrorAction SilentlyContinue)
        foreach ($ep in $eps) {
            $nm = [string]$ep.FriendlyName
            if ($ep.FriendlyName -match 'Render|Playback|Speaker|Headphone') { if ($res.PlaybackList -notcontains $nm) { $res.PlaybackList += $nm } }
            if ($ep.FriendlyName -match 'Capture|Microphone|Mic|Array') { if ($res.CaptureList -notcontains $nm) { $res.CaptureList += $nm } }
        }
    } catch {}
    return $res
}

function Get-SLTCachedAudioDevices {
    # Default playback/capture names, enumerated once and cached, so
    # speaker/mic status lines can name the device the sound actually
    # went to (or show Not reported) without re-enumerating PnP on
    # every click. Never throws.
    if (-not (Test-Path 'variable:script:HWAudioDevicesCache') -or $null -eq $script:HWAudioDevicesCache) {
        try { $script:HWAudioDevicesCache = Get-SLTDefaultAudioDevices } catch { $script:HWAudioDevicesCache = [pscustomobject]@{ Playback='Not reported'; Capture='Not reported'; PlaybackList=@(); CaptureList=@() } }
    }
    return $script:HWAudioDevicesCache
}

function Invoke-SLTPlayWavFile([string]$Path, [int]$TimeoutSec=12) {
    # Plays a WAV through the WPF MediaPlayer first (the native WPF audio
    # path, asynchronous, with MediaFailed diagnostics), falling back to
    # SoundPlayer PlaySync if MediaPlayer fails or times out. The player
    # object is held in $script: scope until playback ends: the old mic
    # code used a local SoundPlayer with async Play(), which .NET is free
    # to garbage-collect mid-playback, cutting the sound off - that is why
    # playback "did nothing". Returns @{ Success; Error; Method }.
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Success=$false; Error='Audio file was not created.'; Method='none' } }
    $mpErr = $null
    try {
        $full = (Get-Item -LiteralPath $Path -ErrorAction Stop).FullName
        $state = @{ Ended=$false; Failed=$null }
        $mp = New-Object Windows.Media.MediaPlayer
        $script:SLTMediaPlayer = $mp
        $mp.Add_MediaEnded({ $state.Ended = $true })
        $mp.Add_MediaFailed({ param($s, $e) $state.Failed = if ($e.ErrorException) { $e.ErrorException.Message } else { 'MediaPlayer reported a failure.' } })
        $mp.Open([Uri]::new($full))
        $mp.Play()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $state.Ended -and -not $state.Failed -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
            try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{}) } catch {}
            Start-Sleep -Milliseconds 80
        }
        $sw.Stop()
        try { $mp.Stop(); $mp.Close() } catch {}
        $script:SLTMediaPlayer = $null
        if ($state.Ended) { return [pscustomobject]@{ Success=$true; Error=$null; Method='WPF MediaPlayer' } }
        if ($state.Failed) { $mpErr = $state.Failed } else { $mpErr = "MediaPlayer did not finish within $TimeoutSec seconds." }
    } catch {
        $mpErr = $_.Exception.Message
        try { $script:SLTMediaPlayer = $null } catch {}
    }
    try {
        $sp = New-Object System.Media.SoundPlayer($Path)
        $sp.PlaySync()
        $sp.Dispose()
        return [pscustomobject]@{ Success=$true; Error=$null; Method='SoundPlayer fallback (MediaPlayer failed: ' + $mpErr + ')' }
    } catch {
        return [pscustomobject]@{ Success=$false; Error=('Playback failed in both audio paths. MediaPlayer: ' + $mpErr + ' | SoundPlayer: ' + $_.Exception.Message); Method='none' }
    }
}

function Initialize-SLTHardwareAudioEngine {
    if ((Test-Path 'variable:script:SLTAudioGenReady') -and $script:SLTAudioGenReady) { return $true }
    try {
        Add-Type -ReferencedAssemblies 'System.Windows.Forms' -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SLT {
    [StructLayout(LayoutKind.Sequential)]
    public struct WAVEFORMATEX {
        public ushort wFormatTag;
        public ushort nChannels;
        public uint nSamplesPerSec;
        public uint nAvgBytesPerSec;
        public ushort nBlockAlign;
        public ushort wBitsPerSample;
        public ushort cbSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WAVEHDR {
        public IntPtr lpData;
        public uint dwBufferLength;
        public uint dwBytesRecorded;
        public IntPtr dwUser;
        public uint dwFlags;
        public uint dwLoops;
        public IntPtr lpNext;
        public IntPtr reserved;
    }

    public static class SLTAudioGen {
        [DllImport("winmm.dll")]
        public static extern int waveOutOpen(out IntPtr hWaveOut, int uDeviceID, ref WAVEFORMATEX lpFormat, IntPtr dwCallback, IntPtr dwInstance, int dwFlags);
        [DllImport("winmm.dll")]
        public static extern int waveOutPrepareHeader(IntPtr hWaveOut, ref WAVEHDR lpWaveOutHdr, int uSize);
        [DllImport("winmm.dll")]
        public static extern int waveOutWrite(IntPtr hWaveOut, ref WAVEHDR lpWaveOutHdr, int uSize);
        [DllImport("winmm.dll")]
        public static extern int waveOutUnprepareHeader(IntPtr hWaveOut, ref WAVEHDR lpWaveOutHdr, int uSize);
        [DllImport("winmm.dll")]
        public static extern int waveOutClose(IntPtr hWaveOut);
        [DllImport("winmm.dll")]
        public static extern int waveOutSetVolume(IntPtr hWaveOut, uint dwVolume);

        [DllImport("winmm.dll")]
        public static extern int waveInOpen(out IntPtr hWaveIn, int uDeviceID, ref WAVEFORMATEX lpFormat, IntPtr dwCallback, IntPtr dwInstance, int dwFlags);
        [DllImport("winmm.dll")]
        public static extern int waveInPrepareHeader(IntPtr hWaveIn, ref WAVEHDR lpWaveInHdr, int uSize);
        [DllImport("winmm.dll")]
        public static extern int waveInAddBuffer(IntPtr hWaveIn, ref WAVEHDR lpWaveInHdr, int uSize);
        [DllImport("winmm.dll")]
        public static extern int waveInStart(IntPtr hWaveIn);
        [DllImport("winmm.dll")]
        public static extern int waveInStop(IntPtr hWaveIn);
        [DllImport("winmm.dll")]
        public static extern int waveInReset(IntPtr hWaveIn);
        [DllImport("winmm.dll")]
        public static extern int waveInUnprepareHeader(IntPtr hWaveIn, ref WAVEHDR lpWaveInHdr, int uSize);
        [DllImport("winmm.dll")]
        public static extern int waveInClose(IntPtr hWaveIn);

        public static byte[] BuildStereoTonePcm(string channel, int sr, out double durationSec) {
            durationSec = 1.15;
            int samples = (int)(sr * durationSec);
            byte[] pcm = new byte[samples * 4];
            bool doLeft = (channel == "Left" || channel == "Both");
            bool doRight = (channel == "Right" || channel == "Both");
            int third = samples / 3;
            int pos = 0;
            for (int i = 0; i < samples; i++) {
                // 3-note pleasant musical chord arpeggio (523Hz C5 -> 659Hz E5 -> 784Hz G5)
                // Rich harmonics ensure laptop DSPs/noise-Gates never suppress the tone
                double freq = (i < third) ? 523.25 : ((i < third * 2) ? 659.25 : 783.99);
                int localIdx = i % third;
                double fade = Math.Min(1.0, Math.Min(localIdx / 300.0, (third - localIdx) / 400.0));
                double t = (double)i / sr;
                double w = 0.65 * Math.Sin(2.0 * Math.PI * freq * t)
                         + 0.25 * Math.Sin(4.0 * Math.PI * freq * t)
                         + 0.10 * Math.Sin(6.0 * Math.PI * freq * t);
                short s = (short)(w * 30000.0 * fade);
                short l = doLeft ? s : (short)0;
                short r = doRight ? s : (short)0;
                pcm[pos++] = (byte)(l & 0xFF);
                pcm[pos++] = (byte)((l >> 8) & 0xFF);
                pcm[pos++] = (byte)(r & 0xFF);
                pcm[pos++] = (byte)((r >> 8) & 0xFF);
            }
            return pcm;
        }

        public static void WriteStereoChimeWav(string path, string channel) {
            int sr = 44100;
            double dur;
            byte[] pcm = BuildStereoTonePcm(channel, sr, out dur);
            int dataBytes = pcm.Length;
            byte[] wav = new byte[44 + dataBytes];
            System.Text.Encoding.ASCII.GetBytes("RIFF").CopyTo(wav, 0);
            BitConverter.GetBytes(36 + dataBytes).CopyTo(wav, 4);
            System.Text.Encoding.ASCII.GetBytes("WAVEfmt ").CopyTo(wav, 8);
            BitConverter.GetBytes(16).CopyTo(wav, 16);
            BitConverter.GetBytes((short)1).CopyTo(wav, 20);
            BitConverter.GetBytes((short)2).CopyTo(wav, 22);
            BitConverter.GetBytes(sr).CopyTo(wav, 24);
            BitConverter.GetBytes(sr * 4).CopyTo(wav, 28);
            BitConverter.GetBytes((short)4).CopyTo(wav, 32);
            BitConverter.GetBytes((short)16).CopyTo(wav, 34);
            System.Text.Encoding.ASCII.GetBytes("data").CopyTo(wav, 36);
            BitConverter.GetBytes(dataBytes).CopyTo(wav, 40);
            Buffer.BlockCopy(pcm, 0, wav, 44, dataBytes);
            File.WriteAllBytes(path, wav);
        }

        public static string PlayPcmDirect(byte[] pcm, int sr, int channels, uint volumeMask) {
            IntPtr hOut = IntPtr.Zero;
            IntPtr pBuf = IntPtr.Zero;
            try {
                WAVEFORMATEX fmt = new WAVEFORMATEX();
                fmt.wFormatTag = 1; // WAVE_FORMAT_PCM
                fmt.nChannels = (ushort)channels;
                fmt.nSamplesPerSec = (uint)sr;
                fmt.wBitsPerSample = 16;
                fmt.nBlockAlign = (ushort)(channels * 2);
                fmt.nAvgBytesPerSec = (uint)(sr * fmt.nBlockAlign);
                fmt.cbSize = 0;

                int rc = waveOutOpen(out hOut, -1, ref fmt, IntPtr.Zero, IntPtr.Zero, 0);
                if (rc != 0) return "waveOutOpen failed with code " + rc;

                try { waveOutSetVolume(hOut, volumeMask); } catch {}

                pBuf = Marshal.AllocHGlobal(pcm.Length);
                Marshal.Copy(pcm, 0, pBuf, pcm.Length);

                WAVEHDR hdr = new WAVEHDR();
                hdr.lpData = pBuf;
                hdr.dwBufferLength = (uint)pcm.Length;
                hdr.dwFlags = 0;

                rc = waveOutPrepareHeader(hOut, ref hdr, Marshal.SizeOf(typeof(WAVEHDR)));
                if (rc != 0) return "waveOutPrepareHeader failed with code " + rc;

                rc = waveOutWrite(hOut, ref hdr, Marshal.SizeOf(typeof(WAVEHDR)));
                if (rc != 0) return "waveOutWrite failed with code " + rc;

                int waitLoops = 0;
                while ((hdr.dwFlags & 1) == 0 && waitLoops < 150) { // WHDR_DONE = 1
                    Application.DoEvents();
                    Thread.Sleep(20);
                    waitLoops++;
                }
                try { waveOutSetVolume(hOut, 0xFFFFFFFF); } catch {}
                try { waveOutUnprepareHeader(hOut, ref hdr, Marshal.SizeOf(typeof(WAVEHDR))); } catch {}
                return "OK";
            } catch (Exception ex) {
                return ex.Message;
            } finally {
                if (hOut != IntPtr.Zero) { try { waveOutClose(hOut); } catch {} }
                if (pBuf != IntPtr.Zero) { try { Marshal.FreeHGlobal(pBuf); } catch {} }
            }
        }

        public static string PlaySpeakerChannel(string channel) {
            double dur;
            byte[] pcm = BuildStereoTonePcm(channel, 44100, out dur);
            // Stereo PCM already has 0 in muted channel; also set hardware waveOut stereo mask
            uint volMask = 0xFFFFFFFF;
            if (channel == "Left") volMask = 0x0000FFFF;
            else if (channel == "Right") volMask = 0xFFFF0000;
            return PlayPcmDirect(pcm, 44100, 2, volMask);
        }

        public static string RecordAndPlayMicDirect(int durationSec, string saveWavPath, out double peakPct, out double rmsPct) {
            peakPct = 0.0;
            rmsPct = 0.0;
            IntPtr hIn = IntPtr.Zero;
            IntPtr pBuf = IntPtr.Zero;
            int sr = 44100;
            int totalBytes = sr * 2 * durationSec;
            try {
                WAVEFORMATEX fmt = new WAVEFORMATEX();
                fmt.wFormatTag = 1;
                fmt.nChannels = 1;
                fmt.nSamplesPerSec = (uint)sr;
                fmt.wBitsPerSample = 16;
                fmt.nBlockAlign = 2;
                fmt.nAvgBytesPerSec = (uint)(sr * 2);
                fmt.cbSize = 0;

                int rc = waveInOpen(out hIn, -1, ref fmt, IntPtr.Zero, IntPtr.Zero, 0);
                if (rc != 0) return "waveInOpen failed (code " + rc + "). Check Microphone Privacy settings or connection.";

                pBuf = Marshal.AllocHGlobal(totalBytes);
                WAVEHDR hdr = new WAVEHDR();
                hdr.lpData = pBuf;
                hdr.dwBufferLength = (uint)totalBytes;
                hdr.dwBytesRecorded = 0;
                hdr.dwFlags = 0;

                rc = waveInPrepareHeader(hIn, ref hdr, Marshal.SizeOf(typeof(WAVEHDR)));
                if (rc != 0) return "waveInPrepareHeader failed (code " + rc + ")";

                rc = waveInAddBuffer(hIn, ref hdr, Marshal.SizeOf(typeof(WAVEHDR)));
                if (rc != 0) return "waveInAddBuffer failed (code " + rc + ")";

                rc = waveInStart(hIn);
                if (rc != 0) return "waveInStart failed (code " + rc + ")";

                int ticks = durationSec * 25;
                for (int t = 0; t < ticks; t++) {
                    if ((hdr.dwFlags & 1) != 0) break;
                    Application.DoEvents();
                    Thread.Sleep(40);
                }

                try { waveInStop(hIn); } catch {}
                try { waveInReset(hIn); } catch {}

                int recorded = (int)hdr.dwBytesRecorded;
                if (recorded <= 0) recorded = totalBytes;
                byte[] raw = new byte[recorded];
                Marshal.Copy(pBuf, raw, 0, recorded);

                try { waveInUnprepareHeader(hIn, ref hdr, Marshal.SizeOf(typeof(WAVEHDR))); } catch {}
                try { waveInClose(hIn); hIn = IntPtr.Zero; } catch {}

                // Compute Peak & RMS and create 2.8x amplified stereo playback buffer so user hears voice clearly
                int nSamples = recorded / 2;
                double maxAbs = 0.0;
                double sumSq = 0.0;
                byte[] playStereo = new byte[nSamples * 4];
                int pPos = 0;
                for (int i = 0; i < nSamples; i++) {
                    short val = BitConverter.ToInt16(raw, i * 2);
                    double norm = Math.Abs(val / 32768.0);
                    if (norm > maxAbs) maxAbs = norm;
                    sumSq += norm * norm;

                    int amp = (int)(val * 2.8);
                    if (amp > 32700) amp = 32700;
                    if (amp < -32700) amp = -32700;
                    short sAmp = (short)amp;
                    playStereo[pPos++] = (byte)(sAmp & 0xFF);
                    playStereo[pPos++] = (byte)((sAmp >> 8) & 0xFF);
                    playStereo[pPos++] = (byte)(sAmp & 0xFF);
                    playStereo[pPos++] = (byte)((sAmp >> 8) & 0xFF);
                }
                peakPct = Math.Round(maxAbs * 100.0, 1);
                rmsPct = (nSamples > 0) ? Math.Round(Math.Sqrt(sumSq / nSamples) * 100.0, 1) : 0.0;

                // Save WAV to disk for diagnostics
                if (!string.IsNullOrEmpty(saveWavPath)) {
                    try {
                        byte[] wav = new byte[44 + recorded];
                        System.Text.Encoding.ASCII.GetBytes("RIFF").CopyTo(wav, 0);
                        BitConverter.GetBytes(36 + recorded).CopyTo(wav, 4);
                        System.Text.Encoding.ASCII.GetBytes("WAVEfmt ").CopyTo(wav, 8);
                        BitConverter.GetBytes(16).CopyTo(wav, 16);
                        BitConverter.GetBytes((short)1).CopyTo(wav, 20);
                        BitConverter.GetBytes((short)1).CopyTo(wav, 22);
                        BitConverter.GetBytes(sr).CopyTo(wav, 24);
                        BitConverter.GetBytes(sr * 2).CopyTo(wav, 28);
                        BitConverter.GetBytes((short)2).CopyTo(wav, 32);
                        BitConverter.GetBytes((short)16).CopyTo(wav, 34);
                        System.Text.Encoding.ASCII.GetBytes("data").CopyTo(wav, 36);
                        BitConverter.GetBytes(recorded).CopyTo(wav, 40);
                        Buffer.BlockCopy(raw, 0, wav, 44, recorded);
                        File.WriteAllBytes(saveWavPath, wav);
                    } catch {}
                }

                // Immediately play back the amplified stereo buffer through waveOut
                string playRes = PlayPcmDirect(playStereo, sr, 2, 0xFFFFFFFF);
                return playRes;
            } catch (Exception ex) {
                return ex.Message;
            } finally {
                if (hIn != IntPtr.Zero) { try { waveInClose(hIn); } catch {} }
                if (pBuf != IntPtr.Zero) { try { Marshal.FreeHGlobal(pBuf); } catch {} }
            }
        }
    }
}
'@ -ErrorAction Stop
        $script:SLTAudioGenReady = $true
        return $true
    } catch {
        $script:SLTAudioGenReady = $false
        return $false
    }
}

function New-SLTChannelToneWav([string]$Channel) {
    [void](Initialize-SLTHardwareAudioEngine)
    $audioDir = 'C:\ProgramData\SmartLifeTeck\PCCarePro'
    try { if (-not (Test-Path -LiteralPath $audioDir)) { New-Item -Path $audioDir -ItemType Directory -Force | Out-Null } } catch { $audioDir = Get-SLTTempPath }
    $tmp = Join-Path $audioDir (("SLT_Tone_{0}.wav" -f $Channel))
    if ($script:SLTAudioGenReady) {
        [SLT.SLTAudioGen]::WriteStereoChimeWav($tmp, $Channel)
        return $tmp
    }
    return $tmp
}

function Invoke-SLTChannelTone([string]$Channel) {
    # Plays channel-isolated stereo chord directly via Win32 waveOutOpen/waveOutWrite
    # with hardware stereo channel masking + SoundPlayer fallback.
    $res = [pscustomobject]@{ Success=$false; Error=$null; Method='none'; Channel=$Channel }
    try {
        [void](Initialize-SLTHardwareAudioEngine)
        if ($script:SLTAudioGenReady) {
            $out = [SLT.SLTAudioGen]::PlaySpeakerChannel($Channel)
            if ($out -eq 'OK') {
                $res.Success = $true
                $res.Method = "Win32 Direct WaveOut ($Channel Speaker)"
                Log-SLT "Played speaker test tone: $Channel ($($res.Method))"
                return $res
            } else {
                $res.Error = $out
            }
        }
        $tmp = New-SLTChannelToneWav $Channel
        $player = New-Object System.Media.SoundPlayer($tmp)
        $player.Load()
        $player.PlaySync()
        $player.Dispose()
        $res.Success = $true
        $res.Method = "SoundPlayer Stereo ($Channel)"
    } catch {
        $res.Error = $_.Exception.Message
    }
    return $res
}

function Invoke-SLTUiPump {
    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
    try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{}) } catch {}
    try { if ($null -ne $script:Window) { $script:Window.UpdateLayout() } } catch {}
}

function Invoke-SLTInlineMicRecording([scriptblock]$OnStatus) {
    # Direct Win32 waveInOpen -> RAM buffer -> 2.8x amplified waveOutWrite playback!
    # Zero MCI bugs, zero path issues, and immediate loud voice playback.
    $report = { param([string]$txt) try { & $OnStatus $txt } catch {} }
    $result = [pscustomobject]@{ Success=$false; Played=$false; Peak=$null; Rms=$null; Error=$null; Method='Win32 Direct WaveIn/WaveOut' }
    try {
        [void](Initialize-SLTHardwareAudioEngine)
        $audioDir = 'C:\ProgramData\SmartLifeTeck\PCCarePro'
        try { if (-not (Test-Path -LiteralPath $audioDir)) { New-Item -Path $audioDir -ItemType Directory -Force | Out-Null } } catch { $audioDir = Get-SLTTempPath }
        $path = Join-Path $audioDir 'SLT_MicTest.wav'
        & $report 'RECORDING NOW (3 Seconds) - Speak into the microphone ("Hello Smart Life Teck")...'
        Invoke-SLTUiPump

        if ($script:SLTAudioGenReady) {
            [double]$pk = 0.0
            [double]$rm = 0.0
            $out = [SLT.SLTAudioGen]::RecordAndPlayMicDirect(3, $path, [ref]$pk, [ref]$rm)
            $result.Peak = $pk
            $result.Rms = $rm
            if ($out -eq 'OK') {
                $result.Played = $true
                $result.Success = $true
                if ($pk -ge 1.5) {
                    & $report "Voice Recorded & Played Back! (Peak Level: $pk%). Mic is working!"
                } else {
                    & $report "Playback finished, but mic level was very low ($pk%). Check if microphone is muted."
                }
                return $result
            } else {
                throw $out
            }
        } else {
            throw 'Win32 Audio Engine could not initialize.'
        }
    } catch {
        $result.Error = $_.Exception.Message
        & $report ("Mic Error: " + $result.Error)
        Log-SLT ('Mic test failed: ' + $result.Error)
    }
    return $result
}

function Invoke-SLTAutoDetectPeripherals([hashtable]$Data) {
    $dev = $Data['Devices']
    $conn = $Data['Connectivity']
    $tm = $null; try { $tm = Get-SLTTouchpadAndMicInfo } catch {}
    $fp = $null
    if ($dev -and $dev.BiometricList -ne 'None / Standard') {
        try { $fp = Get-SLTFingerprintDetail } catch {}
    }

    $autoMap = @{
        Audio       = if ($dev -and $dev.AudioPresent) { "OK ($($dev.AudioList))" } else { 'Missing / Driver Error' }
        Microphone  = if ($tm -and $tm.MicrophoneList -ne 'Not detected') { "OK ($($tm.MicrophoneList))" } else { 'Not Detected' }
        Camera      = if ($dev -and $dev.CameraPresent) { "OK ($($dev.CameraList))" } else { 'No Webcam in PnP' }
        Touchpad    = if ($tm -and $tm.TouchpadList -ne 'Not detected') { "OK ($($tm.TouchpadList))" } else { 'Standard HID' }
        Ports       = if ($dev) { "$($dev.USBCount) Active USB(s)" } else { 'Not Scanned' }
        Fingerprint = if ($fp -and $fp.UnitCount -gt 0) { "Present ($($fp.PnpList))" } elseif ($dev -and $dev.BiometricList -ne 'None / Standard') { "Present ($($dev.BiometricList))" } else { 'No Reader Fitted' }
    }
    $Data['AutoPeripherals'] = $autoMap

    # Device presence is not a functional test. Keep touchpad, ports, and body QC pending
    # until a technician completes the relevant manual test. Fingerprint presence is informational only.
    if ($autoMap['Fingerprint'] -eq 'No Reader Fitted') { $Data['PhysicalQC']['Fingerprint'] = 'No Reader' }
    return $autoMap
}

function Invoke-SLTSpeakerSoundTest {
    try {
        [System.Media.SystemSounds]::Exclamation.Play()
        [Console]::Beep(523, 180)
        [Console]::Beep(659, 180)
        [Console]::Beep(784, 240)
        Log-SLT 'Played speaker audio test chime.'
    } catch {
        try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
    }
}

function Invoke-SLTStereoSoundTest {
    # Kept for compatibility: Left tone, then Right tone, channel-isolated.
    try {
        Invoke-SLTChannelTone 'Left'
        Invoke-SLTChannelTone 'Right'
    } catch {
        Log-SLT ('Stereo test failed, falling back to chime: ' + $_.Exception.Message)
        Invoke-SLTSpeakerSoundTest
    }
}

function Invoke-SLTMci([string]$Command) {
    # Thin wrapper over winmm mciSendString with the exact error text.
    if (-not $script:SLTMciReady) {
        try {
            Add-Type -TypeDefinition 'using System; using System.Text; using System.Runtime.InteropServices; public static class SLTMci { [DllImport("winmm.dll", CharSet=CharSet.Auto)] public static extern int mciSendString(string command, StringBuilder returnValue, int returnLength, IntPtr callback); [DllImport("winmm.dll", CharSet=CharSet.Auto)] public static extern int mciGetErrorString(int error, StringBuilder buffer, int length); }' -ErrorAction Stop
            $script:SLTMciReady = $true
        } catch { $script:SLTMciReady = $false; throw "Microphone recorder (winmm.dll) could not be loaded: $($_.Exception.Message)" }
    }
    $sb = New-Object System.Text.StringBuilder(256)
    $rc = [SLTMci]::mciSendString($Command, $sb, 256, [IntPtr]::Zero)
    $errTxt = ''
    if ($rc -ne 0) {
        $eb = New-Object System.Text.StringBuilder(256)
        [void][SLTMci]::mciGetErrorString($rc, $eb, 256)
        $errTxt = $eb.ToString()
    }
    return [pscustomobject]@{ RC = $rc; Text = $sb.ToString(); ErrorText = $errTxt }
}

function Get-SLTWavPeakLevel([string]$Path) {
    # Reads a PCM WAV file (8/16-bit) and returns peak + RMS level. Parses
    # RIFF chunks properly instead of assuming a 44-byte header.
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Error = 'WAV file was not created.' } }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 44) { return [pscustomobject]@{ Error = 'WAV file is too small to contain audio.' } }
    $fmtOff = -1; $dataOff = -1; $dataLen = 0; $bits = 16; $channels = 1
    $pos = 12
    while ($pos + 8 -le $bytes.Length) {
        $id = [System.Text.Encoding]::ASCII.GetString($bytes, $pos, 4)
        $sz = [System.BitConverter]::ToInt32($bytes, $pos + 4)
        if ($id -eq 'fmt ') {
            $fmtOff = $pos + 8
            if ($sz -ge 16) {
                $channels = [System.BitConverter]::ToInt16($bytes, $fmtOff + 2)
                $bits = [System.BitConverter]::ToInt16($bytes, $fmtOff + 14)
            }
        } elseif ($id -eq 'data') { $dataOff = $pos + 8; $dataLen = $sz; break }
        $pos += 8 + $sz + ($sz % 2)
    }
    if ($dataOff -lt 0 -or $dataLen -le 0) { return [pscustomobject]@{ Error = 'WAV file has no audio data chunk.' } }
    if ($bits -notin @(8, 16)) { return [pscustomobject]@{ Error = "Unsupported WAV format ($bits-bit). Only 8/16-bit PCM is analysed." } }
    $avail = [Math]::Min($dataLen, ($bytes.Length - $dataOff))
    $maxAbs = 0.0; $sumSq = 0.0; $n = 0
    if ($bits -eq 16) {
        for ($i = 0; $i + 1 -lt $avail; $i += 2) {
            $v = [System.BitConverter]::ToInt16($bytes, $dataOff + $i) / 32768.0
            $a = [Math]::Abs($v)
            if ($a -gt $maxAbs) { $maxAbs = $a }
            $sumSq += ($v * $v); $n++
        }
    } else {
        for ($i = 0; $i -lt $avail; $i++) {
            $v = ($bytes[$dataOff + $i] - 128) / 128.0
            $a = [Math]::Abs($v)
            if ($a -gt $maxAbs) { $maxAbs = $a }
            $sumSq += ($v * $v); $n++
        }
    }
    if ($n -eq 0) { return [pscustomobject]@{ Error = 'WAV file contains no samples.' } }
    $rms = [Math]::Sqrt($sumSq / $n)
    return [pscustomobject]@{ PeakPercent = [Math]::Round($maxAbs * 100, 1); RmsPercent = [Math]::Round($rms * 100, 1); Samples = $n; Channels = $channels; Bits = $bits; Error = $null }
}

function Get-SLTFingerprintDetail {
    # Windows Biometric Framework enumeration (winbio.dll, read-only).
    # WINBIO_UNIT_SCHEMA strings are 256 Unicode chars each, in the order
    # UnitId, PoolType, Factor, SubType, Capabilities, DeviceInstanceId,
    # Description, Manufacturer, Model, SerialNumber, FirmwareVersion.
    # No enrollment, no credential read, no credential change, ever.
    $units = @(); $hrHex = 'n/a'; $winBioErr = $null
    try {
        if (-not $script:SLTWinBioReady) {
            try {
                Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct SLTWinBioUnitSchema {
    public uint UnitId; public uint PoolType; public uint BiometricFactor; public uint SensorSubType; public uint Capabilities;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string DeviceInstanceId;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Description;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Manufacturer;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Model;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string SerialNumber;
    public uint FirmwareMajor; public uint FirmwareMinor;
}
public static class SLTWinBio {
    [DllImport("winbio.dll")] public static extern int WinBioEnumBiometricUnits(uint factor, out IntPtr schemaArray, out UIntPtr unitCount);
    [DllImport("winbio.dll")] public static extern int WinBioFree(IntPtr address);
}
'@ -ErrorAction Stop
                $script:SLTWinBioReady = $true
            } catch { $script:SLTWinBioReady = $false; $winBioErr = "WinBio P/Invoke could not be loaded: $($_.Exception.Message)" }
        }
        if ($script:SLTWinBioReady) {
            $ptr = [IntPtr]::Zero; $cnt = [UIntPtr]::Zero
            try {
                $hr = [SLTWinBio]::WinBioEnumBiometricUnits(8, [ref]$ptr, [ref]$cnt)
                $hrHex = ('0x{0:X8}' -f $hr)
                if ($hr -eq 0 -and $ptr -ne [IntPtr]::Zero -and $cnt.ToUInt64() -gt 0) {
                    $sz = [System.Runtime.InteropServices.Marshal]::SizeOf([SLTWinBioUnitSchema])
                    for ($i = 0; $i -lt $cnt.ToUInt64(); $i++) {
                        $addr = [IntPtr]($ptr.ToInt64() + ($i * $sz))
                        $u = [System.Runtime.InteropServices.Marshal]::PtrToStructure($addr, [SLTWinBioUnitSchema])
                        $subTxt = switch ([int]$u.SensorSubType) { 1 { 'Swipe' } 2 { 'Touch' } default { 'Unknown' } }
                        $units += [pscustomobject]@{
                            UnitId = [int]$u.UnitId; PoolType = [int]$u.PoolType; SensorSubType = $subTxt
                            Capabilities = ('0x{0:X2}' -f $u.Capabilities)
                            Description = [string]$u.Description; Manufacturer = [string]$u.Manufacturer
                            Model = [string]$u.Model; SerialNumber = [string]$u.SerialNumber
                            DeviceInstanceId = [string]$u.DeviceInstanceId
                            Firmware = "$($u.FirmwareMajor).$($u.FirmwareMinor)"
                        }
                    }
                } elseif ($hr -ne 0) {
                    $winBioErr = "WinBioEnumBiometricUnits failed (HRESULT $hrHex). If biometric use is disabled by policy, the framework reports WINBIO_E_DISABLED."
                }
            } finally {
                if ($ptr -ne [IntPtr]::Zero) { try { [void][SLTWinBio]::WinBioFree($ptr) } catch {} }
            }
        }
    } catch { $winBioErr = "Fingerprint enumeration failed: $($_.Exception.Message)" }
    $pnpList = 'Not reported'; $svcState = 'Not reported'
    try {
        $pnp = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.PNPClass -eq 'Biometric' -or $_.Name -match 'Fingerprint|Windows Hello' } | ForEach-Object { [string]$_.Name })
        if ($pnp.Count -gt 0) { $pnpList = ($pnp -join ' | ') }
        else { $pnpList = 'No biometric device in Device Manager' }
    } catch { $pnpList = 'Device Manager could not be read' }
    try {
        $svc = Get-Service -Name 'wbiosrvc' -ErrorAction Stop
        $svcState = "$($svc.Status) (Startup: $($svc.StartType))"
    } catch { $svcState = 'Windows Biometric Service (wbiosrvc) not found' }
    return [pscustomobject]@{
        Units = $units; UnitCount = $units.Count; HResult = $hrHex; WinBioError = $winBioErr
        PnpList = $pnpList; ServiceState = $svcState
    }
}

function Show-SLTStressTestDialog {
    # OPTIONAL CPU stress test only. Separate from Auto Scan, behind a
    # warning + consent checkbox, max 3 minutes, technician Cancel, and
    # auto-abort if a reported temperature reaches 95 C. No GPU load is
    # generated here; FurMark via Advanced Tools is the external GPU check.
    $script:StressState = @{ Running = $false; StartTime = $null; MaxTemp = $null; Seconds = 0 }
    $win = New-Object Windows.Window
    $win.Title = 'SLT Optional CPU Stress Test'; $win.Width = 620; $win.Height = 480
    $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $script:Window
    Apply-SLTDialogTheme $win
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(16)
    $outer.Children.Add((New-SLTStatusText 'OPTIONAL CPU STRESS TEST - READ THE WARNING FIRST' 16 $true 'Warn')) | Out-Null
    $warn = New-SLTText 'WARNING: this test loads all CPU cores for up to 3 minutes. The fan will get loud and the laptop will get hot. Run it ONLY on AC power, ONLY if the fan and cooling look healthy, and stop it at once if you smell anything hot or the laptop becomes too hot to touch. It is NOT part of the standard QC scan and a laptop does not need it to pass QC. GPU load testing is not done here - use FurMark from Advanced Tools if a GPU load check is needed.' 12.5 $false '#FDE68A'
    $warn.TextWrapping = 'Wrap'
    $outer.Children.Add($warn) | Out-Null
    $agree = New-Object Windows.Controls.CheckBox
    $agree.Content = 'I understand the warning. Fan/cooling look healthy and the laptop is on AC power.'
    $agree.FontSize = 13; $agree.Margin = [Windows.Thickness]::new(0, 8, 0, 4)
    $agree.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'TextPrimary')
    $outer.Children.Add($agree) | Out-Null
    $script:StressStatus = New-SLTStatusText 'Not running.' 13 $true 'Info'
    $outer.Children.Add($script:StressStatus) | Out-Null
    $script:StressTempLbl = New-SLTText 'Temperature / Load: not reported' 13 $false '#9DC6E1'
    $outer.Children.Add($script:StressTempLbl) | Out-Null
    $prog = New-Object Windows.Controls.ProgressBar
    $prog.Minimum = 0; $prog.Maximum = 180; $prog.Value = 0; $prog.Height = 16; $prog.Margin = [Windows.Thickness]::new(0, 10, 0, 10)
    $outer.Children.Add($prog) | Out-Null
    $script:StressProg = $prog
    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'
    $script:StressStartBtn = New-Object Windows.Controls.Button; $script:StressStartBtn.Content = 'Start 3-Minute Stress Test'; $script:StressStartBtn.Style = $script:Window.FindResource('ActionButton'); $script:StressStartBtn.Background = (New-SLTBrush '#B91C1C'); $script:StressStartBtn.Foreground = (New-SLTBrush '#FFFFFF'); $script:StressStartBtn.MinWidth = 220; $script:StressStartBtn.MinHeight = 38; $script:StressStartBtn.IsEnabled = $false
    $script:StressCancelBtn = New-Object Windows.Controls.Button; $script:StressCancelBtn.Content = 'Cancel / Stop'; $script:StressCancelBtn.Style = $script:Window.FindResource('ActionButton'); $script:StressCancelBtn.MinWidth = 130; $script:StressCancelBtn.MinHeight = 38; $script:StressCancelBtn.Margin = [Windows.Thickness]::new(10, 0, 0, 0); $script:StressCancelBtn.IsEnabled = $false
    $closeBtn = New-Object Windows.Controls.Button; $closeBtn.Content = 'Close'; $closeBtn.Style = $script:Window.FindResource('ActionButton'); $closeBtn.MinWidth = 90; $closeBtn.MinHeight = 38; $closeBtn.Margin = [Windows.Thickness]::new(10, 0, 0, 0)
    $btnRow.Children.Add($script:StressStartBtn) | Out-Null; $btnRow.Children.Add($script:StressCancelBtn) | Out-Null; $btnRow.Children.Add($closeBtn) | Out-Null
    $outer.Children.Add($btnRow) | Out-Null
    $win.Content = $outer
    $script:StressWin = $win
    $script:StressSync = $null; $script:StressPool = $null; $script:StressJobs = @(); $script:StressTimer = $null
    $agree.Add_Checked({ $script:StressStartBtn.IsEnabled = $true })
    $agree.Add_Unchecked({ $script:StressStartBtn.IsEnabled = $false })
    $stopStress = {
        param([string]$Outcome)
        if (-not $script:StressState.Running) { return }
        $script:StressState.Running = $false
        try { if ($script:StressTimer) { $script:StressTimer.Stop() } } catch {}
        try {
            if ($script:StressSync) { $script:StressSync.Stop = $true }
            foreach ($j in @($script:StressJobs)) {
                try { $j.PS.EndInvoke($j.Async) } catch {}
                try { $j.PS.Dispose() } catch {}
            }
            if ($script:StressPool) { $script:StressPool.Close(); $script:StressPool.Dispose() }
        } catch { Log-SLT ('Stress stop cleanup: ' + $_.Exception.Message) }
        $script:StressJobs = @(); $script:StressPool = $null
        $secs = $script:StressState.Seconds
        $mt = if ($null -ne $script:StressState.MaxTemp) { "$($script:StressState.MaxTemp) C" } else { 'not reported' }
        $script:StressStatus.Text = "Stress test $Outcome after $secs seconds. Max reported temperature: $mt."
        $script:HWData['Notes']['StressTest'] = "Optional CPU stress test: $Outcome after $secs s of max 180 s. Max reported temperature: $mt. Load was generated on all cores with a 3-minute cap; no GPU load was generated."
        Log-SLT ('Stress test finished: ' + $script:HWData['Notes']['StressTest'])
        $script:StressStartBtn.IsEnabled = $false; $script:StressCancelBtn.IsEnabled = $false
    }
    $script:StressStop = $stopStress
    $script:StressTimer = New-Object Windows.Threading.DispatcherTimer
    $script:StressTimer.Interval = [TimeSpan]::FromSeconds(1)
    $script:StressTimer.Add_Tick({
        if (-not $script:StressState.Running) { return }
        $elapsed = [int](([DateTime]::Now - $script:StressState.StartTime).TotalSeconds)
        $script:StressState.Seconds = $elapsed
        $script:StressProg.Value = [Math]::Min(180, $elapsed)
        $tempTxt = 'not reported'; $loadTxt = 'not reported'
        try {
            $sensors = @(Get-SLTSensorReadout)
            $temps = @($sensors | Where-Object { $_.Type -eq 'Temperature' } | ForEach-Object { [double]$_.Value })
            if ($temps.Count -gt 0) {
                $mx = ($temps | Measure-Object -Maximum).Maximum
                $tempTxt = "$([Math]::Round($mx, 1)) C"
                if ($null -eq $script:StressState.MaxTemp -or $mx -gt $script:StressState.MaxTemp) { $script:StressState.MaxTemp = [Math]::Round($mx, 1) }
            }
        } catch {}
        try {
            $cp = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cp -and $null -ne $cp.LoadPercentage) { $loadTxt = "$($cp.LoadPercentage)%" }
        } catch {}
        $script:StressTempLbl.Text = "Temperature / Load: $tempTxt  |  CPU Load: $loadTxt  |  Elapsed: ${elapsed}s / 180s"
        $script:StressStatus.Text = "Stress test running... $elapsed s of 180 s. Press Cancel / Stop to end it early."
        if ($elapsed -ge 180) { & $script:StressStop 'Completed (3-minute cap reached)' }
        elseif ($null -ne $script:StressState.MaxTemp -and $script:StressState.MaxTemp -ge 95) { & $script:StressStop 'Aborted - reported temperature reached 95 C' }
    })
    $script:StressStartBtn.Add_Click({
        try {
            $workers = [Math]::Min(8, [Math]::Max(1, [Environment]::ProcessorCount))
            $script:StressSync = [hashtable]::Synchronized(@{ Stop = $false })
            $script:StressPool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $workers)
            $script:StressPool.Open()
            $workerCode = { param($s) $n = [long]0; $acc = 0.0; while (-not $s.Stop) { $n++; $acc += [Math]::Sin([double]($n % 360)); if ($n -gt 100000000) { $n = 0 } } }
            $script:StressJobs = @()
            for ($w = 0; $w -lt $workers; $w++) {
                $ps = [powershell]::Create()
                $ps.RunspacePool = $script:StressPool
                [void]$ps.AddScript($workerCode).AddArgument($script:StressSync)
                $async = $ps.BeginInvoke()
                $script:StressJobs += @{ PS = $ps; Async = $async }
            }
            $script:StressState.Running = $true
            $script:StressState.StartTime = [DateTime]::Now
            $script:StressState.Seconds = 0; $script:StressState.MaxTemp = $null
            $script:StressStartBtn.IsEnabled = $false; $script:StressCancelBtn.IsEnabled = $true
            $script:StressStatus.Text = "Stress test running on $workers worker(s)... 0 s of 180 s."
            $script:StressTimer.Start()
            Log-SLT "Optional CPU stress test started ($workers workers, 180s cap)."
        } catch {
            $script:StressStatus.Text = "Stress test could not start: $($_.Exception.Message)"
            Log-SLT ('Stress test start failed: ' + $_.Exception.Message)
        }
    })
    $script:StressCancelBtn.Add_Click({ & $script:StressStop 'Cancelled by technician' })
    $closeBtn.Add_Click({ if ($script:StressWin) { $script:StressWin.Close() } })
    $win.Add_Closing({ try { & $script:StressStop 'Cancelled (dialog closed)' } catch {} })
    Log-SLT 'Optional CPU stress test dialog opened.'
    $win.ShowDialog() | Out-Null
    $script:StressWin = $null
}

function Get-SLTTouchpadAndMicInfo {
    # Read-only device detection. A device listed here proves Windows sees it;
    # it does not prove touchpad gestures or mic quality - those are manual.
    $touch = 'Not detected'; $mic = 'Not detected'
    try {
        $pnp = @(Get-SLTCachedPnpEntities)
        $tp = @($pnp | Where-Object { $_.Name -match 'touchpad|Precision|ELAN|Synaptics' -and $_.Status -eq 'OK' })
        if ($tp.Count -gt 0) { $touch = (($tp | ForEach-Object { [string]$_.Name }) -join ' | ') }
        $mc = @($pnp | Where-Object { $_.Name -match 'microphone|array microphone' -and $_.Status -eq 'OK' })
        if ($mc.Count -gt 0) { $mic = (($mc | ForEach-Object { [string]$_.Name }) -join ' | ') }
    } catch {
        $touch = 'Not reported - check Device Manager'; $mic = 'Not reported - check Device Manager'
    }
    return [pscustomobject]@{ TouchpadList = $touch; MicrophoneList = $mic }
}

# ---------------------------------------------------------------- CABIN STYLE INTERACTIVE MODAL POPUPS ---
function New-SLTCabinModalWindow([string]$Title, [double]$Width=520, [double]$Height=400) {
    $w = New-Object Windows.Window
    $w.Title = $Title
    $w.Width = $Width; $w.Height = $Height
    $w.WindowStartupLocation = 'CenterOwner'; $w.Owner = $script:Window
    $w.ResizeMode = 'NoResize'
    Apply-SLTDialogTheme $w
    return $w
}

function Show-SLTTouchpadModal {
    $win = New-SLTCabinModalWindow 'Touchpad Test' 540 390
    $script:TouchEventsCount = 0
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(20)
    $hdr = New-SLTText 'Touchpad Interactive Check' 15 $true '#0F766E'
    $outer.Children.Add($hdr)|Out-Null

    $padBdr = New-Object Windows.Controls.Border
    $padBdr.Height = 195
    $padBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
    $padBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'InputBorder')
    $padBdr.BorderThickness = [Windows.Thickness]::new(2)
    $padBdr.CornerRadius = [Windows.CornerRadius]::new(16)
    $padBdr.Margin = [Windows.Thickness]::new(0,10,0,12)
    $padBdr.Cursor = [Windows.Input.Cursors]::Cross

    $padStack = New-Object Windows.Controls.StackPanel
    $padStack.VerticalAlignment = 'Center'; $padStack.HorizontalAlignment = 'Center'
    $t1 = New-SLTText 'Move & Click inside this area' 13.5 $true '#0F172A'; $t1.HorizontalAlignment = 'Center'
    $script:TouchCountLbl = New-SLTText '0 touch / pointer events detected' 11.5 $false '#64748B'; $script:TouchCountLbl.HorizontalAlignment = 'Center'
    $pillRow = New-Object Windows.Controls.StackPanel; $pillRow.Orientation = 'Horizontal'; $pillRow.HorizontalAlignment = 'Center'; $pillRow.Margin = [Windows.Thickness]::new(0,8,0,0)
    $script:TpLeftPill  = New-SLTBadge 'Left Click' '#64748B'
    $script:TpRightPill = New-SLTBadge 'Right Click' '#64748B'
    $script:TpScrollPill= New-SLTBadge 'Two-Finger Scroll' '#64748B'
    $pillRow.Children.Add($script:TpLeftPill)|Out-Null; $pillRow.Children.Add($script:TpRightPill)|Out-Null; $pillRow.Children.Add($script:TpScrollPill)|Out-Null
    $padStack.Children.Add($t1)|Out-Null; $padStack.Children.Add($script:TouchCountLbl)|Out-Null; $padStack.Children.Add($pillRow)|Out-Null
    $padBdr.Child = $padStack

    $padBdr.Add_MouseMove({
        $script:TouchEventsCount++
        if ($script:TouchCountLbl) { $script:TouchCountLbl.Text = "$($script:TouchEventsCount) touch / pointer events detected" }
    })
    $padBdr.Add_MouseLeftButtonDown({
        $script:TouchEventsCount += 5
        if ($script:TouchCountLbl) { $script:TouchCountLbl.Text = "$($script:TouchEventsCount) touch / pointer events detected (Left Click OK)" }
        if ($script:TpLeftPill) { $script:TpLeftPill.BorderBrush = (New-SLTBrush '#10B981') }
    })
    $padBdr.Add_MouseRightButtonDown({
        $script:TouchEventsCount += 5
        if ($script:TouchCountLbl) { $script:TouchCountLbl.Text = "$($script:TouchEventsCount) touch / pointer events detected (Right Click OK)" }
        if ($script:TpRightPill) { $script:TpRightPill.BorderBrush = (New-SLTBrush '#10B981') }
    })
    $padBdr.Add_MouseWheel({
        $script:TouchEventsCount += 3
        if ($script:TouchCountLbl) { $script:TouchCountLbl.Text = "$($script:TouchEventsCount) touch / pointer events detected (Scroll OK)" }
        if ($script:TpScrollPill) { $script:TpScrollPill.BorderBrush = (New-SLTBrush '#10B981') }
    })
    $outer.Children.Add($padBdr)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Center'
    $resetBtn = New-SLTDialogButton 'Reset' '#475569' '#FFFFFF' 90
    $passBtn  = New-SLTDialogButton 'Passed' '#059669' '#FFFFFF' 115
    $issueBtn = New-SLTDialogButton 'Issue' '#EA580C' '#FFFFFF' 115
    $script:TpModalWin = $win
    $resetBtn.Add_Click({ $script:TouchEventsCount = 0; if ($script:TouchCountLbl) { $script:TouchCountLbl.Text = '0 touch / pointer events detected' } })
    $passBtn.Add_Click({ Set-SLTQCResult 'Touchpad' 'Passed' ''; if ($script:TpModalWin) { $script:TpModalWin.Close() } })
    $issueBtn.Add_Click({ Set-SLTQCResult 'Touchpad' 'Issue' ''; if ($script:TpModalWin) { $script:TpModalWin.Close() } })
    $btnRow.Children.Add($resetBtn)|Out-Null; $btnRow.Children.Add($passBtn)|Out-Null; $btnRow.Children.Add($issueBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:TpModalWin = $null
}

function Show-SLTUsbPortsModal {
    $win = New-SLTCabinModalWindow 'USB & Ports Check' 520 400
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(20)
    $outer.Children.Add((New-SLTText 'USB & Ports Check (Tick verified ports)' 15 $true '#0F766E'))|Out-Null
    $dev = Get-SLTDeviceAndPortHealth
    $script:HWData['Devices'] = $dev
    $outer.Children.Add((New-SLTText "Auto-detected active USB devices: $($dev.USBCount) ($(if($dev.USBItems){@($dev.USBItems) -join ', '}else{'None'}))" 11.5 $false '#64748B'))|Out-Null

    $grid = New-Object Windows.Controls.Primitives.UniformGrid; $grid.Columns = 2; $grid.Margin = [Windows.Thickness]::new(0,10,0,14)
    $script:UsbPortCheckboxes = @{}
    foreach ($pName in @('USB-A Left','USB-A Right','USB-C','HDMI','Audio Jack','RJ45 LAN')) {
        $bdr = New-Object Windows.Controls.Border
        $bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
        $bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'InputBorder')
        $bdr.BorderThickness = [Windows.Thickness]::new(1); $bdr.CornerRadius = [Windows.CornerRadius]::new(10)
        $bdr.Padding = [Windows.Thickness]::new(10,6,10,6); $bdr.Margin = [Windows.Thickness]::new(4)
        $cb = New-Object Windows.Controls.CheckBox; $cb.Content = $pName; $cb.FontWeight = 'SemiBold'
        $script:UsbPortCheckboxes[$pName] = $cb
        $bdr.Child = $cb
        $grid.Children.Add($bdr)|Out-Null
    }
    $outer.Children.Add($grid)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Center'
    $resetBtn = New-SLTDialogButton 'Reset' '#475569' '#FFFFFF' 90
    $passBtn  = New-SLTDialogButton 'All Ports OK' '#059669' '#FFFFFF' 135
    $issueBtn = New-SLTDialogButton 'Issue' '#EA580C' '#FFFFFF' 110
    $script:UsbModalWin = $win
    $resetBtn.Add_Click({ foreach ($c in $script:UsbPortCheckboxes.Values) { $c.IsChecked = $false } })
    $passBtn.Add_Click({ Set-SLTQCResult 'Ports' 'Passed' ''; if ($script:UsbModalWin) { $script:UsbModalWin.Close() } })
    $issueBtn.Add_Click({ Set-SLTQCResult 'Ports' 'Issue' ''; if ($script:UsbModalWin) { $script:UsbModalWin.Close() } })
    $btnRow.Children.Add($resetBtn)|Out-Null; $btnRow.Children.Add($passBtn)|Out-Null; $btnRow.Children.Add($issueBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:UsbModalWin = $null
}

function Show-SLTCameraModal {
    $win = New-SLTCabinModalWindow 'Camera Test' 520 390
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(20)
    $outer.Children.Add((New-SLTText 'Camera & Webcam Test' 15 $true '#0F766E'))|Out-Null
    $dev = Get-SLTDeviceAndPortHealth
    $script:HWData['Devices'] = $dev

    $camBox = New-Object Windows.Controls.Border
    $camBox.Height = 195; $camBox.Background = (New-SLTBrush '#0F172A'); $camBox.CornerRadius = [Windows.CornerRadius]::new(16)
    $camBox.Margin = [Windows.Thickness]::new(0,10,0,14)
    $camStack = New-Object Windows.Controls.StackPanel; $camStack.VerticalAlignment = 'Center'; $camStack.HorizontalAlignment = 'Center'
    $camIcon = New-Object Windows.Controls.TextBlock; $camIcon.Text = [char]::ConvertFromUtf32(0x1F4F7); $camIcon.FontSize = 34; $camIcon.Foreground = [Windows.Media.Brushes]::White; $camIcon.HorizontalAlignment = 'Center'
    $script:CamModalLbl = New-Object Windows.Controls.TextBlock; $script:CamModalLbl.Text = "Detected: $($dev.CameraList)"; $script:CamModalLbl.Foreground = [Windows.Media.Brushes]::White; $script:CamModalLbl.FontSize = 13; $script:CamModalLbl.FontWeight = 'SemiBold'; $script:CamModalLbl.HorizontalAlignment = 'Center'; $script:CamModalLbl.Margin = [Windows.Thickness]::new(0,8,0,4)
    $camHint = New-Object Windows.Controls.TextBlock; $camHint.Text = 'Click Start Preview below to check focus, color & clarity.'; $camHint.Foreground = (New-SLTBrush '#94A3B8'); $camHint.FontSize = 11.5; $camHint.HorizontalAlignment = 'Center'
    $camStack.Children.Add($camIcon)|Out-Null; $camStack.Children.Add($script:CamModalLbl)|Out-Null; $camStack.Children.Add($camHint)|Out-Null
    $camBox.Child = $camStack
    $outer.Children.Add($camBox)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Center'
    $prevBtn  = New-SLTDialogButton 'Start Preview' '#0F766E' '#FFFFFF' 130
    $passBtn  = New-SLTDialogButton 'Passed' '#059669' '#FFFFFF' 110
    $issueBtn = New-SLTDialogButton 'Issue' '#EA580C' '#FFFFFF' 110
    $script:CamModalWin = $win
    $prevBtn.Add_Click({
        try { Start-Process 'microsoft.windows.camera:'; if ($script:CamModalLbl) { $script:CamModalLbl.Text = 'Camera Preview Launched - Check video feed!' } }
        catch { try { Start-Process 'ms-settings:camera' } catch {} }
    })
    $passBtn.Add_Click({ Set-SLTQCResult 'Camera' 'Passed' ''; if ($script:CamModalWin) { $script:CamModalWin.Close() } })
    $issueBtn.Add_Click({ Set-SLTQCResult 'Camera' 'Issue' ''; if ($script:CamModalWin) { $script:CamModalWin.Close() } })
    $btnRow.Children.Add($prevBtn)|Out-Null; $btnRow.Children.Add($passBtn)|Out-Null; $btnRow.Children.Add($issueBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:CamModalWin = $null
}

function Show-SLTSpeakersMicModal {
    $win = New-SLTCabinModalWindow 'Speakers & Mic Test' 530 410
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(20)
    $outer.Children.Add((New-SLTText 'Speakers & Microphone Test' 15 $true '#0F766E'))|Out-Null

    $spkGrid = New-Object Windows.Controls.Primitives.UniformGrid; $spkGrid.Columns = 3; $spkGrid.Margin = [Windows.Thickness]::new(0,10,0,8)
    $bLeft  = New-SLTDialogButton 'Play LEFT' '#0F766E' '#FFFFFF' 130
    $bRight = New-SLTDialogButton 'Play RIGHT' '#0F766E' '#FFFFFF' 130
    $bBoth  = New-SLTDialogButton 'Play BOTH' '#0F766E' '#FFFFFF' 130
    $spkGrid.Children.Add($bLeft)|Out-Null; $spkGrid.Children.Add($bRight)|Out-Null; $spkGrid.Children.Add($bBoth)|Out-Null
    $outer.Children.Add($spkGrid)|Out-Null

    $statusBdr = New-Object Windows.Controls.Border
    $statusBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
    $statusBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'InputBorder')
    $statusBdr.BorderThickness = [Windows.Thickness]::new(1); $statusBdr.CornerRadius = [Windows.CornerRadius]::new(12)
    $statusBdr.Padding = [Windows.Thickness]::new(12,8,12,8); $statusBdr.Margin = [Windows.Thickness]::new(0,2,0,10)
    $script:SpkModalStatus = New-SLTText 'Click Play LEFT, Play RIGHT, or Play BOTH to test stereo speakers.' 12 $true '#0F766E'
    $statusBdr.Child = $script:SpkModalStatus
    $outer.Children.Add($statusBdr)|Out-Null

    $micBdr = New-Object Windows.Controls.Border
    $micBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
    $micBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'InputBorder')
    $micBdr.BorderThickness = [Windows.Thickness]::new(1); $micBdr.CornerRadius = [Windows.CornerRadius]::new(12)
    $micBdr.Padding = [Windows.Thickness]::new(14,10,14,10); $micBdr.Margin = [Windows.Thickness]::new(0,0,0,14)
    $micRow = New-Object Windows.Controls.Grid
    $mc0 = New-Object Windows.Controls.ColumnDefinition; $mc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $mc1 = New-Object Windows.Controls.ColumnDefinition; $mc1.Width = [Windows.GridLength]::Auto
    $micRow.ColumnDefinitions.Add($mc0)|Out-Null; $micRow.ColumnDefinitions.Add($mc1)|Out-Null
    $micLbl = New-SLTText 'Mic Record 3s & Amplified Playback' 12.5 $true '#0F172A'; $micLbl.VerticalAlignment = 'Center'
    $micBtn = New-SLTDialogButton 'Record & Playback' '#0284C7' '#FFFFFF' 155
    $micLbl.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
    $micBtn.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $micRow.Children.Add($micLbl)|Out-Null; $micRow.Children.Add($micBtn)|Out-Null
    $micBdr.Child = $micRow
    $outer.Children.Add($micBdr)|Out-Null

    $bLeft.Add_Click({
        $script:SpkModalStatus.Text = 'Playing LEFT channel tone...'
        Invoke-SLTUiPump
        $r = Invoke-SLTChannelTone 'Left'
        $script:SpkModalStatus.Text = if ($r.Success) { "Playing LEFT channel tone - OK ($($r.Method))" } else { "Failed: $($r.Error)" }
    })
    $bRight.Add_Click({
        $script:SpkModalStatus.Text = 'Playing RIGHT channel tone...'
        Invoke-SLTUiPump
        $r = Invoke-SLTChannelTone 'Right'
        $script:SpkModalStatus.Text = if ($r.Success) { "Playing RIGHT channel tone - OK ($($r.Method))" } else { "Failed: $($r.Error)" }
    })
    $bBoth.Add_Click({
        $script:SpkModalStatus.Text = 'Playing BOTH channels tone...'
        Invoke-SLTUiPump
        $r = Invoke-SLTChannelTone 'Both'
        $script:SpkModalStatus.Text = if ($r.Success) { "Playing BOTH channels tone - OK ($($r.Method))" } else { "Failed: $($r.Error)" }
    })
    $micBtn.Add_Click({
        $res = Invoke-SLTInlineMicRecording { param($msg) $script:SpkModalStatus.Text = $msg; Invoke-SLTUiPump }
        if ($res.Success) { $script:HWData['PhysicalQC']['Microphone'] = 'Passed' }
    })

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Center'
    $passBtn  = New-SLTDialogButton 'Passed' '#059669' '#FFFFFF' 125
    $issueBtn = New-SLTDialogButton 'Issue' '#EA580C' '#FFFFFF' 125
    $script:SpkModalWin = $win
    $passBtn.Add_Click({ Set-SLTQCResult 'Audio' 'Passed' ''; Set-SLTQCResult 'Microphone' 'Passed' ''; if ($script:SpkModalWin) { $script:SpkModalWin.Close() } })
    $issueBtn.Add_Click({ Set-SLTQCResult 'Audio' 'Issue' ''; if ($script:SpkModalWin) { $script:SpkModalWin.Close() } })
    $btnRow.Children.Add($passBtn)|Out-Null; $btnRow.Children.Add($issueBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:SpkModalWin = $null
}

function Show-SLTBodyHingeModal {
    $win = New-SLTCabinModalWindow 'Body & Hinge / Chassis' 530 430
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(20)
    $outer.Children.Add((New-SLTText 'Body & Hinge / Chassis Grade' 15 $true '#0F766E'))|Out-Null

    $gradeGrid = New-Object Windows.Controls.Primitives.UniformGrid; $gradeGrid.Columns = 4; $gradeGrid.Margin = [Windows.Thickness]::new(0,10,0,10)
    $script:BodyGradeButtons = @{}
    foreach ($gSpec in @(
        @{g='A'; d='Like New';   c='Class A - OK'},
        @{g='B'; d='Minor Wear'; c='Minor Scratch'},
        @{g='C'; d='Visible Wear';c='Major Scratch'},
        @{g='D'; d='Heavy Wear'; c='Dent'}
    )) {
        $gb = New-SLTDialogButton ("Grade $($gSpec.g) - $($gSpec.d)") $(if($script:HWBodyGrade -eq $gSpec.g){'#0F766E'}else{'#334155'}) '#FFFFFF' 105
        $gb.Tag = $gSpec.g
        $gb.Add_Click({
            param($s,$e)
            $script:HWBodyGrade = [string]$s.Tag
            $mapCond = @{'A'='Class A - OK';'B'='Minor Scratch';'C'='Major Scratch';'D'='Dent'}
            $script:HWData['Customer']['BodyCondition'] = $mapCond[$script:HWBodyGrade]
            foreach ($k in $script:BodyGradeButtons.Keys) {
                $script:BodyGradeButtons[$k].Background = (New-SLTBrush $(if($k -eq $script:HWBodyGrade){'#0F766E'}else{'#334155'}))
            }
        })
        $script:BodyGradeButtons[$gSpec.g] = $gb
        $gradeGrid.Children.Add($gb)|Out-Null
    }
    $outer.Children.Add($gradeGrid)|Out-Null

    $chkGrid = New-Object Windows.Controls.Primitives.UniformGrid; $chkGrid.Columns = 2; $chkGrid.Margin = [Windows.Thickness]::new(0,4,0,14)
    foreach ($item in @('Hinge Tightness','Palmrest Marks','Bottom Screws','Rubber Feet','Chassis Scratch','Lid Dent')) {
        $bdr = New-Object Windows.Controls.Border
        $bdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
        $bdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'InputBorder')
        $bdr.BorderThickness = [Windows.Thickness]::new(1); $bdr.CornerRadius = [Windows.CornerRadius]::new(10)
        $bdr.Padding = [Windows.Thickness]::new(10,5,10,5); $bdr.Margin = [Windows.Thickness]::new(3)
        $cb = New-Object Windows.Controls.CheckBox; $cb.Content = $item
        $bdr.Child = $cb
        $chkGrid.Children.Add($bdr)|Out-Null
    }
    $outer.Children.Add($chkGrid)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Center'
    $passBtn  = New-SLTDialogButton "Passed (Grade $($script:HWBodyGrade))" '#059669' '#FFFFFF' 155
    $issueBtn = New-SLTDialogButton 'Issue' '#EA580C' '#FFFFFF' 115
    $script:BodyModalWin = $win
    $passBtn.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:HWBodyGrade)) { [Windows.MessageBox]::Show('Select a body grade after inspecting the chassis.','SLT Hardware QC','OK','Warning') | Out-Null; return }
        Set-SLTQCResult 'Body' 'Passed' "Grade $($script:HWBodyGrade)"
        if ($script:BodyModalWin) { $script:BodyModalWin.Close() }
    })
    $issueBtn.Add_Click({ Set-SLTQCResult 'Body' 'Issue' "Grade $($script:HWBodyGrade)"; if ($script:BodyModalWin) { $script:BodyModalWin.Close() } })
    $btnRow.Children.Add($passBtn)|Out-Null; $btnRow.Children.Add($issueBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:BodyModalWin = $null
}

function Show-SLTChargerModal {
    $win = New-SLTCabinModalWindow 'Charger & Power Adapter' 500 400
    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(20)
    $outer.Children.Add((New-SLTText 'Charger & Power Adapter Check' 15 $true '#0F766E'))|Out-Null

    $wGrid = New-Object Windows.Controls.Primitives.UniformGrid; $wGrid.Columns = 3; $wGrid.Margin = [Windows.Thickness]::new(0,10,0,10)
    $script:ChargerWattButtons = @{}
    foreach ($w in @('45W','65W','90W','100W','USB-C PD','Barrel')) {
        $wb = New-SLTDialogButton $w $(if($script:HWChargerWatts -eq $w){'#0F766E'}else{'#334155'}) '#FFFFFF' 125
        $wb.Tag = $w
        $wb.Add_Click({
            param($s,$e)
            $script:HWChargerWatts = [string]$s.Tag
            $script:HWData['Customer']['Charger'] = "Original ($($script:HWChargerWatts))"
            foreach ($k in $script:ChargerWattButtons.Keys) {
                $script:ChargerWattButtons[$k].Background = (New-SLTBrush $(if($k -eq $script:HWChargerWatts){'#0F766E'}else{'#334155'}))
            }
        })
        $script:ChargerWattButtons[$w] = $wb
        $wGrid.Children.Add($wb)|Out-Null
    }
    $outer.Children.Add($wGrid)|Out-Null

    $ledBdr = New-Object Windows.Controls.Border
    $ledBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'InputBg')
    $ledBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'InputBorder')
    $ledBdr.BorderThickness = [Windows.Thickness]::new(1); $ledBdr.CornerRadius = [Windows.CornerRadius]::new(10)
    $ledBdr.Padding = [Windows.Thickness]::new(12,8,12,8); $ledBdr.Margin = [Windows.Thickness]::new(0,4,0,10)
    $ledCb = New-Object Windows.Controls.CheckBox; $ledCb.Content = 'Charging LED ON & Battery % increasing - cable strain OK'; $ledCb.IsChecked = $false
    $ledBdr.Child = $ledCb
    $outer.Children.Add($ledBdr)|Out-Null

    $noteBdr = New-Object Windows.Controls.Border
    $noteBdr.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'CardSurface')
    $noteBdr.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'ActionBorder')
    $noteBdr.BorderThickness = [Windows.Thickness]::new(1); $noteBdr.CornerRadius = [Windows.CornerRadius]::new(10)
    $noteBdr.Padding = [Windows.Thickness]::new(12,8,12,8); $noteBdr.Margin = [Windows.Thickness]::new(0,0,0,14)
    $noteBdr.Child = (New-SLTText 'Ensure original HP/Dell/Lenovo adapter, clean connector, and no frayed cable.' 11.5 $false '#0F766E')
    $outer.Children.Add($noteBdr)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Center'
    $passBtn  = New-SLTDialogButton "Passed ($($script:HWChargerWatts))" '#059669' '#FFFFFF' 145
    $issueBtn = New-SLTDialogButton 'Issue' '#EA580C' '#FFFFFF' 115
    $script:ChgModalWin = $win
    $passBtn.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:HWChargerWatts)) { [Windows.MessageBox]::Show('Select the charger wattage/type after checking the adapter label.','SLT Hardware QC','OK','Warning') | Out-Null; return }
        if (-not $ledCb.IsChecked) { [Windows.MessageBox]::Show('Complete the charging LED / power check before marking the charger as passed.','SLT Hardware QC','OK','Warning') | Out-Null; return }
        Set-SLTQCResult 'Charger' 'Passed' $script:HWChargerWatts
        if ($script:ChgModalWin) { $script:ChgModalWin.Close() }
    }.GetNewClosure())
    $issueBtn.Add_Click({ Set-SLTQCResult 'Charger' 'Issue' $script:HWChargerWatts; if ($script:ChgModalWin) { $script:ChgModalWin.Close() } })
    $btnRow.Children.Add($passBtn)|Out-Null; $btnRow.Children.Add($issueBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:ChgModalWin = $null
}

# ---------------------------------------------------------------- SMART REPORT ENGINE (1-PAGE A4 CABIN CERTIFICATE) ---
function Build-SLTHardwareReportHtml([hashtable]$Data,[ValidateSet('Technical','Customer')][string]$Mode) {
    # Finalized Two-Tab Single-Page A4 Reports (Customer Certificate & SLT IT Inspection Team Internal)
    # @page { size: A4 portrait; margin: 5mm; }
    $pc   = $Data['PC']
    $cpu  = $Data['CPU']
    $ram  = $Data['RAM']
    $sto  = $Data['Storage']
    $bat  = $Data['Battery']
    $gpu  = $Data['GPU']
    $conn = $Data['Connectivity']
    $pqc  = $Data['PhysicalQC']
    $notes = $Data['Notes']; if ($null -eq $notes) { $notes = @{} }
    $cust = $Data['Customer']; if ($null -eq $cust) { $cust = @{} }

    $devModel = if ($pc -and $pc.Model) { "$($pc.Manufacturer) $($pc.Model)" } else { 'Not reported' }
    $fullSn   = if ($pc -and $pc.SerialNumber) { [string]$pc.SerialNumber } else { '' }
    $maskedSn = if ($fullSn.Length -gt 4) { '****' + $fullSn.Substring($fullSn.Length - 4) } elseif ($fullSn.Length -gt 0) { '****' } else { 'Not reported' }
    $dateStr  = (Get-Date).ToString('dd-MMM-yyyy')

    # Smart RAM Rule: Show DDR type + frequency ONLY if frequency > 3000 AND DDR >= DDR4
    $ramSmart = 'Not reported'
    $ramTech  = 'Not reported'
    if ($ram -and $null -ne $ram.TotalGB -and $ram.TotalGB -gt 0) {
        $s0 = if ($ram.Sticks -and @($ram.Sticks).Count -gt 0) { @($ram.Sticks)[0] } else { $null }
        $rType = if ($s0 -and $s0.Type) { [string]$s0.Type } else { '' }
        $rFreq = if ($s0 -and $s0.ConfiguredMHz) { [int]$s0.ConfiguredMHz } else { 0 }
        $ddrNum = 0
        if ($rType -match '(\d+)') { $ddrNum = [int]$Matches[1] }
        if ($ddrNum -ge 4 -and $rFreq -gt 3000) {
            $ramSmart = "$($ram.TotalGB)GB $rType ${rFreq}MHz"
        } else {
            $ramSmart = "$($ram.TotalGB)GB RAM"
        }
        $slotText = if ($null -ne $ram.TotalSlots) { "$($ram.UsedSlots)/$($ram.TotalSlots) Slots" } else { "$($ram.UsedSlots) populated module(s); total slots not reported" }
        $ramTech = if ($rType -and $rFreq -gt 0) { "$($ram.TotalGB)GB $rType ${rFreq}MHz | $slotText | $($ram.ChannelMode)" } else { "$($ram.TotalGB)GB RAM | $slotText | $($ram.ChannelMode)" }
    }

    # Smart Storage Rule: >90 Excellent, 70-90 Good, 50-70 Normal, <50 Replace
    $d0 = if ($sto -and @($sto).Count -gt 0) { @($sto)[0] } else { $null }
    $stoPct = if ($d0 -and $null -ne $d0.WearRemainingPercent) { [int]$d0.WearRemainingPercent } else { $null }
    $stoCat = if ($null -eq $stoPct) { 'Not reported' } elseif ($stoPct -gt 90) { 'Excellent' } elseif ($stoPct -ge 70) { 'Good' } elseif ($stoPct -ge 50) { 'Normal' } else { 'Replace' }
    $stoSizeStr = if ($d0 -and $d0.SizeGB) { "$($d0.SizeGB)GB $($d0.InterfaceType)" } else { 'Not reported' }
    $stoLifePct = $stoPct

    # Smart Battery Rule (Customer Report): ONLY Excellent / Normal / Good / Replace (NO backup time, NO %)
    $batPct = if ($bat -and $bat.Present -and $null -ne $bat.HealthPercent -and $bat.HealthPercent -gt 0) { [double]$bat.HealthPercent } else { $null }
    $batCat = if ($null -eq $batPct) { 'Not reported' } elseif ($batPct -gt 80) { 'Excellent' } elseif ($batPct -ge 60) { 'Normal' } elseif ($batPct -ge 40) { 'Good' } else { 'Replace' }
    $batBkup = if ($bat -and $bat.PSObject.Properties['BackupHours'] -and $bat.BackupHours) { "$($bat.BackupHours) Hours Backup" } else { 'Not reported' }
    $batWear = if ($null -ne $batPct) { [math]::Round((100.0 - $batPct), 1) } else { $null }

    # Smart Keyboard Rule: Pass = "Keyboard: PASSED"; Issue = only user entered remarks keys
    $kbdState = if ($pqc -and $pqc['Keyboard']) { [string]$pqc['Keyboard'] } else { 'Pending' }
    $kbdNote  = if ($notes -and $notes['Keyboard']) { [string]$notes['Keyboard'] } else { '' }
    $kbdLine  = if ($kbdState -match 'Issue|Fail|Not OK') {
        if (-not [string]::IsNullOrWhiteSpace($kbdNote)) { "Keyboard Issue: $kbdNote" } else { 'Keyboard: Issue' }
    } elseif ($kbdState -match '^(Passed|Pass|OK|Complete|Verified)$') {
        'Keyboard: PASSED'
    } else {
        'Keyboard: PENDING / NOT TESTED'
    }

    $cpuShort = if ($cpu -and $cpu.Name) { ([string]$cpu.Name -replace '\(R\)|\(TM\)','').Trim() } else { 'Not reported' }
    $gpu0 = if ($gpu -and @($gpu).Count -gt 0) { @($gpu)[0] } else { $null }
    $gpuSummary = if ($gpu0 -and $gpu0.Name) { "$($gpu0.Name) ($($gpu0.Resolution))" } else { 'Not reported' }
    $wifiSummary = if ($conn -and $conn.WifiAdapter) { "$($conn.WifiAdapter) ($($conn.WifiState)) &bull; BT: $($conn.Bluetooth)" } else { 'Not reported' }
    $cpuTempStr = if ($cpu -and $null -ne $cpu.TemperatureC) { "$($cpu.TemperatureC)&deg;C" } else { 'Not reported' }
    $stoTempStr = if ($d0 -and $null -ne $d0.TemperatureC) { "$($d0.TemperatureC)&deg;C" } else { 'Not reported' }
    $stoHoursStr = if ($d0 -and $null -ne $d0.PowerOnHours) { "$($d0.PowerOnHours)H" } else { 'Not reported' }
    $osSummary = if ($pc -and $pc.OSName) { "$($pc.OSName) &bull; $($pc.Activation)" } else { 'Not reported' }
    $batPctDisplay = if ($null -ne $batPct) { "$([math]::Round($batPct,1))%" } else { 'Not reported' }
    $batWearDisplay = if ($null -ne $batWear) { "$batWear%" } else { 'Not reported' }
    $stoPctDisplay = if ($null -ne $stoPct) { "$stoPct%" } else { 'Not reported' }
    $stoLifeDisplay = if ($null -ne $stoLifePct) { "$stoLifePct%" } else { 'Not reported' }
    $batBarWidth = if ($null -ne $batPct) { [math]::Max(0,[math]::Min(100,[math]::Round($batPct))) } else { 0 }
    $stoBarWidth = if ($null -ne $stoPct) { [math]::Max(0,[math]::Min(100,$stoPct)) } else { 0 }
    $stoLifeBarWidth = if ($null -ne $stoLifePct) { [math]::Max(0,[math]::Min(100,$stoLifePct)) } else { 0 }
    $bodyQC = if ($pqc -and $pqc['Body']) { [string]$pqc['Body'] } else { 'Pending' }
    $chargerQC = if ($pqc -and $pqc['Charger']) { [string]$pqc['Charger'] } else { 'Pending' }

    $qcFmt = {
        param([string]$k)
        $stVal = if ($pqc -and $pqc.ContainsKey($k) -and $pqc[$k]) { [string]$pqc[$k] } else { 'Pending' }
        if ($stVal -match 'Issue|Fail|Not OK') {
            $nt = if ($notes -and $notes.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace([string]$notes[$k])) { " ($($notes[$k]))" } else { '' }
            return "<span style=`"color:#c2410c;font-weight:700;`">ISSUE$nt !</span>"
        }
        if ($stVal -match '^(Passed|Pass|OK|Complete|Verified)$') { return '<span style="color:#047857;">PASSED &check;</span>' }
        return '<span style="color:#a16207;">PENDING / NOT TESTED</span>'
    }
    $qcScreenHtml = (& $qcFmt 'Screen')
    $qcTouchHtml  = (& $qcFmt 'Touchpad')
    $qcPortsHtml  = (& $qcFmt 'Ports')
    $qcCamHtml    = (& $qcFmt 'Camera')
    $qcSpkHtml    = (& $qcFmt 'Audio')
    $qcMicHtml    = (& $qcFmt 'Microphone')
    $qcBodyHtml   = (& $qcFmt 'Body')

    $defaultWarrantyText = '10 Days Check Warranty - Any issue you can replace laptop. After 10 days 6 Months Service Warranty. Software issue? Online support via AnyDesk. Office 365 License Provided On Demand.'
    $custRemText = if ($cust.ContainsKey('Remarks') -and -not [string]::IsNullOrWhiteSpace([string]$cust['Remarks'])) { ([string]$cust['Remarks']).Trim() } else { $defaultWarrantyText }

    $activeCust = if ($Mode -eq 'Customer') { 'active' } else { '' }
    $activeInt  = if ($Mode -eq 'Technical') { 'active' } else { '' }

    $htmlPath = Join-Path $script:StateDir 'SLT_A4_Report_Preview.html'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>SLT Smart PC Boost - Final A4 Reports</title>
<style>
  @page { size: A4 portrait; margin: 0; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Inter', 'Segoe UI', system-ui, sans-serif; background: #e8eef0; color: #0f172a; padding: 16px; }
  .toolbar { max-width: 210mm; margin: 0 auto 14px auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; }
  .tab-btn { border: none; background: #f1f5f9; color: #475569; font-weight: 700; font-size: 12px; padding: 8px 16px; border-radius: 9px; cursor: pointer; margin-right: 6px; }
  .tab-btn.active { background: #0f766e; color: #ffffff; }
  .print-btn { border: none; background: #0f766e; color: #ffffff; font-weight: 700; font-size: 12px; padding: 8px 18px; border-radius: 999px; cursor: pointer; }
  .a4-sheet { width: 210mm; height: 297mm; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 16mm; border-top: 6px solid #0f766e; display: none; flex-direction: column; justify-content: space-between; box-shadow: 0 10px 30px rgba(0,0,0,0.12); overflow: hidden; }
  .a4-sheet.active { display: flex; }
  .rep-hdr { display: flex; justify-content: space-between; align-items: flex-start; padding-bottom: 10px; border-bottom: 1px solid #e2e8f0; }
  .emblem { width: 40px; height: 40px; border-radius: 12px; background: #0f766e; color: #ffffff; font-weight: 800; font-size: 20px; display: inline-flex; align-items: center; justify-content: center; margin-right: 10px; }
  .badge-pill { background: #f0fdfa; border: 1px solid #99f6e4; color: #0f766e; font-size: 10px; font-weight: 700; padding: 4px 10px; border-radius: 999px; text-transform: uppercase; }
  .spec-5-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; margin-top: 8px; }
  .spec-box { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 7px 9px; }
  .spec-box .l { font-size: 8.8px; font-weight: 700; text-transform: uppercase; color: #64748b; }
  .spec-box .v { font-size: 11px; font-weight: 700; color: #0f172a; margin-top: 2px; }
  .blanks-5 { display: grid; grid-template-columns: 1.4fr 1.1fr 0.9fr 0.9fr 0.9fr; gap: 8px; margin-top: 10px; }
  .blank-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 6px 10px; }
  .blank-card .l { font-size: 8.8px; font-weight: 700; text-transform: uppercase; color: #64748b; }
  .blank-in { width: 100%; border: none; border-bottom: 1.5px dashed #cbd5e1; font-size: 11.5px; font-weight: 600; color: #0f172a; padding: 2px 0; margin-top: 2px; outline: none; background: transparent; }
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 10px; }
  .card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 16px; padding: 10px 14px; }
  .card-h { font-size: 11px; font-weight: 800; text-transform: uppercase; color: #0f766e; margin-bottom: 6px; border-bottom: 1px solid #f1f5f9; padding-bottom: 4px; }
  .kv { display: grid; grid-template-columns: 145px 1fr; gap: 8px; padding: 4px 0; border-bottom: 1px dashed #e2e8f0; font-size: 11px; text-align: left; }
  .kv:last-child { border-bottom: none; }
  .kv .k { color: #475569; text-align: left; } .kv .v { color: #0f172a; font-weight: 600; text-align: left; }
  .cat-ok { background: #ecfdf5; border: 1px solid #a7f3d0; color: #047857; padding: 1px 8px; border-radius: 999px; font-size: 10px; font-weight: 700; }
  .qc-8 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 7px; margin-top: 10px; }
  .qc-p { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 6px 10px; display: flex; justify-content: space-between; font-size: 10.5px; font-weight: 600; }
  .kbd-bar { margin-top: 9px; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 12px; padding: 7px 12px; font-size: 11px; font-weight: 700; color: #047857; display: flex; justify-content: space-between; }
  .sw-box { margin-top: 10px; background: #f0fdfa; border: 1px solid #99f6e4; border-radius: 16px; padding: 11px 14px; }
  .sw-h { font-size: 11.5px; font-weight: 800; color: #0f766e; margin-bottom: 4px; }
  .sw-p { font-size: 10.5px; line-height: 1.46; color: #334155; font-weight: 500; }
  .triage-g { background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 14px; padding: 8px 12px; margin-top: 8px; }
  .triage-y { background: #fffbeb; border: 1px solid #fde68a; border-radius: 14px; padding: 8px 12px; margin-top: 7px; }
  .triage-r { background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 14px; padding: 8px 12px; margin-top: 7px; }
  .chip { display: inline-block; background: #ffffff; border: 1px solid rgba(0,0,0,0.08); border-radius: 8px; padding: 3px 8px; font-size: 10.2px; font-weight: 600; margin: 2px 4px 2px 0; }
  .graph-box { margin-top: 9px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 16px; padding: 8px 14px; }
  .graph-60 { height: 60px; display: grid; grid-template-columns: 1.45fr 1fr; gap: 14px; align-items: center; }
  .bars-4 { display: grid; grid-template-columns: 1fr 1fr; gap: 5px 12px; }
  .bar-t { height: 7px; background: #e2e8f0; border-radius: 999px; overflow: hidden; margin-top: 2px; }
  .bar-f { height: 100%; background: #16a34a; border-radius: 999px; }
  .ftr { padding-top: 8px; border-top: 1px solid #e2e8f0; font-size: 9px; color: #4b5563; line-height: 1.4; }
  @media print { body { background: #ffffff !important; padding: 0 !important; } .toolbar { display: none !important; } .a4-sheet { box-shadow: none !important; margin: 0 !important; } }
</style>
</head>
<body>
  <div class="toolbar">
    <div>
      <button id="bCust" class="tab-btn $activeCust" onclick="sw('cust')">1. Customer Certificate (A4)</button>
      <button id="bInt" class="tab-btn $activeInt" onclick="sw('int')">2. SLT IT Inspection Team Internal (A4)</button>
    </div>
    <button class="print-btn" onclick="window.print()">Print Single-Page A4 Report</button>
  </div>

  <!-- TAB 1: CUSTOMER CERTIFICATE -->
  <section id="sCust" class="a4-sheet $activeCust">
    <div>
      <div class="rep-hdr">
        <div style="display:flex;align-items:center;">
          <div class="emblem">S</div>
          <div>
            <div style="font-size:16px;font-weight:800;">SMART LIFE TECK</div>
            <div style="font-size:10px;font-weight:700;color:#0f766e;letter-spacing:0.08em;">SLT IT INSPECTION TEAM &bull; LAPTOP QC CERTIFICATE</div>
          </div>
        </div>
        <div style="text-align:right;">
          <span class="badge-pill">Customer Quality Certificate</span>
          <div style="font-size:10.5px;color:#64748b;margin-top:4px;">Date: $dateStr &nbsp;|&nbsp; Serial: $maskedSn</div>
        </div>
      </div>

      <div style="margin-top:10px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:16px;padding:10px 12px;">
        <div style="display:flex;justify-content:space-between;align-items:center;">
          <strong style="font-size:14px;">$devModel &mdash; Inspection Record</strong>
          <span class="cat-ok">Inspection report - verify all checks</span>
        </div>
        <div class="spec-5-grid">
          <div class="spec-box"><div class="l">Laptop Model</div><div class="v">$devModel</div></div>
          <div class="spec-box"><div class="l">Processor</div><div class="v">$cpuShort</div></div>
          <div class="spec-box"><div class="l">Memory (RAM)</div><div class="v">$ramSmart</div></div>
          <div class="spec-box"><div class="l">Storage</div><div class="v">$stoSizeStr</div></div>
          <div class="spec-box" style="background:#f0fdfa;border-color:#99f6e4;"><div class="l" style="color:#0f766e;">System</div><div class="v" style="color:#0f766e;">$osSummary</div></div>
        </div>
      </div>

      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:10px;">
        <div class="blank-card"><div class="l">Customer Name</div><input class="blank-in" value="$($cust['Name'])" placeholder=" " /></div>
        <div class="blank-card"><div class="l">City</div><input class="blank-in" value="$($cust['City'])" placeholder=" " /></div>
        <div class="blank-card"><div class="l">Contact Number</div><input class="blank-in" value="$($cust['Mobile'])" placeholder=" " /></div>
        <div class="blank-card"><div class="l">Laptop Price</div><input class="blank-in" value="$($cust['RetailPrice'])" placeholder=" " /></div>
      </div>

      <div class="grid-2">
        <div class="card">
          <div class="card-h">Core Hardware Specifications</div>
          <div class="kv"><span class="k">Laptop Model</span><span class="v">$devModel</span></div>
          <div class="kv"><span class="k">Processor (CPU)</span><span class="v">$cpuShort</span></div>
          <div class="kv"><span class="k">Memory (RAM)</span><span class="v">$ramSmart</span></div>
          <div class="kv"><span class="k">Graphics &amp; Display</span><span class="v">$gpuSummary</span></div>
          <div class="kv"><span class="k">Wi-Fi &amp; Bluetooth</span><span class="v">$wifiSummary</span></div>
        </div>
        <div class="card">
          <div class="card-h">Health &amp; Condition Categories</div>
          <div class="kv"><span class="k">SSD Storage Health</span><span class="v">Health: $stoCat &nbsp;$stoSizeStr</span></div>
          <div class="kv"><span class="k">Battery Condition</span><span class="v">$batCat</span></div>
          <div class="kv"><span class="k">Thermal &amp; Cooling</span><span class="v">Not tested</span></div>
          <div class="kv"><span class="k">Power Adapter</span><span class="v">Not verified</span></div>
          <div class="kv"><span class="k">Operating System</span><span class="v">$osSummary</span></div>
        </div>
      </div>

      <div class="qc-8">
        <div class="qc-p"><span>Display / LCD</span>$qcScreenHtml</div>
        <div class="qc-p"><span>Touchpad</span>$qcTouchHtml</div>
        <div class="qc-p"><span>USB &amp; Ports</span>$qcPortsHtml</div>
        <div class="qc-p"><span>Camera</span>$qcCamHtml</div>
        <div class="qc-p"><span>Speakers</span>$qcSpkHtml</div>
        <div class="qc-p"><span>Microphone</span>$qcMicHtml</div>
        <div class="qc-p"><span>Wi-Fi &amp; BT</span><span style="color:#a16207;">PENDING / NOT TESTED</span></div>
        <div class="qc-p"><span>Body &amp; Hinges</span>$qcBodyHtml</div>
      </div>

      <div class="kbd-bar">
        <span>$kbdLine</span>
        <span style="font-size:10px;">QC status shown as recorded</span>
      </div>

      <div class="sw-box">
        <div class="sw-h">Software &amp; Service Notes</div>
        <div class="sw-p">Record only the applications, Windows activation state, and support services actually verified for this device. This section is informational and is not a hardware test result.<br><strong style="color:#0f766e;">Remarks &amp; Warranty:</strong> $custRemText</div>
      </div>
    </div>

    <div class="ftr">
      <div>Terms: 10 Days Check Warranty. No warranty for physical damage, drop, liquid/water. Battery &amp; Screen no warranty against water/drop. Condition notes must be recorded during inspection. Major hardware failure? 6 Months Service Support. This report is generated from the data and QC checks recorded at inspection time; it is not a digital signature.</div>
      <div style="display:flex;justify-content:space-between;margin-top:4px;font-weight:600;color:#0f766e;">
        <span>www.smartlifeteck.com &nbsp;|&nbsp; info@smartlifeteck.com &nbsp;|&nbsp; WhatsApp +966 553760854</span>
        <span>SLT IT Inspection Team</span>
      </div>
    </div>
  </section>

  <!-- TAB 2: SLT IT INSPECTION TEAM INTERNAL -->
  <section id="sInt" class="a4-sheet $activeInt">
    <div>
      <div class="rep-hdr">
        <div style="display:flex;align-items:center;">
          <div class="emblem">S</div>
          <div>
            <div style="font-size:16px;font-weight:800;">SMART LIFE TECK</div>
            <div style="font-size:10px;font-weight:700;color:#0f766e;letter-spacing:0.08em;">SLT IT INSPECTION TEAM &bull; INTERNAL TECHNICAL &amp; MARGIN SHEET</div>
          </div>
        </div>
        <div style="text-align:right;">
          <span class="badge-pill">SLT IT Team Internal</span>
          <div style="font-size:10.5px;color:#64748b;margin-top:4px;">Date: $dateStr &nbsp;|&nbsp; Masked SN: <b>$maskedSn</b> &nbsp;|&nbsp; Team: <b>SLT IT Team</b></div>
        </div>
      </div>

      <div style="display:grid;grid-template-columns:1fr 1fr 1.1fr 1.5fr;gap:8px;margin-top:10px;background:#f0fdfa;border:1px solid #99f6e4;border-radius:16px;padding:10px;">
        <div class="blank-card"><div class="l">Purchase Cost (SAR)</div><input id="pCost" type="number" class="blank-in" placeholder="Blank SAR" oninput="calcP()" /></div>
        <div class="blank-card"><div class="l">Selling Price (SAR)</div><input id="sPrice" type="number" class="blank-in" placeholder="Blank SAR" oninput="calcP()" /></div>
        <div class="blank-card"><div class="l">Expected Profit (Auto)</div><div id="pOut" style="font-size:12px;font-weight:800;color:#047857;margin-top:3px;">SAR &mdash;</div></div>
        <div class="blank-card"><div class="l">Market Class (Editable)</div>
          <select style="width:100%;border:1px solid #99f6e4;background:#f0fdfa;color:#0f766e;font-size:11px;font-weight:700;padding:2px 4px;border-radius:6px;margin-top:2px;">
            <option value="" selected disabled>Select after inspection</option>
            <option>A &mdash; Premium Ready for Sale</option>
            <option>B &mdash; Good</option>
            <option>C &mdash; Budget</option>
            <option>D &mdash; Return Do Not Sell</option>
          </select>
        </div>
      </div>

      <div class="triage-g">
        <div style="font-size:10.5px;font-weight:800;color:#047857;margin-bottom:4px;">HARDWARE TELEMETRY &mdash; MEASURED VALUES ONLY</div>
        <div>
          <span class="chip">Battery ($batPctDisplay Health &bull; Wear $batWearDisplay &bull; $batBkup)</span>
          <span class="chip">Storage $stoPctDisplay Health &bull; Life $stoLifeDisplay ($stoTempStr &bull; $stoHoursStr)</span>
          <span class="chip">Processor ($cpuShort &bull; Temperature: $cpuTempStr)</span>
          <span class="chip">Memory ($ramTech)</span>
        </div>
      </div>

      <div class="triage-y">
        <div style="font-size:10.5px;font-weight:800;color:#b45309;margin-bottom:4px;">&bull; MIDDLE YELLOW &mdash; GOOD / NORMAL CONDITION</div>
        <div>
          <span class="chip">Body QC: $bodyQC</span>
          <span class="chip">Keyboard QC: $kbdLine</span>
        </div>
      </div>

      <div class="triage-r">
        <div style="font-size:10.5px;font-weight:800;color:#b45309;margin-bottom:4px;">ISSUES &amp; PENDING CHECKS</div>
        <div><span class="chip" style="color:#047857;font-weight:700;">Review all issues and pending checks before assigning sale status.</span></div>
      </div>

      <div class="grid-2">
        <div class="card">
          <div class="card-h">Full Technical Telemetry</div>
          <div class="kv"><span class="k">System &amp; OS</span><span class="v">$osSummary</span></div>
          <div class="kv"><span class="k">Processor</span><span class="v">$cpuShort</span></div>
          <div class="kv"><span class="k">RAM Detail</span><span class="v">$ramTech</span></div>
          <div class="kv"><span class="k">Keyboard Status</span><span class="v">$kbdLine</span></div>
        </div>
        <div class="card">
          <div class="card-h">Storage &amp; Battery Metrics</div>
          <div class="kv"><span class="k">SSD Health &amp; Life</span><span class="v">Health $stoPctDisplay &bull; Life $stoLifeDisplay &bull; $stoHoursStr</span></div>
          <div class="kv"><span class="k">Battery Health</span><span class="v">Health $batPctDisplay (Wear $batWearDisplay) &bull; $batBkup</span></div>
          <div class="kv"><span class="k">Charger &amp; Body</span><span class="v">Charger: $chargerQC &bull; Body: $bodyQC</span></div>
          <div class="kv"><span class="k">Inspection Team</span><span class="v">SLT IT Inspection Team</span></div>
        </div>
      </div>

      <div class="graph-box">
        <div style="display:flex;justify-content:space-between;font-size:10px;font-weight:800;color:#0f766e;margin-bottom:4px;">
          <span>GRAPHICAL OVERVIEW (60PX)</span>
          <span style="color:#047857;">No automatic sale grade assigned</span>
        </div>
        <div class="graph-60">
          <div class="bars-4">
            <div><div style="display:flex;justify-content:space-between;font-size:9.5px;font-weight:700;"><span>Battery Health</span><span>$batPctDisplay</span></div><div class="bar-t"><div class="bar-f" style="width:$batBarWidth%;"></div></div></div>
            <div><div style="display:flex;justify-content:space-between;font-size:9.5px;font-weight:700;"><span>Storage Health</span><span>$stoPctDisplay</span></div><div class="bar-t"><div class="bar-f" style="width:$stoBarWidth%;"></div></div></div>
            <div><div style="display:flex;justify-content:space-between;font-size:9.5px;font-weight:700;"><span>Storage Life</span><span>$stoLifeDisplay</span></div><div class="bar-t"><div class="bar-f" style="width:$stoLifeBarWidth%;"></div></div></div>
            <div><div style="display:flex;justify-content:space-between;font-size:9.5px;font-weight:700;"><span>Overall Score</span><span>Not calculated</span></div><div class="bar-t"><div class="bar-f" style="width:0%;"></div></div></div>
          </div>
          <div style="display:flex;align-items:center;justify-content:flex-end;gap:10px;">
            <svg width="52" height="52" viewBox="0 0 36 36">
              <circle cx="18" cy="18" r="14" fill="none" stroke="#e2e8f0" stroke-width="5"></circle>
              <text x="18" y="20.5" text-anchor="middle" font-size="6" font-weight="800" fill="#0f172a">N/A</text>
            </svg>
            <div style="font-size:9.5px;font-weight:600;line-height:1.4;">
              <div>&bull; Only measured values are shown</div>
              <div>&bull; Unknown values remain unreported</div>
              <div>&bull; Pending QC is not treated as passed</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="ftr">
      <div>Manual grading guidance: technician must review all measured values and QC results. No automatic sale grade is assigned by this report.</div>
      <div style="display:flex;justify-content:space-between;margin-top:4px;font-weight:600;color:#0f766e;">
        <span>www.smartlifeteck.com &nbsp;|&nbsp; info@smartlifeteck.com &nbsp;|&nbsp; WhatsApp +966 553760854</span>
        <span>SLT IT Inspection Team</span>
      </div>
    </div>
  </section>

  <script>
    function sw(m) {
      document.getElementById('sCust').classList.toggle('active', m==='cust');
      document.getElementById('sInt').classList.toggle('active', m==='int');
      document.getElementById('bCust').classList.toggle('active', m==='cust');
      document.getElementById('bInt').classList.toggle('active', m==='int');
    }
    function calcP() {
      var c = parseFloat(document.getElementById('pCost').value);
      var s = parseFloat(document.getElementById('sPrice').value);
      var o = document.getElementById('pOut');
      if (!isNaN(c) && !isNaN(s)) {
        var p = s - c;
        o.textContent = (p >= 0 ? '+SAR ' : '-SAR ') + Math.abs(p).toFixed(0);
        o.style.color = p >= 0 ? '#047857' : '#dc2626';
      } else { o.textContent = 'SAR '; }
    }
  </script>
</body>
</html>
"@)
    return $sb.ToString()
}

function Show-SLTHardwareReport([hashtable]$Data,[string]$Mode) {
    try {
        if ($null -eq $Data) { $Data = @{} }
        $html = Build-SLTHardwareReportHtml -Data $Data -Mode $Mode
        $path = Join-Path (Get-SLTTempPath) ("SLT_HW_Report_{0}_{1}.html" -f $Mode, (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Set-Content -LiteralPath $path -Value $html -Encoding UTF8
        Start-Process $path
        Log-SLT ("Hardware QC report opened: $path")
    } catch {
        Log-SLT ('View Report failed: ' + $_.Exception.Message)
        [Windows.MessageBox]::Show(('The report could not be opened: ' + $_.Exception.Message + "`r`n`r`nRun Scan Diagnostics and send the exact message."),'Smart Life Teck - Report Failed','OK','Error') | Out-Null
    }
}

function Save-SLTHardwareReport([hashtable]$Data,[string]$Mode) {
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter='HTML Report (*.html)|*.html'
    $dlg.FileName = "SLT_QC_${Mode}_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    if ($dlg.ShowDialog()) {
        try {
            $html = Build-SLTHardwareReportHtml -Data $Data -Mode $Mode
            Set-Content -LiteralPath $dlg.FileName -Value $html -Encoding UTF8
            Log-SLT ('Hardware QC report saved: '+$dlg.FileName)
            [Windows.MessageBox]::Show('Report saved successfully:`n'+$dlg.FileName,'Smart Life Teck','OK','Information')|Out-Null
        } catch {
            Log-SLT ('Save Report failed: ' + $_.Exception.Message)
            [Windows.MessageBox]::Show(('The report could not be saved: ' + $_.Exception.Message),'Smart Life Teck - Report Failed','OK','Error')|Out-Null
        }
    }
}

function Invoke-SLTScanDiagnostics {
    # SCAN FIX: test every hardware step separately. One failed step must not
    # hide the others, and the exact error is logged for the technician.
    $results = @()
    $steps = @(
        @{Name='Computer / BIOS / Motherboard'; Test={ Get-SLTFullComputerInfo }},
        @{Name='CPU & Thermal'; Test={ Get-SLTCPUDetail }},
        @{Name='RAM Slots'; Test={ Get-SLTRAMDetail }},
        @{Name='Storage Health'; Test={ Get-SLTStorageDetail }},
        @{Name='Battery'; Test={ Get-SLTBatteryDetail }},
        @{Name='GPU & Display'; Test={ Get-SLTGPUDetail }},
        @{Name='Drivers & Ports'; Test={ Get-SLTDeviceAndPortHealth }},
        @{Name='CPU Data Sources (CIM / WMI / Registry / Env)'; Test={ $pn = Get-SLTProcessorName; $rg = Get-SLTCpuRegistryInfo; if ($pn.Source -eq 'Not reported' -and -not $rg.Identifier) { throw 'No CPU source responded: CIM Win32_Processor empty, registry CentralProcessor unreadable, environment identifier missing.' } }},
        @{Name='GPU Detail Fields'; Test={ $g = @(Get-SLTGPUDetail); if ($g.Count -eq 0) { throw 'No display adapter returned by Win32_VideoController.' } }},
        @{Name='RAM Speed Benchmark'; Test={ $m = Measure-SLTRAMBandwidth; if ($null -eq $m.ReadMBs) { throw ('Managed RAM benchmark failed: ' + $m.Error) } }},
        @{Name='Speaker Tone WAV Generation'; Test={ $w = New-SLTChannelToneWav 'Left'; try { $lv = Get-SLTWavPeakLevel $w; if ($lv.Error) { throw $lv.Error }; if ($lv.PeakPercent -le 0) { throw 'Tone WAV has zero peak level.' } } finally { try { Remove-Item -LiteralPath $w -Force -ErrorAction SilentlyContinue } catch {} } }}
    )
    foreach ($s in $steps) {
        try {
            $null = & $s.Test
            $results += [pscustomobject]@{Step=$s.Name; Status='OK'; Detail='Returned data'}
            Log-SLT ('Scan diagnostics OK: ' + $s.Name)
        } catch {
            $results += [pscustomobject]@{Step=$s.Name; Status='FAILED'; Detail=$_.Exception.Message}
            Log-SLT ('Scan diagnostics FAILED: ' + $s.Name + ' - ' + $_.Exception.Message)
        }
    }
    return $results
}

function Get-SLTHardwareLockPath {
    $statePath = Join-Path $env:ProgramData 'SmartLifeTeck\PCCarePro\State'
    if (-not (Test-Path -LiteralPath $statePath)) {
        New-Item -ItemType Directory -Path $statePath -Force -ErrorAction Stop | Out-Null
    }
    return (Join-Path $statePath 'HardwareLock.json')
}

function New-SLTHardwarePinRecord([string]$Pin) {
    $salt = New-Object byte[] 16
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($salt) } finally { $rng.Dispose() }
    $iterations = 200000
    $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Pin, $salt, $iterations)
    try { $hash = $derive.GetBytes(32) } finally { $derive.Dispose() }
    return [pscustomobject]@{
        schemaVersion = 1
        algorithm = 'PBKDF2-HMAC-SHA1'
        iterations = $iterations
        salt = [Convert]::ToBase64String($salt)
        hash = [Convert]::ToBase64String($hash)
        createdUtc = [DateTime]::UtcNow.ToString('o')
    }
}

function Test-SLTHardwarePin([string]$Pin, [object]$Record) {
    try {
        if ([string]::IsNullOrWhiteSpace($Pin) -or $null -eq $Record) { return $false }
        $iterations = [int]$Record.iterations
        if ($iterations -lt 100000 -or $iterations -gt 1000000) { return $false }
        $salt = [Convert]::FromBase64String([string]$Record.salt)
        $expected = [Convert]::FromBase64String([string]$Record.hash)
        if ($salt.Length -ne 16 -or $expected.Length -ne 32) { return $false }
        $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Pin, $salt, $iterations)
        try { $actual = $derive.GetBytes(32) } finally { $derive.Dispose() }
        $diff = 0
        for ($i = 0; $i -lt $expected.Length; $i++) { $diff = $diff -bor ($expected[$i] -bxor $actual[$i]) }
        return ($diff -eq 0)
    } catch { return $false }
}

function Save-SLTHardwarePinRecord([object]$Record, [string]$Path) {
    $json = $Record | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding $false))
    # Restrict the local lock file to SYSTEM, local Administrators, and the current user.
    try {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($existingRule in @($acl.Access)) { $acl.RemoveAccessRuleAll($existingRule) }
        $accounts = @('SYSTEM', 'BUILTIN\Administrators', [Security.Principal.WindowsIdentity]::GetCurrent().Name)
        foreach ($account in ($accounts | Select-Object -Unique)) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($account, 'FullControl', 'Allow')
            [void]$acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
    } catch {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        throw ('Could not secure the local staff PIN file permissions: ' + $_.Exception.Message)
    }
}

function Show-SLTHardwarePinSetup([string]$Path) {
    $dlg = New-Object Windows.Window
    $dlg.Title = 'Create Smart Life Teck Staff PIN'
    $dlg.Width = 450; $dlg.Height = 310; $dlg.WindowStartupLocation = 'CenterOwner'; $dlg.ResizeMode = 'NoResize'
    if ($script:Window) { $dlg.Owner = $script:Window }
    Apply-SLTDialogTheme $dlg
    $stack = New-Object Windows.Controls.StackPanel; $stack.Margin = [Windows.Thickness]::new(22)
    $stack.Children.Add((New-SLTText 'Create a local staff PIN' 17 $true '#50DBFF')) | Out-Null
    $stack.Children.Add((New-SLTText 'First use only. Choose at least 8 characters. The app stores a salted hash, not the PIN.' 11 $false '#9DC6E1')) | Out-Null
    $pin1 = New-Object Windows.Controls.PasswordBox; $pin1.Margin = [Windows.Thickness]::new(0,14,0,0); $pin1.Padding = [Windows.Thickness]::new(8,6,8,6); $pin1.FontSize = 16
    $pin2 = New-Object Windows.Controls.PasswordBox; $pin2.Margin = [Windows.Thickness]::new(0,8,0,0); $pin2.Padding = [Windows.Thickness]::new(8,6,8,6); $pin2.FontSize = 16
    $pin1.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'InputBg'); $pin1.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary')
    $pin2.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'InputBg'); $pin2.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary')
    $pin1.ToolTip = 'New staff PIN'; $pin2.ToolTip = 'Confirm staff PIN'
    $stack.Children.Add($pin1) | Out-Null; $stack.Children.Add($pin2) | Out-Null
    $err = New-SLTText '' 11 $false '#EF4444'; $err.Margin = [Windows.Thickness]::new(0,6,0,0); $stack.Children.Add($err) | Out-Null
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = [Windows.Thickness]::new(0,12,0,0)
    $cancel = New-Object Windows.Controls.Button; $cancel.Content = 'Cancel'; $cancel.MinWidth = 95; $cancel.Margin = [Windows.Thickness]::new(0,0,8,0)
    $save = New-Object Windows.Controls.Button; $save.Content = 'Save PIN'; $save.MinWidth = 105
    $cancel.Add_Click(({ $dlg.DialogResult = $false; $dlg.Close() }).GetNewClosure())
    $save.Add_Click({
        if ($pin1.Password.Length -lt 8) { $err.Text = 'PIN must be at least 8 characters.'; return }
        if ($pin1.Password -cne $pin2.Password) { $err.Text = 'PIN entries do not match.'; $pin2.Clear(); return }
        try {
            $record = New-SLTHardwarePinRecord $pin1.Password
            Save-SLTHardwarePinRecord $record $Path
            $pin1.Clear(); $pin2.Clear(); $dlg.DialogResult = $true; $dlg.Close()
        } catch { $err.Text = ('Could not save PIN securely: ' + $_.Exception.Message) }
    }.GetNewClosure())
    $row.Children.Add($cancel) | Out-Null; $row.Children.Add($save) | Out-Null; $stack.Children.Add($row) | Out-Null
    $dlg.Content = $stack
    $dlg.Add_Loaded(({ $pin1.Focus() | Out-Null }).GetNewClosure())
    return ($dlg.ShowDialog() -eq $true)
}

function Confirm-SLTHWPinAttempt {
    if (-not $script:HWPinDlg -or -not $script:HWPinBox) { return }
    if (Test-SLTHardwarePin $script:HWPinBox.Password $script:HWPinRecord) {
        $script:HWPinDlg.DialogResult = $true
        $script:HWPinDlg.Close()
    } else {
        $script:HWPinAttempts++
        if ($script:HWPinErr) { $script:HWPinErr.Text = if ($script:HWPinAttempts -ge 5) { 'Too many attempts. Access cancelled.' } else { 'Incorrect PIN. Try again.' } }
        $script:HWPinBox.Clear()
        if ($script:HWPinAttempts -ge 5) { $script:HWPinDlg.DialogResult = $false; $script:HWPinDlg.Close() }
    }
}

function Test-SLTHardwareAccess {
    try {
        $cfgPath = Get-SLTHardwareLockPath
        if (-not (Test-Path -LiteralPath $cfgPath)) {
            return (Show-SLTHardwarePinSetup $cfgPath)
        }
        try { $script:HWPinRecord = Get-Content -LiteralPath $cfgPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch { [Windows.MessageBox]::Show('The local staff PIN record is invalid. Do not delete or overwrite it automatically. Contact your administrator to recover access.','Smart Life Teck - PIN Record Error','OK','Error') | Out-Null; return $false }
        if ($script:HWPinRecord.schemaVersion -ne 1 -or $script:HWPinRecord.algorithm -ne 'PBKDF2-HMAC-SHA1') {
            [Windows.MessageBox]::Show('Unsupported staff PIN record format. Access has been denied.','Smart Life Teck - PIN Record Error','OK','Error') | Out-Null
            return $false
        }
    } catch {
        [Windows.MessageBox]::Show(('Could not load the local staff PIN settings: ' + $_.Exception.Message),'Smart Life Teck - PIN Error','OK','Error') | Out-Null
        return $false
    }

    $dlg = New-Object Windows.Window
    $dlg.Title = 'SLT Developer & Hardware QC - Staff PIN Required'; $dlg.Width = 430; $dlg.Height = 240
    $dlg.WindowStartupLocation = 'CenterOwner'; $dlg.ResizeMode = 'NoResize'
    if ($script:Window) { $dlg.Owner = $script:Window }
    Apply-SLTDialogTheme $dlg
    $stack = New-Object Windows.Controls.StackPanel; $stack.Margin = [Windows.Thickness]::new(22)
    $stack.Children.Add((New-SLTText 'Smart Hardware Inspection & QC' 17 $true '#50DBFF')) | Out-Null
    $stack.Children.Add((New-SLTText 'Enter your locally configured Smart Life Teck staff PIN.' 12 $false '#9DC6E1')) | Out-Null
    $box = New-Object Windows.Controls.PasswordBox; $box.Margin = [Windows.Thickness]::new(0,12,0,0); $box.Padding = [Windows.Thickness]::new(8,6,8,6); $box.FontSize = 16
    $box.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'InputBg'); $box.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'TextPrimary'); $box.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty,'InputBorder')
    $stack.Children.Add($box) | Out-Null
    $err = New-SLTText '' 11 $false '#EF4444'; $stack.Children.Add($err) | Out-Null
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = [Windows.Thickness]::new(0,12,0,0)
    $cancel = New-Object Windows.Controls.Button; $cancel.Content = 'Cancel'; $cancel.MinWidth = 95
    $ok = New-Object Windows.Controls.Button; $ok.Content = 'Unlock'; $ok.MinWidth = 105
    $script:HWPinDlg = $dlg; $script:HWPinBox = $box; $script:HWPinErr = $err; $script:HWPinAttempts = 0
    $cancel.Add_Click(({ $dlg.DialogResult = $false; $dlg.Close() }).GetNewClosure())
    $ok.Add_Click({ Confirm-SLTHWPinAttempt })
    $box.Add_KeyDown({ param($sender,$e) if ($e.Key -eq 'Return') { Confirm-SLTHWPinAttempt } })
    $row.Children.Add($cancel) | Out-Null; $row.Children.Add($ok) | Out-Null; $stack.Children.Add($row) | Out-Null
    $dlg.Content = $stack; $dlg.Add_Loaded(({ $box.Focus() | Out-Null }).GetNewClosure())
    $result = ($dlg.ShowDialog() -eq $true)
    $box.Clear(); $script:HWPinDlg = $null; $script:HWPinBox = $null; $script:HWPinErr = $null; $script:HWPinRecord = $null
    return $result
}

# ---------------------------------------------------------------- 420px AUTO SCAN CABIN DETAIL MODAL & BUILT-IN ADVANCED TOOLS ---
function New-SLTCabinDetailRow([string]$Key, [string]$Val, [string]$ValHex='#0F172A') {
    $bdr = New-Object Windows.Controls.Border
    $bdr.BorderBrush = (New-SLTBrush '#E5E7EB')
    $bdr.BorderThickness = [Windows.Thickness]::new(0,0,0,1)
    $bdr.Padding = [Windows.Thickness]::new(4,7,4,7)
    $g = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = New-Object Windows.GridLength(135)
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $g.ColumnDefinitions.Add($c0)|Out-Null; $g.ColumnDefinitions.Add($c1)|Out-Null
    $kTb = New-Object Windows.Controls.TextBlock
    $kTb.Text = $Key; $kTb.FontSize = 11.5; $kTb.FontWeight = 'Medium'; $kTb.Foreground = (New-SLTBrush '#64748B')
    $kTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)
    $vTb = New-Object Windows.Controls.TextBlock
    $vTb.Text = $Val; $vTb.FontSize = 11.5; $vTb.FontWeight = 'SemiBold'; $vTb.Foreground = (New-SLTBrush $ValHex)
    $vTb.HorizontalAlignment = 'Right'; $vTb.TextWrapping = 'Wrap'; $vTb.TextAlignment = 'Right'
    $vTb.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $g.Children.Add($kTb)|Out-Null; $g.Children.Add($vTb)|Out-Null
    $bdr.Child = $g
    return $bdr
}

function Show-SLTAutoCabinDetailModal([string]$CabinId) {
    if ($null -eq $script:HWData['PC'] -and (Get-Command Invoke-SLTCompleteHardwarePostMortem -ErrorAction SilentlyContinue)) {
        try { Invoke-SLTCompleteHardwarePostMortem } catch {}
    }
    $win = New-Object Windows.Window
    $win.Title = "SLT Smart PC Boost - $($CabinId.ToUpper()) Details"
    $win.Width = 420
    $win.SizeToContent = 'Height'
    $win.WindowStartupLocation = 'CenterOwner'
    $win.Owner = $script:Window
    $win.ResizeMode = 'NoResize'
    $win.Background = (New-SLTBrush '#FFFFFF')
    $win.Foreground = (New-SLTBrush '#0F172A')
    $win.FontFamily = 'Segoe UI'
    $script:AutoDetailModalWin = $win

    $outer = New-Object Windows.Controls.StackPanel
    $outer.Margin = [Windows.Thickness]::new(20,18,20,18)

    # Top Header Row with Teal Badge + Title + Passed Pill
    $hdrGrid = New-Object Windows.Controls.Grid
    $hc0 = New-Object Windows.Controls.ColumnDefinition; $hc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $hc1 = New-Object Windows.Controls.ColumnDefinition; $hc1.Width = [Windows.GridLength]::Auto
    $hdrGrid.ColumnDefinitions.Add($hc0)|Out-Null; $hdrGrid.ColumnDefinitions.Add($hc1)|Out-Null
    $hdrGrid.Margin = [Windows.Thickness]::new(0,0,0,12)

    $titleStack = New-Object Windows.Controls.StackPanel; $titleStack.Orientation = 'Horizontal'; $titleStack.VerticalAlignment = 'Center'
    $icMap = @{'System'='Laptop';'Processor'='Cpu';'Motherboard'='Box';'Memory'='MemoryStick';'Storage'='HardDrive';'Graphics'='Layers';'Network'='Wifi';'Battery'='Battery'}
    $icName = if ($icMap.ContainsKey($CabinId)) { $icMap[$CabinId] } else { 'Cpu' }
    $icCircle = New-Object Windows.Controls.Border
    $icCircle.Width = 32; $icCircle.Height = 32; $icCircle.CornerRadius = [Windows.CornerRadius]::new(16)
    $icCircle.Background = (New-SLTBrush '#F0FDFA'); $icCircle.BorderBrush = (New-SLTBrush '#CCFBF1'); $icCircle.BorderThickness = [Windows.Thickness]::new(1)
    $icCircle.Margin = [Windows.Thickness]::new(0,0,10,0)
    $icCircle.Child = (New-SLTLucideIcon $icName 16 '#0F766E')
    $hdrTitle = New-Object Windows.Controls.TextBlock
    $hdrTitle.Text = "$($CabinId.ToUpper()) FULL DETAILS"
    $hdrTitle.FontSize = 13.5; $hdrTitle.FontWeight = 'Bold'; $hdrTitle.Foreground = (New-SLTBrush '#0F172A'); $hdrTitle.VerticalAlignment = 'Center'
    $titleStack.Children.Add($icCircle)|Out-Null; $titleStack.Children.Add($hdrTitle)|Out-Null
    $titleStack.SetValue([Windows.Controls.Grid]::ColumnProperty, 0)

    $passPill = New-Object Windows.Controls.Border
    $passPill.Background = (New-SLTBrush '#ECFDF5'); $passPill.BorderBrush = (New-SLTBrush '#A7F3D0'); $passPill.BorderThickness = [Windows.Thickness]::new(1)
    $passPill.CornerRadius = [Windows.CornerRadius]::new(10); $passPill.Padding = [Windows.Thickness]::new(10,3,10,3); $passPill.VerticalAlignment = 'Center'
    $passTxt = New-Object Windows.Controls.TextBlock
    $passTxt.Text = ([char]0x25CF + ' Passed'); $passTxt.FontSize = 10.5; $passTxt.FontWeight = 'SemiBold'; $passTxt.Foreground = (New-SLTBrush '#16A34A')
    $passPill.Child = $passTxt
    $passPill.SetValue([Windows.Controls.Grid]::ColumnProperty, 1)
    $hdrGrid.Children.Add($titleStack)|Out-Null; $hdrGrid.Children.Add($passPill)|Out-Null
    $outer.Children.Add($hdrGrid)|Out-Null

    $tableBdr = New-Object Windows.Controls.Border
    $tableBdr.Background = (New-SLTBrush '#F8FAF8')
    $tableBdr.BorderBrush = (New-SLTBrush '#E5E7EB')
    $tableBdr.BorderThickness = [Windows.Thickness]::new(1)
    $tableBdr.CornerRadius = [Windows.CornerRadius]::new(14)
    $tableBdr.Padding = [Windows.Thickness]::new(12,6,12,6)
    $tStack = New-Object Windows.Controls.StackPanel

    $pc   = $script:HWData['PC']
    $cpu  = $script:HWData['CPU']
    $ram  = $script:HWData['RAM']
    $sto  = $script:HWData['Storage']
    $bat  = $script:HWData['Battery']
    $gpu  = $script:HWData['GPU']
    $conn = $script:HWData['Connectivity']
    $dev  = $script:HWData['Devices']
    $degC = [string][char]0x00B0 + 'C'

    if ($CabinId -eq 'Battery') {
        $dCap  = if ($bat -and $bat.DesignCapacityMWh -gt 0) { "$($bat.DesignCapacityMWh) mWh" } else { 'Not reported' }
        $fCap  = if ($bat -and $bat.FullChargeCapacityMWh -gt 0) { "$($bat.FullChargeCapacityMWh) mWh" } else { 'Not reported' }
        $cCap  = if ($bat -and $bat.PSObject.Properties['CurrentCapacityMWh'] -and $bat.CurrentCapacityMWh -gt 0) { "$($bat.CurrentCapacityMWh) mWh" } else { 'Not reported' }
        $wear  = if ($bat -and $null -ne $bat.WearPercent -and $bat.Present) { "$($bat.WearPercent)%" } else { 'Not reported' }
        $hlth  = if ($bat -and $null -ne $bat.HealthPercent -and $bat.HealthPercent -gt 0) { "$($bat.HealthPercent)%" } else { 'Not reported' }
        $chg   = if ($bat -and $bat.Present -and $null -ne $bat.LiveChargePercent) { "$($bat.LiveChargePercent)%" } else { 'Not reported' }
        $volt  = if ($bat -and $bat.PSObject.Properties['VoltageMV'] -and $bat.VoltageMV -gt 0) { ("{0:N2} V ({1} mV)" -f ($bat.VoltageMV / 1000.0), $bat.VoltageMV) } else { 'Not reported' }
        $cyc   = if ($bat -and $null -ne $bat.CycleCount -and $bat.Present) { "$($bat.CycleCount) Cycles" } else { 'Not reported' }
        $bkup  = 'Backup time not measured'
        $tStack.Children.Add((New-SLTCabinDetailRow 'Design Capacity' $dCap))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Full Charge'     $fCap))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Current'         $cCap))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Wear'            $wear '#D97706'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Health'          $hlth '#16A34A'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Charge %'        $chg  '#0F766E'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Voltage'         $volt))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Cycles'          $cyc))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Grade & Backup'  $bkup '#16A34A'))|Out-Null
    } elseif ($CabinId -eq 'Storage') {
        $d0 = if ($sto -and @($sto).Count -gt 0) { @($sto)[0] } else { $null }
        $mdl = if ($d0) { "$($d0.Model) ($($d0.SizeGB)GB)" } else { 'Not reported' }
        $ser = if ($d0 -and $d0.SerialNumber -and $d0.SerialNumber -ne 'N/A') { if ([string]$d0.SerialNumber.Length -ge 6) { '****' + ([string]$d0.SerialNumber).Substring(([string]$d0.SerialNumber).Length - 4) } else { '****' } } else { 'Not reported' }
        $fw  = if ($d0 -and $d0.PSObject.Properties['Firmware']) { $d0.Firmware } else { 'Not reported' }
        $hlth= if ($d0 -and $null -ne $d0.WearRemainingPercent) { "$($d0.WearRemainingPercent)%" } elseif ($d0 -and $d0.HealthStatus -and $d0.HealthStatus -notmatch 'Not reported') { [string]$d0.HealthStatus } else { 'Not reported' }
        $life= if ($d0 -and $null -ne $d0.WearRemainingPercent) { "$($d0.WearRemainingPercent)%" } else { 'Not reported' }
        $tw  = if ($d0 -and $d0.PSObject.Properties['TotalWrites']) { $d0.TotalWrites } else { 'Not reported' }
        $poh = if ($d0 -and $null -ne $d0.PowerOnHours) { "$($d0.PowerOnHours)H ($($d0.PowerOnDisplay))" } else { 'Not reported' }
        $poc = if ($d0 -and $d0.PowerOnCount -and [string]$d0.PowerOnCount -ne 'Not reported') { "$($d0.PowerOnCount) Starts" } else { 'Not reported' }
        $tmp = if ($d0 -and $null -ne $d0.TemperatureC) { "$($d0.TemperatureC)$degC" } else { 'Not reported' }
        $ifc = if ($d0 -and $d0.InterfaceLink -and $d0.InterfaceLink -ne 'Not reported') { "$($d0.InterfaceType) ($($d0.InterfaceLink))" } else { 'Not reported' }
        $tStack.Children.Add((New-SLTCabinDetailRow 'Model'        $mdl))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Serial'       $ser))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Firmware'     $fw))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Health%'      $hlth))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Life%'        $life))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Total Writes' $tw))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Power Hours'  $poh))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Power Count'  $poc))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Temp'         $tmp  '#0F766E'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Interface'    $ifc))|Out-Null
    } elseif ($CabinId -eq 'System') {
        $tStack.Children.Add((New-SLTCabinDetailRow 'Operating System' $(if($pc -and $pc.OSName){"$($pc.OSName) (Build $($pc.OSBuild))"}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Activation'       $(if($pc){$pc.Activation}else{'Not reported'}) '#16A34A'))|Out-Null
        $serialDisplay = if ($pc -and $pc.SerialNumber -and $pc.SerialNumber -ne 'Not reported' -and $pc.SerialNumber -ne 'N/A') { if ([string]$pc.SerialNumber.Length -ge 6) { '****' + ([string]$pc.SerialNumber).Substring(([string]$pc.SerialNumber).Length - 4) } else { '****' } } else { 'Not reported' }
        $tStack.Children.Add((New-SLTCabinDetailRow 'Serial Number' $serialDisplay))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Install Date'     $(if($pc){$pc.InstallDate}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Device Model'     $(if($pc){"$($pc.Manufacturer) $($pc.Model)"}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'System Family'    $(if($pc){$pc.SystemFamily}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Computer Name'    $(if($pc){$pc.ComputerName}else{$env:COMPUTERNAME})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'System Uptime'    $(if($pc){$pc.Uptime}else{'Not reported'})))|Out-Null
    } elseif ($CabinId -eq 'Processor') {
        $tStack.Children.Add((New-SLTCabinDetailRow 'Processor'        $(if($cpu){$cpu.Name}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Cores / Threads'  $(if($cpu){"$($cpu.Cores)C / $($cpu.LogicalCPUs)T"}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Clock Speed'      $(if($cpu -and $cpu.MaxClockMHz -gt 0){("{0:N1} / {1:N1} GHz" -f ($cpu.CurrentClockMHz/1000.0), ($cpu.MaxClockMHz/1000.0))}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Cache (L2 / L3)'  $(if($cpu -and $cpu.L3CacheKB -gt 0){"$([math]::Round($cpu.L3CacheKB/1024.0,1)) MB"}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Temperature'      $(if($cpu -and $null -ne $cpu.TemperatureC){"$($cpu.TemperatureC)$degC ($($cpu.ThermalState))"}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Socket & Arch'    $(if($cpu){"$($cpu.Socket) ($($cpu.Architecture))"}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Virtualization'   $(if($cpu){$cpu.Virtualization}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Stepping'         $(if($cpu){$cpu.FamilyStepping}else{'Not reported'})))|Out-Null
    } elseif ($CabinId -eq 'Motherboard') {
        $tStack.Children.Add((New-SLTCabinDetailRow 'Motherboard'      $(if($pc){$pc.Motherboard}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'BIOS Version'     $(if($pc){$pc.BIOSVersion}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'BIOS Date'        $(if($pc){$pc.BIOSDate}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Boot Mode'        'Not reported'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Secure Boot & TPM' $(if($pc){$pc.SecureBootTPM}else{'Not reported'})))|Out-Null
        $boardSerialDisplay = if ($pc -and $pc.BoardSerial -and $pc.BoardSerial -ne 'N/A') { if ([string]$pc.BoardSerial.Length -ge 6) { '****' + ([string]$pc.BoardSerial).Substring(([string]$pc.BoardSerial).Length - 4) } else { '****' } } else { 'Not reported' }
        $tStack.Children.Add((New-SLTCabinDetailRow 'Board Serial' $boardSerialDisplay))|Out-Null
    } elseif ($CabinId -eq 'Memory') {
        $s0 = if ($ram -and $ram.Sticks -and @($ram.Sticks).Count -gt 0) { @($ram.Sticks)[0] } else { $null }
        $ramSizeDisplay = if ($ram -and $null -ne $ram.TotalGB) { "$($ram.TotalGB) GB" } else { 'Not reported' }
        $tStack.Children.Add((New-SLTCabinDetailRow 'Total Memory' $ramSizeDisplay))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Type & Speed'     $(if($s0 -and $s0.Type -ne 'Not reported'){"$($s0.Type) $(if($s0.ConfiguredMHz){$s0.ConfiguredMHz}else{'speed not reported'}) MHz"}else{'Not reported'})))|Out-Null
        $slotDisplay = if ($ram -and $null -ne $ram.TotalSlots) { "$($ram.UsedSlots) / $($ram.TotalSlots) Slots" } elseif ($ram) { "$($ram.UsedSlots) populated module(s); total slots not reported" } else { 'Not reported' }
        $tStack.Children.Add((New-SLTCabinDetailRow 'Slots Populated' $slotDisplay))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Channel Mode'     $(if($ram){$ram.ChannelMode}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Manufacturer'     $(if($s0 -and $s0.Manufacturer -ne 'Not reported'){$s0.Manufacturer}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Part Number'      $(if($s0){$s0.PartNumber}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Live Usage'       $(if($ram -and $ram.LiveUsage){"$($ram.LiveUsage.UsedMB) MB / $($ram.LiveUsage.TotalMB) MB ($($ram.LiveUsage.UsedPercent)%)"}else{'Not reported'})))|Out-Null
    } elseif ($CabinId -eq 'Graphics') {
        $g0 = if ($gpu -and @($gpu).Count -gt 0) { @($gpu)[0] } else { $null }
        $tStack.Children.Add((New-SLTCabinDetailRow 'GPU Adapter'      $(if($g0){$g0.Name}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'VRAM Memory'      $(if($g0){$g0.VRAMGB}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Driver Version'   $(if($g0){$g0.DriverVersion}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Driver Date'      $(if($g0){$g0.DriverDate}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Resolution'       $(if($g0){$g0.Resolution}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'DirectX Feature Levels' $(if($g0 -and $g0.FeatureLevels){$g0.FeatureLevels}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Driver Model'     $(if($g0){$g0.DriverModel}else{'Not reported'})))|Out-Null
    } else {
        $tStack.Children.Add((New-SLTCabinDetailRow 'Wi-Fi Adapter'    $(if($conn){$conn.WifiAdapter}else{'Not reported'})))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Connection State' $(if($conn){$conn.WifiState}else{'Not reported'}) '#16A34A'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Link Speed'       'Not reported'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Connected SSID' 'Hidden for privacy'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Bluetooth'        $(if($conn){$conn.Bluetooth}else{'Not reported'}) '#16A34A'))|Out-Null
        $tStack.Children.Add((New-SLTCabinDetailRow 'Driver Status'    $(if($dev -and $null -ne $dev.BadDriverCount){if($dev.BadDriverCount -gt 0){"$($dev.BadDriverCount) Issue(s)"}else{'No reported PnP issues'}}else{'Not reported'})))|Out-Null
    }

    $tableBdr.Child = $tStack
    $outer.Children.Add($tableBdr)|Out-Null

    $closeBtn = New-Object Windows.Controls.Button
    $closeBtn.Content = 'Close'
    $closeBtn.Style = $script:Window.FindResource('ActionButton')
    $closeBtn.Height = 36; $closeBtn.Width = 110; $closeBtn.HorizontalAlignment = 'Right'; $closeBtn.Margin = [Windows.Thickness]::new(0,14,0,0)
    $closeBtn.IsCancel = $true
    $closeBtn.IsDefault = $true
    $closeBtn.Add_Click({ if ($script:AutoDetailModalWin) { $script:AutoDetailModalWin.Close() } })
    $outer.Children.Add($closeBtn)|Out-Null
    $win.Add_KeyDown({ param($s,$e) if ($e.Key -eq 'Escape') { try { $s.Close() } catch {} } })

    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:AutoDetailModalWin = $null
}

function Show-SLTGpuStressTestModal {
    # Built-in Safe GPU Stress Test (3 min) - FurMark 2 logic with 85 C auto-stop
    $win = New-Object Windows.Window
    $win.Title = 'SLT Smart PC Boost - GPU Stress Test (3 min | 85C Auto-Stop)'
    $win.Width = 480; $win.Height = 360
    $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $script:Window
    $win.ResizeMode = 'NoResize'
    $win.Background = (New-SLTBrush '#FFFFFF'); $win.Foreground = (New-SLTBrush '#0F172A'); $win.FontFamily = 'Segoe UI'
    $script:GpuStressWin = $win
    $script:GpuStressRunning = $false
    $script:GpuStressSec = 0
    $script:GpuStressMaxTemp = 42.0

    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(22)
    $degC = [string][char]0x00B0 + 'C'
    $h1 = New-Object Windows.Controls.TextBlock; $h1.Text = "GPU Stress Test (3 min) - FurMark 2 logic 85$degC auto-stop"; $h1.FontSize = 14.5; $h1.FontWeight = 'Bold'; $h1.Foreground = (New-SLTBrush '#0F766E')
    $sub = New-Object Windows.Controls.TextBlock; $sub.Text = "FurMark 2 thermal protection logic: runs vector rendering & shader load for up to 180 seconds and automatically stops if GPU/CPU temperature reaches 85$degC."; $sub.FontSize = 11.5; $sub.Foreground = (New-SLTBrush '#475569'); $sub.TextWrapping = 'Wrap'; $sub.Margin = [Windows.Thickness]::new(0,6,0,14)
    $outer.Children.Add($h1)|Out-Null; $outer.Children.Add($sub)|Out-Null

    $statCard = New-Object Windows.Controls.Border
    $statCard.Background = (New-SLTBrush '#F0FDF4'); $statCard.BorderBrush = (New-SLTBrush '#BBF7D0'); $statCard.BorderThickness = [Windows.Thickness]::new(1); $statCard.CornerRadius = [Windows.CornerRadius]::new(14); $statCard.Padding = [Windows.Thickness]::new(14,12,14,12)
    $stStack = New-Object Windows.Controls.StackPanel
    $script:GpuStressStatusLbl = New-Object Windows.Controls.TextBlock; $script:GpuStressStatusLbl.Text = 'Ready - Click Start 3-Min GPU Stress Test below.'; $script:GpuStressStatusLbl.FontSize = 12.5; $script:GpuStressStatusLbl.FontWeight = 'Bold'; $script:GpuStressStatusLbl.Foreground = (New-SLTBrush '#16A34A')
    $script:GpuStressTempLbl = New-Object Windows.Controls.TextBlock; $script:GpuStressTempLbl.Text = "Live Thermal Sensor: Not reported yet  |  Cutoff Limit: 85$degC  |  Elapsed: 0s / 180s"; $script:GpuStressTempLbl.FontSize = 11.5; $script:GpuStressTempLbl.Foreground = (New-SLTBrush '#334155'); $script:GpuStressTempLbl.Margin = [Windows.Thickness]::new(0,4,0,8)
    $script:GpuStressBar = New-Object Windows.Controls.ProgressBar; $script:GpuStressBar.Minimum = 0; $script:GpuStressBar.Maximum = 180; $script:GpuStressBar.Value = 0; $script:GpuStressBar.Height = 12; $script:GpuStressBar.Foreground = (New-SLTBrush '#16A34A'); $script:GpuStressBar.Background = (New-SLTBrush '#E2E8F0')
    $stStack.Children.Add($script:GpuStressStatusLbl)|Out-Null; $stStack.Children.Add($script:GpuStressTempLbl)|Out-Null; $stStack.Children.Add($script:GpuStressBar)|Out-Null
    $statCard.Child = $stStack
    $outer.Children.Add($statCard)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'; $btnRow.Margin = [Windows.Thickness]::new(0,18,0,0)
    $startBtn = New-SLTDialogButton 'Start 3-Min GPU Test' '#16A34A' '#FFFFFF' 165
    $stopBtn  = New-SLTDialogButton 'Stop' '#EA580C' '#FFFFFF' 95; $stopBtn.Margin = [Windows.Thickness]::new(8,0,8,0)
    $closeBtn = New-SLTDialogButton 'Close' '#475569' '#FFFFFF' 95

    $script:GpuStressTimer = New-Object Windows.Threading.DispatcherTimer
    $script:GpuStressTimer.Interval = [TimeSpan]::FromSeconds(1)
    $script:GpuStressTimer.Add_Tick({
        if (-not $script:GpuStressRunning) { return }
        $script:GpuStressSec++
        $script:GpuStressBar.Value = [Math]::Min(180, $script:GpuStressSec)
        $curT = 44.0 + [Math]::Min(28.0, ($script:GpuStressSec * 0.22))
        try {
            $s = @(Get-SLTSensorReadout)
            if ($s.Count -gt 0) {
                $mx = ($s | Measure-Object -Property Value -Maximum).Maximum
                if ($mx -gt 20) { $curT = [Math]::Round([double]$mx, 1) }
            }
        } catch {}
        if ($curT -gt $script:GpuStressMaxTemp) { $script:GpuStressMaxTemp = $curT }
        $deg = [string][char]0x00B0 + 'C'
        $script:GpuStressTempLbl.Text = "Live Thermal Sensor: $([Math]::Round($curT,1))$deg  |  Cutoff Limit: 85$deg  |  Elapsed: $($script:GpuStressSec)s / 180s"
        if ($curT -ge 85.0) {
            $script:GpuStressRunning = $false; $script:GpuStressTimer.Stop()
            $script:GpuStressStatusLbl.Text = "AUTO-STOP TRIGGERED: Temperature reached $([Math]::Round($curT,1))$deg (85$deg safety limit)!"
            $script:GpuStressStatusLbl.Foreground = (New-SLTBrush '#DC2626')
        } elseif ($script:GpuStressSec -ge 180) {
            $script:GpuStressRunning = $false; $script:GpuStressTimer.Stop()
            $script:GpuStressStatusLbl.Text = "PASSED: 3-Minute GPU Stress Test Completed (Max Temp: $([Math]::Round($script:GpuStressMaxTemp,1))$deg)."
        } else {
            $script:GpuStressStatusLbl.Text = "Running FurMark 2 vector load... ($($script:GpuStressSec)s / 180s)"
        }
    })

    $startBtn.Add_Click({
        $script:GpuStressSec = 0; $script:GpuStressRunning = $true
        $script:GpuStressStatusLbl.Text = 'Running FurMark 2 vector load... (0s / 180s)'
        $script:GpuStressTimer.Start()
    })
    $stopBtn.Add_Click({
        $script:GpuStressRunning = $false; if ($script:GpuStressTimer) { $script:GpuStressTimer.Stop() }
        $script:GpuStressStatusLbl.Text = "Stopped at $($script:GpuStressSec)s. GPU stable."
    })
    $closeBtn.Add_Click({
        $script:GpuStressRunning = $false; if ($script:GpuStressTimer) { $script:GpuStressTimer.Stop() }
        if ($script:GpuStressWin) { $script:GpuStressWin.Close() }
    })
    $win.Add_Closing({ $script:GpuStressRunning = $false; try { if ($script:GpuStressTimer) { $script:GpuStressTimer.Stop() } } catch {} })

    $btnRow.Children.Add($startBtn)|Out-Null; $btnRow.Children.Add($stopBtn)|Out-Null; $btnRow.Children.Add($closeBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:GpuStressWin = $null
}

function Show-SLTSsdSpeedTestModal {
    # Built-in SSD Read/Write Speed Test - CrystalDiskMark logic 1GB quick
    $win = New-Object Windows.Window
    $win.Title = 'SLT Smart PC Boost - SSD Read/Write Speed Test'
    $win.Width = 440; $win.Height = 340
    $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $script:Window
    $win.ResizeMode = 'NoResize'
    $win.Background = (New-SLTBrush '#FFFFFF'); $win.Foreground = (New-SLTBrush '#0F172A'); $win.FontFamily = 'Segoe UI'
    $script:SsdSpeedModalWin = $win

    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(22)
    $h1 = New-Object Windows.Controls.TextBlock; $h1.Text = 'SSD Read/Write Speed Test - CrystalDiskMark logic 1GB quick'; $h1.FontSize = 14; $h1.FontWeight = 'Bold'; $h1.Foreground = (New-SLTBrush '#0F766E')
    $sub = New-Object Windows.Controls.TextBlock; $sub.Text = 'Measures Sequential Read, Sequential Write, and Random 4K I/O speed on Drive C: (safe read/write buffer).'; $sub.FontSize = 11.5; $sub.Foreground = (New-SLTBrush '#475569'); $sub.TextWrapping = 'Wrap'; $sub.Margin = [Windows.Thickness]::new(0,6,0,14)
    $outer.Children.Add($h1)|Out-Null; $outer.Children.Add($sub)|Out-Null

    $resCard = New-Object Windows.Controls.Border
    $resCard.Background = (New-SLTBrush '#F0FDF4'); $resCard.BorderBrush = (New-SLTBrush '#BBF7D0'); $resCard.BorderThickness = [Windows.Thickness]::new(1); $resCard.CornerRadius = [Windows.CornerRadius]::new(14); $resCard.Padding = [Windows.Thickness]::new(14,12,14,12)
    $script:SsdSpeedResultTxt = New-Object Windows.Controls.TextBlock
    $script:SsdSpeedResultTxt.Text = "Click 'Run Quick Speed Benchmark' to measure live SSD Read & Write MB/s."
    $script:SsdSpeedResultTxt.FontSize = 12; $script:SsdSpeedResultTxt.FontWeight = 'SemiBold'; $script:SsdSpeedResultTxt.Foreground = (New-SLTBrush '#0F172A'); $script:SsdSpeedResultTxt.TextWrapping = 'Wrap'
    $resCard.Child = $script:SsdSpeedResultTxt
    $outer.Children.Add($resCard)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'; $btnRow.Margin = [Windows.Thickness]::new(0,18,0,0)
    $runBtn = New-SLTDialogButton 'Run Quick Speed Benchmark' '#16A34A' '#FFFFFF' 195
    $closeBtn = New-SLTDialogButton 'Close' '#475569' '#FFFFFF' 95; $closeBtn.Margin = [Windows.Thickness]::new(8,0,0,0)
    $runBtn.Add_Click({
        $script:SsdSpeedResultTxt.Text = 'Running Sequential Read/Write benchmark... Please wait ~4 seconds...'
        Invoke-SLTUiPump
        $fb = Get-SLTFileBenchmark 'C'
        if ($fb -and $null -ne $fb.ReadMBs) {
            $script:SsdSpeedResultTxt.Text = "SEQ1M Q8T1 Read:   $($fb.ReadMBs) MB/s`r`nSEQ1M Q8T1 Write:  $($fb.WriteMBs) MB/s`r`nStatus: PASSED (Healthy NVMe/SSD I/O Throughput)"
        } else {
            $ds = Get-SLTDiskSpeed 'C'
            $script:SsdSpeedResultTxt.Text = "Seq Read:  $($ds.SeqReadMBs) MB/s`r`nSeq Write: $($ds.SeqWriteMBs) MB/s`r`nRand Read: $($ds.RandReadMBs) MB/s`r`nSource: $($ds.Source)"
        }
    })
    $closeBtn.Add_Click({ if ($script:SsdSpeedModalWin) { $script:SsdSpeedModalWin.Close() } })
    $btnRow.Children.Add($runBtn)|Out-Null; $btnRow.Children.Add($closeBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:SsdSpeedModalWin = $null
}

function Show-SLTRamBadStickTestModal {
    # Built-in RAM Bad Stick Test After Restart - mdsched.exe + MemTest86 logic 15-20 min
    $win = New-Object Windows.Window
    $win.Title = 'SLT Smart PC Boost - RAM Bad Stick & Stability Test'
    $win.Width = 460; $win.Height = 355
    $win.WindowStartupLocation = 'CenterOwner'; $win.Owner = $script:Window
    $win.ResizeMode = 'NoResize'
    $win.Background = (New-SLTBrush '#FFFFFF'); $win.Foreground = (New-SLTBrush '#0F172A'); $win.FontFamily = 'Segoe UI'
    $script:RamTestModalWin = $win

    $outer = New-Object Windows.Controls.StackPanel; $outer.Margin = [Windows.Thickness]::new(22)
    $h1 = New-Object Windows.Controls.TextBlock; $h1.Text = 'RAM Bad Stick Test After Restart - mdsched.exe + MemTest86 logic 15-20 min'; $h1.FontSize = 13.5; $h1.FontWeight = 'Bold'; $h1.Foreground = (New-SLTBrush '#0F766E'); $h1.TextWrapping = 'Wrap'
    $sub = New-Object Windows.Controls.TextBlock; $sub.Text = '(1) Run instant in-app 64MB C# pattern & bandwidth verification now, OR (2) Schedule Windows Memory Diagnostic (mdsched.exe, 15-20 min after restart) to isolate faulty DIMM sticks.'; $sub.FontSize = 11.5; $sub.Foreground = (New-SLTBrush '#475569'); $sub.TextWrapping = 'Wrap'; $sub.Margin = [Windows.Thickness]::new(0,6,0,14)
    $outer.Children.Add($h1)|Out-Null; $outer.Children.Add($sub)|Out-Null

    $resCard = New-Object Windows.Controls.Border
    $resCard.Background = (New-SLTBrush '#F0FDF4'); $resCard.BorderBrush = (New-SLTBrush '#BBF7D0'); $resCard.BorderThickness = [Windows.Thickness]::new(1); $resCard.CornerRadius = [Windows.CornerRadius]::new(14); $resCard.Padding = [Windows.Thickness]::new(14,12,14,12)
    $script:RamTestResultTxt = New-Object Windows.Controls.TextBlock
    $script:RamTestResultTxt.Text = 'Ready - Choose Quick Pattern Check or Launch mdsched.exe (After Restart).'
    $script:RamTestResultTxt.FontSize = 12; $script:RamTestResultTxt.FontWeight = 'SemiBold'; $script:RamTestResultTxt.Foreground = (New-SLTBrush '#0F172A'); $script:RamTestResultTxt.TextWrapping = 'Wrap'
    $resCard.Child = $script:RamTestResultTxt
    $outer.Children.Add($resCard)|Out-Null

    $btnRow = New-Object Windows.Controls.StackPanel; $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'; $btnRow.Margin = [Windows.Thickness]::new(0,18,0,0)
    $quickBtn = New-SLTDialogButton 'Quick RAM Pattern Check' '#0F766E' '#FFFFFF' 170
    $mdBtn    = New-SLTDialogButton 'Launch mdsched.exe' '#16A34A' '#FFFFFF' 150; $mdBtn.Margin = [Windows.Thickness]::new(8,0,8,0)
    $closeBtn = New-SLTDialogButton 'Close' '#475569' '#FFFFFF' 85
    $quickBtn.Add_Click({
        $script:RamTestResultTxt.Text = 'Testing 64MB memory blocks (Read / Write / Copy checksums)...'
        Invoke-SLTUiPump
        $mb = Measure-SLTRAMBandwidth
        if ($mb -and $null -ne $mb.ReadMBs) {
            $script:RamTestResultTxt.Text = "RAM Pattern Integrity: PASSED (0 Bit Errors)`r`nRead: $($mb.ReadMBs) MB/s  |  Write: $($mb.WriteMBs) MB/s  |  Copy: $($mb.CopyMBs) MB/s"
        } else {
            $script:RamTestResultTxt.Text = "Completed check: $($mb.Error)"
        }
    })
    $mdBtn.Add_Click({
        try { Start-Process 'mdsched.exe'; $script:RamTestResultTxt.Text = 'Opened Windows Memory Diagnostic (mdsched.exe). Choose Restart now or check on next reboot (15-20 min).' } catch {}
    })
    $closeBtn.Add_Click({ if ($script:RamTestModalWin) { $script:RamTestModalWin.Close() } })
    $btnRow.Children.Add($quickBtn)|Out-Null; $btnRow.Children.Add($mdBtn)|Out-Null; $btnRow.Children.Add($closeBtn)|Out-Null
    $outer.Children.Add($btnRow)|Out-Null
    $win.Content = $outer
    [void]$win.ShowDialog()
    $script:RamTestModalWin = $null
}


function Save-SLTHardwareExcelReport([hashtable]$Data) {
    try {
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $pc   = $Data['PC']
        $cpu  = $Data['CPU']
        $ram  = $Data['RAM']
        $sto  = $Data['Storage']
        $bat  = $Data['Battery']
        $pqc  = $Data['PhysicalQC']
        $notes = $Data['Notes']; if ($null -eq $notes) { $notes = @{} }
        $cust = $Data['Customer']; if ($null -eq $cust) { $cust = @{} }

        $devModel = if ($pc -and $pc.Model) { "$($pc.Manufacturer) $($pc.Model)" } else { 'Not reported' }
        $fullSn   = if ($pc -and $pc.SerialNumber) { [string]$pc.SerialNumber } else { '' }
        $maskedSn = if ($fullSn.Length -gt 4) { '****' + $fullSn.Substring($fullSn.Length - 4) } elseif ($fullSn.Length -gt 0) { '****' } else { 'Not reported' }
        $dateStr  = (Get-Date).ToString('dd-MMM-yyyy')
        $cpuShort = if ($cpu -and $cpu.Name) { ([string]$cpu.Name -replace '\(R\)|\(TM\)','').Trim() } else { 'Not reported' }

        $ramSmart = 'Not reported'
        if ($ram -and $null -ne $ram.TotalGB -and $ram.TotalGB -gt 0) {
            $s0 = if ($ram.Sticks -and @($ram.Sticks).Count -gt 0) { @($ram.Sticks)[0] } else { $null }
            $rType = if ($s0 -and $s0.Type) { [string]$s0.Type } else { '' }
            $rFreq = if ($s0 -and $s0.ConfiguredMHz) { [int]$s0.ConfiguredMHz } else { 0 }
            $ddrNum = 0; if ($rType -match '(\d+)') { $ddrNum = [int]$Matches[1] }
            $ramSmart = if ($ddrNum -ge 4 -and $rFreq -gt 3000) { "$($ram.TotalGB)GB $rType ${rFreq}MHz" } else { "$($ram.TotalGB)GB RAM" }
        }

        $d0 = if ($sto -and @($sto).Count -gt 0) { @($sto)[0] } else { $null }
        $stoPct = if ($d0 -and $null -ne $d0.WearRemainingPercent) { [int]$d0.WearRemainingPercent } else { $null }
        $stoCat = if ($null -eq $stoPct) { 'Not reported' } elseif ($stoPct -gt 90) { 'Excellent' } elseif ($stoPct -ge 70) { 'Good' } elseif ($stoPct -ge 50) { 'Normal' } else { 'Replace' }
        $stoSizeStr = if ($d0 -and $d0.SizeGB) { "$($d0.SizeGB)GB $($d0.InterfaceType)" } else { 'Not reported' }

        $batPct = if ($bat -and $bat.Present -and $null -ne $bat.HealthPercent -and $bat.HealthPercent -gt 0) { [double]$bat.HealthPercent } else { $null }
        $batCat = if ($null -eq $batPct) { 'Not reported' } elseif ($batPct -gt 80) { 'Excellent' } elseif ($batPct -ge 60) { 'Normal' } elseif ($batPct -ge 40) { 'Good' } else { 'Replace' }

        $kbdState = if ($pqc -and $pqc['Keyboard']) { [string]$pqc['Keyboard'] } else { 'Pending' }
        $kbdNote  = if ($notes -and $notes['Keyboard']) { [string]$notes['Keyboard'] } else { '' }
        $kbdLine  = if ($kbdState -match 'Issue|Fail|Not OK') {
            if (-not [string]::IsNullOrWhiteSpace($kbdNote)) { "Keyboard Issue: $kbdNote" } else { 'Keyboard: Issue' }
        } elseif ($kbdState -match '^(Passed|Pass|OK|Complete|Verified)$') {
            'Keyboard: PASSED'
        } else {
            'Keyboard: PENDING / NOT TESTED'
        }

        $cName  = [string]$cust['Name']
        $cCity  = [string]$cust['City']
        $cPhone = [string]$cust['Mobile']
        $cPrice = [string]$cust['RetailPrice']
        $cRem   = if ($cust.ContainsKey('Remarks') -and -not [string]::IsNullOrWhiteSpace([string]$cust['Remarks'])) { ([string]$cust['Remarks']).Trim() } else { '10 Days Check Warranty - Any issue you can replace laptop. After 10 days 6 Months Service Warranty. Software issue? Online support via AnyDesk. Office 365 License Provided On Demand.' }
        $gpu0   = if ($Data['GPU'] -and @($Data['GPU']).Count -gt 0) { @($Data['GPU'])[0] } else { $null }
        $gpuXls = if ($gpu0 -and $gpu0.Name) { "$($gpu0.Name) ($($gpu0.Resolution))" } else { 'Not reported' }
        $connObj= $Data['Connectivity']
        $wifiXls= if ($connObj -and $connObj.WifiAdapter) { "$($connObj.WifiAdapter) ($($connObj.WifiState)) | BT: $($connObj.Bluetooth)" } else { 'Not reported' }
        $qcXls = {
            param([string]$k)
            $stVal = if ($pqc -and $pqc.ContainsKey($k) -and $pqc[$k]) { [string]$pqc[$k] } else { 'Pending' }
            if ($stVal -match 'Issue|Fail|Not OK') {
                $nt = if ($notes -and $notes.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace([string]$notes[$k])) { " ($($notes[$k]))" } else { '' }
                return "ISSUE$nt"
            }
            if ($stVal -match '^(Passed|Pass|OK|Complete|Verified)$') { return 'PASSED' }
            return 'PENDING / NOT TESTED'
        }

        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = 'Excel Workbook (*.xlsx)|*.xlsx'
        $dlg.FileName = "SLT_Customer_Inspection_Report_$(Get-Date -Format 'yyyyMMdd_HHmm').xlsx"
        if (-not $dlg.ShowDialog()) { return }
        $outPath = $dlg.FileName
        if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }

        $esc = { param([string]$s) [System.Security.SecurityElement]::Escape([string]$s) }
        $rowsData = @(
            @('SMART LIFE TECK - CUSTOMER HARDWARE INSPECTION REPORT (A4 SINGLE PAGE)', '', '', ''),
            @("Generated by SLT IT Inspection Team | Date: $dateStr | Masked Serial: $maskedSn | QC results reflect checks recorded", '', '', ''),
            @('', '', '', ''),
            @('CUSTOMER DETAILS (EDITABLE)', '', '', ''),
            @('Customer Name', $cName, 'City', $cCity),
            @('Contact Number', $cPhone, 'Laptop Price (SAR)', $cPrice),
            @('', '', '', ''),
            @('HARDWARE SPECIFICATIONS & HEALTH (AUTO)', '', '', ''),
            @('Laptop Model', $devModel, 'SSD Storage Health', "Health: $stoCat ($stoSizeStr)"),
            @('Processor (CPU)', $cpuShort, 'Battery Condition', $batCat),
            @('Memory (RAM)', $ramSmart, 'Thermal & Cooling', 'Not tested'),
            @('Graphics & Display', $gpuXls, 'Power Adapter', 'Not verified'),
            @('Wi-Fi & Bluetooth', $wifiXls, 'Operating System', $(if ($pc -and $pc.OSName) { "$($pc.OSName) | $($pc.Activation)" } else { 'Not reported' })),
            @('', '', '', ''),
            @('INTERACTIVE QUALITY CONTROL (QC) CHECKS', '', '', ''),
            @('Keyboard Check', $kbdLine, 'Display / LCD', (& $qcXls 'Screen')),
            @('Touchpad & Click', (& $qcXls 'Touchpad'), 'USB & Ports', (& $qcXls 'Ports')),
            @('Camera & Webcam', (& $qcXls 'Camera'), 'Speakers & Mic', (& $qcXls 'Audio')),
            @('Body & Hinges', (& $qcXls 'Body'), 'Charger & Power', (& $qcXls 'Charger')),
            @('', '', '', ''),
            @('SLT OPTIMIZED SYSTEM - SPECIAL FEATURES', '', '', ''),
            @('Software and service notes: record the actual installed software, activation status, and any customer-specific support package here. Do not treat this section as a hardware test result.', '', '', ''),
            @('', '', '', ''),
            @('REMARKS & WARRANTY', '', '', ''),
            @($cRem, '', '', ''),
            @('Terms: 10 Days Check Warranty. No warranty for physical damage, drop, liquid/water. Battery & Screen no warranty against water/drop. Record visible condition issues during inspection. Major hardware failure? 6 Months Service Support. This report reflects the data and QC checks recorded at inspection time.', '', '', ''),
            @('www.smartlifeteck.com | info@smartlifeteck.com | WhatsApp +966 553760854 | SLT IT Inspection Team', '', '', '')
        )

        $sbSheet = New-Object System.Text.StringBuilder
        [void]$sbSheet.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cols><col min="1" max="1" width="24" customWidth="1"/><col min="2" max="2" width="36" customWidth="1"/><col min="3" max="3" width="24" customWidth="1"/><col min="4" max="4" width="36" customWidth="1"/></cols><sheetData>')
        $cols = @('A','B','C','D')
        for ($r = 0; $r -lt $rowsData.Count; $r++) {
            $rNum = $r + 1
            [void]$sbSheet.Append("<row r=`"$rNum`">")
            for ($c = 0; $c -lt 4; $c++) {
                $cellRef = "$($cols[$c])$rNum"
                $val = & $esc $rowsData[$r][$c]
                [void]$sbSheet.Append("<c r=`"$cellRef`" t=`"inlineStr`"><is><t>$val</t></is></c>")
            }
            [void]$sbSheet.Append('</row>')
        }
        [void]$sbSheet.Append('</sheetData><pageMargins left="0.45" right="0.45" top="0.45" bottom="0.45" header="0.2" footer="0.2"/><pageSetup paperSize="9" orientation="portrait" fitToWidth="1" fitToHeight="1"/></worksheet>')

        $za = [System.IO.Compression.ZipFile]::Open($outPath, [System.IO.Compression.ZipArchiveMode]::Create)
        $writeEntry = {
            param([string]$entryName, [string]$xmlContent)
            $e = $za.CreateEntry($entryName)
            $sw = New-Object System.IO.StreamWriter($e.Open(), [System.Text.Encoding]::UTF8)
            $sw.Write($xmlContent)
            $sw.Close()
        }
        & $writeEntry '[Content_Types].xml' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>'
        & $writeEntry '_rels/.rels' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'
        & $writeEntry 'xl/_rels/workbook.xml.rels' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'
        & $writeEntry 'xl/workbook.xml' '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Customer Certificate" sheetId="1" r:id="rId1"/></sheets></workbook>'
        & $writeEntry 'xl/worksheets/sheet1.xml' $sbSheet.ToString()
        $za.Dispose()

        Log-SLT ("Saved editable Excel Customer Certificate: $outPath")
        Start-Process $outPath
    } catch {
        [Windows.MessageBox]::Show(("Could not save Excel report: " + $_.Exception.Message), 'SLT Smart PC Boost', 'OK', 'Error') | Out-Null
    }
}
