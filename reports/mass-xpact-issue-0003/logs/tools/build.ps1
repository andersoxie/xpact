# build.ps1: trace.exe (reports\mass-xpact-issue-0002\tools\trace.c) linked with exprobe.c, which logs every exception with its stack (mass-xpact #3).
$R = "C:\xpact\xpact-student-Mass"
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && cd /d `"$PSScriptRoot`" && cl /nologo /O2 /I`"$R\include`" `"$R\reports\mass-xpact-issue-0002\tools\trace.c`" exprobe.c `"$R\build\sm-8ccf51b\native-eiffel\xpact.lib`" dbghelp.lib /Fe:trace-probe.exe"
