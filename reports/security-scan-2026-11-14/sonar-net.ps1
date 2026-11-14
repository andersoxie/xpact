$ErrorActionPreference = "Stop"
Set-Location C:\xpact\xpact-student-Mass
$s = ConvertTo-SecureString (Get-Content "$env:USERPROFILE\.sonar-token")
$env:SONAR_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
$cov = "$env:TEMP\xpact-cov"; Remove-Item -Recurse -Force $cov -ErrorAction SilentlyContinue
Rename-Item sonar-project.properties sonar-project.properties.off
try {
  $ex = "EIFGENs/**,build/**,dist/**,.tmp/**,coverage/**,tests/**,**/*.obj,exception_trace.log,reports/**,student/results/**,**/node_modules/**,website/dist/**,examples/contributed/**/project.py,**/bin/**,**/obj/**"
  dotnet-sonarscanner begin /k:xpact /d:sonar.host.url=https://sonarqube.bsharp.se /d:sonar.token=$env:SONAR_TOKEN "/d:sonar.exclusions=$ex" "/d:sonar.cs.opencover.reportsPaths=$cov/**/coverage.opencover.xml" /d:sonar.scanner.scanAll=true /d:sonar.sourceEncoding=UTF-8
  if ($LASTEXITCODE) { throw "begin $LASTEXITCODE" }
  dotnet build website\backend\Xpact.Web.slnx -c Release --no-incremental
  if ($LASTEXITCODE) { throw "build $LASTEXITCODE" }
  dotnet test website\backend\Xpact.Web.slnx -c Release --no-build --collect:"XPlat Code Coverage" --settings "$PSScriptRoot\cov.runsettings" --results-directory $cov
  "TEST EXIT $LASTEXITCODE"
  dotnet-sonarscanner end /d:sonar.token=$env:SONAR_TOKEN
  "END EXIT $LASTEXITCODE"
} finally { Rename-Item sonar-project.properties.off sonar-project.properties }
