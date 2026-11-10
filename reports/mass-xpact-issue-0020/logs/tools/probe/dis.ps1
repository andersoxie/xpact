$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && dumpbin /nologo /disasm /range:0x180007CF0,0x180007D80 `"$PSScriptRoot\..\dbg\xpact.dll`""
