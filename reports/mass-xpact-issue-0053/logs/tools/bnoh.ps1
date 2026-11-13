$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && cd /d `"$PSScriptRoot`" && cl /nologo /O2 /IC:\xpact\xpact-student-Mass\include nohprobe.c C:\xpact\xpact-student-Mass\build\fix51\native-eiffel\xpact.lib /Fe:nohprobe.exe"
