$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && dumpbin /nologo /disasm `"$PSScriptRoot\nokeep-map\xpact.dll`" > `"$PSScriptRoot\nokeep-map\disasm.txt`""
