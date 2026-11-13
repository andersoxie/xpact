param([string] $Src)
$E = "C:\Users\masou\AppData\Local\Temp\claude\c--xpact-xpact-student-Mass\a1df27f3-4bcf-4e06-b574-128daf781d5b\scratchpad\expat-src\expat-2.8.1\lib"
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
$b = [IO.Path]::GetFileNameWithoutExtension($Src)
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && cd /d `"$PSScriptRoot`" && cl /nologo /O2 /DUSE_EXPAT /DXML_STATIC /D_CRT_RAND_S /DHAVE_EXPAT_CONFIG_H /I cfg /I `"$E`" $Src `"$E\xmlparse.c`" `"$E\xmlrole.c`" `"$E\xmltok.c`" `"$E\random_rand_s.c`" advapi32.lib /Fe:$b-expat.exe >nul && cl /nologo /O2 /IC:\xpact\xpact-student-Mass\include $Src C:\xpact\xpact-student-Mass\build\fix64\native-eiffel\xpact.lib /Fe:$b-xpact.exe >nul"
