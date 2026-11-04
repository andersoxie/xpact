$ErrorActionPreference = "Stop"
$Repo = "C:\xpact\xpact-student-Mass"
$Out = "C:\Users\masou\AppData\Local\Temp\claude\c--xpact-xpact-student-Mass\a1df27f3-4bcf-4e06-b574-128daf781d5b\scratchpad\dbg"
$F = "$Repo\EIFGENs\xpact_native_library\F_code"
$lines = Get-Content "$F\xpact_native_library.dll.lnk"
$lines[0] = "-DLL -NOLOGO -NODEFAULTLIB:libc -OUT:`"$Out\xpact.dll`" -IMPLIB:`"$Out\xpact.lib`" -MAP:`"$Out\xpact.map`" -DEBUG -INCREMENTAL:NO -OPT:REF -OPT:ICF -PDB:`"$Out\xpact.pdb`""
Set-Content -Path "$Out\dbg.lnk" -Value $lines
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
$vc = "$vs\VC\Auxiliary\Build\vcvars64.bat"
cmd.exe /c "`"$vc`" >nul && cd /d `"$F`" && link @`"$Out\dbg.lnk`" && cd /d `"$Out`" && cl /nologo /O2 minidbg.c dbghelp.lib /Fe:minidbg.exe"
