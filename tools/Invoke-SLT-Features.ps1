param([Parameter(Mandatory=$true)][string]$Manifest)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$allowed=Get-Content -LiteralPath (Join-Path $root 'data\feature.json') -Raw|ConvertFrom-Json
$names=@(foreach($entry in $allowed.PSObject.Properties){if($entry.Value.PSObject.Properties['feature'] -and -not($null -ne $entry.Value.PSObject.Properties['InvokeScript'] -and @($entry.Value.InvokeScript).Count -gt 0)){foreach($name in @($entry.Value.feature)){[string]$name}}})
$requested=Get-Content -LiteralPath $Manifest -Raw|ConvertFrom-Json
$log=Join-Path (Split-Path -Parent $Manifest) ('FeatureResults_'+(Get-Date -Format yyyyMMdd_HHmmss)+'.txt')
try {
 foreach($feature in @($requested.features)){
  if($feature -notin $names -or $feature -notmatch '^[A-Za-z0-9.\-]+$') {throw "Unsupported feature: $feature"}
  Write-Host "Checking: $feature" -ForegroundColor Cyan
  $status=Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction Stop
  if($status.State -eq 'Enabled'){"Already enabled: $feature"|Tee-Object -FilePath $log -Append;continue}
  Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop|Out-Null
  "Enabled: $feature"|Tee-Object -FilePath $log -Append
 }
 Write-Host "Completed. Some features require restart. Log: $log" -ForegroundColor Green
} catch {$_|Out-String|Add-Content -LiteralPath $log;Write-Host $_.Exception.Message -ForegroundColor Red}
Write-Host 'Press Enter to close...';[void][Console]::ReadLine()
