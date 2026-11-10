# relink-map.ps1 <out dir>: relink EIFGENs\xpact_native_library\F_code into <out>\xpact.dll with a link map and PDB,
# and save the F_code C-name -> {CLASS}.feature table next to it (mass-xpact #20).
param([Parameter(Mandatory)] [string] $Out)
$ErrorActionPreference = "Stop"
$Repo = "C:\xpact\xpact-student-Mass"
$F = "$Repo\EIFGENs\xpact_native_library\F_code"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$lines = Get-Content "$F\xpact_native_library.dll.lnk"
$lines[0] = "-DLL -NOLOGO -NODEFAULTLIB:libc -OUT:`"$Out\xpact.dll`" -IMPLIB:`"$Out\xpact.lib`" -MAP:`"$Out\xpact.map`" -DEBUG -INCREMENTAL:NO -OPT:REF -OPT:ICF -PDB:`"$Out\xpact.pdb`""
Set-Content -Path "$Out\map.lnk" -Value $lines
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && cd /d `"$F`" && link @`"$Out\map.lnk`""
if ($LASTEXITCODE -ne 0) { throw "link failed: $LASTEXITCODE" }
