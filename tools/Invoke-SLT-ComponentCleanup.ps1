$ErrorActionPreference='Stop'
$path=Join-Path $env:ProgramData ('SmartLifeTeck\PCCarePro\Logs\DISM_'+(Get-Date -Format yyyyMMdd_HHmmss)+'.txt')
try {
 Write-Host 'DISM StartComponentCleanup. Do not interrupt. No ResetBase.' -ForegroundColor Cyan
 & "$env:WINDIR\System32\dism.exe" /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Tee-Object -FilePath $path
 $code=$LASTEXITCODE
 "DISM EXIT CODE: $code" | Tee-Object -FilePath $path -Append
 if($code -ne 0){Write-Host 'DISM did not finish successfully. Check log.' -ForegroundColor Red}
 else{Write-Host 'DISM complete. Exit code 0.' -ForegroundColor Green}
} catch {$_ | Out-String | Add-Content -LiteralPath $path;Write-Host $_.Exception.Message -ForegroundColor Red}
Write-Host 'Press Enter to close...';[void][Console]::ReadLine()
