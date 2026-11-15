# SonarQube scan of xpact on sonarqube.bsharp.se: forwards to the .NET scan script.
#
#   powershell -File student\tools\sonar\run-sonar.ps1 [-Python <python.exe with coverage.py>]
#
# The old version of this script ran the plain SonarScanner CLI. That scanner skips C# and sends no
# coverage, so one run erased the C# results and turned the quality gate red (#371, #397). It also
# asked for the token every time and had a scanner path from an old PC. The current scan:
#   reports\security-scan-2026-11-14\sonar-net.ps1  (C# + Python coverage, token from %USERPROFILE%\.sonar-token)
param([string] $Python = "python")
$Script = Join-Path $PSScriptRoot "..\..\..\reports\security-scan-2026-11-14\sonar-net.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -Python $Python
exit $LASTEXITCODE
