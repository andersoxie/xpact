# bsharp SonarQube scan with C# (SonarScanner for .NET), C# coverage and Python coverage.
#
#   powershell -File reports\security-scan-2026-11-14\sonar-net.ps1 [-Python <python.exe with coverage.py>]
#
# Needs: dotnet tool install -g dotnet-sonarscanner; the DPAPI token in %USERPROFILE%\.sonar-token.
# Python coverage needs coverage.py (pip install coverage) in the chosen Python; without it the scan
# still runs, but SonarQube then counts every Python line as uncovered (the quality gate fails).
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path "$PSScriptRoot\..\..")
$s = ConvertTo-SecureString (Get-Content "$env:USERPROFILE\.sonar-token")
$env:SONAR_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
$cov = "$env:TEMP\xpact-cov"; Remove-Item -Recurse -Force $cov -ErrorAction SilentlyContinue
$pyCov = Join-Path $cov "coverage-python.xml"
New-Item -ItemType Directory -Force $cov | Out-Null

# 1. Python suite under coverage.py (before the scanner starts, so a failure is visible early).
& $Python -m coverage --version *> $null
if ($LASTEXITCODE -eq 0) {
  & $Python -m coverage run --branch --data-file "$cov\.coverage" --source=scripts,benchmarks,tools,website/scripts -m unittest discover -s tests/python -p "test_*.py"
  "PYTHON TESTS EXIT $LASTEXITCODE"
  & $Python -m coverage xml --data-file "$cov\.coverage" -o $pyCov
} else {
  Write-Warning "coverage.py not found for '$Python': Python coverage is not sent."
}

Rename-Item sonar-project.properties sonar-project.properties.off
try {
  $ex = "EIFGENs/**,build/**,dist/**,.tmp/**,coverage/**,tests/**,**/*.obj,exception_trace.log,reports/**,student/results/**,**/node_modules/**,website/dist/**,examples/contributed/**/project.py,**/bin/**,**/obj/**"
  # Not measured for coverage: test code itself, and Xpact.Worker. The 48 API tests run the worker
  # end to end, but in its own Low-integrity process, where the coverage collector cannot write (#370).
  $covEx = "website/backend/tests/**,**/test_*.py,website/backend/src/Xpact.Worker/**"
  dotnet-sonarscanner begin /k:xpact /d:sonar.host.url=https://sonarqube.bsharp.se /d:sonar.token=$env:SONAR_TOKEN "/d:sonar.exclusions=$ex" "/d:sonar.coverage.exclusions=$covEx" "/d:sonar.cs.opencover.reportsPaths=$cov/**/coverage.opencover.xml" "/d:sonar.python.coverage.reportPaths=$pyCov" /d:sonar.scanner.scanAll=true /d:sonar.sourceEncoding=UTF-8
  if ($LASTEXITCODE) { throw "begin $LASTEXITCODE" }
  dotnet build website\backend\Xpact.Web.slnx -c Release --no-incremental
  if ($LASTEXITCODE) { throw "build $LASTEXITCODE" }
  dotnet test website\backend\Xpact.Web.slnx -c Release --no-build --collect:"XPlat Code Coverage" --settings website\backend\coverage.runsettings --results-directory $cov
  "TEST EXIT $LASTEXITCODE"
  dotnet-sonarscanner end /d:sonar.token=$env:SONAR_TOKEN
  "END EXIT $LASTEXITCODE"
} finally { Rename-Item sonar-project.properties.off sonar-project.properties }
