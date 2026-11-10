# Local SonarQube scan of xpact (issue #131). The token is asked for here and never saved.
#   powershell -ExecutionPolicy Bypass -File student\tools\sonar\run-sonar.ps1 -Scanner <path to sonar-scanner.bat>
# SonarScanner CLI (Windows x64 zip, e.g. 7.0.2.4839) comes from binaries.sonarsource.com; it is not in the repo.
param([string] $Scanner = "C:\Users\masou\Desktop\Lia\tools\sonar\sonar-scanner-7.0.2.4839-windows-x64\bin\sonar-scanner.bat",
      [string] $Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path,
      [string] $Server = "https://sonarqube.bsharp.se")
if (-not (Test-Path $Scanner)) { Write-Host "SonarScanner not found: $Scanner" -ForegroundColor Red; exit 2 }
$Secure = Read-Host "SonarQube token (input hidden)" -AsSecureString
$env:SONAR_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure))
Write-Host "1/2 Token check against $Server ..."
try {
  $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($env:SONAR_TOKEN):"))
  $r = Invoke-RestMethod "$Server/api/authentication/validate" -Headers @{Authorization = "Basic $auth"}
  Write-Host "   token valid: $($r.valid)"
} catch { Write-Host "   token check failed: $($_.Exception.Message)" -ForegroundColor Red }
$Log = Join-Path $env:TEMP "sonar-run.log"
Write-Host "2/2 Scan (log: $Log) ..."
Push-Location $Repo
& $Scanner "-Dsonar.host.url=$Server" "-Dproject.settings=sonar-project.properties" *> $Log
$code = $LASTEXITCODE
Pop-Location
Remove-Item Env:SONAR_TOKEN
Get-Content $Log | Select-String "EXECUTION SUCCESS|EXECUTION FAILURE|ERROR|ANALYSIS SUCCESSFUL|dashboard" | Select-Object -First 10
Write-Host "Exit code: $code"
