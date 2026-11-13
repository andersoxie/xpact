# build.ps1: Expat 2.8.1's xmlwf twice: with Expat compiled in (xmlwf-expat.exe) and against xpact.lib (xmlwf-xpact.exe).
param([string] $Expat, [string] $XpactLib)
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
$src = "`"$Expat\xmlwf\xmlwf.c`" `"$Expat\xmlwf\xmlfile.c`" `"$Expat\xmlwf\codepage.c`" `"$Expat\xmlwf\readfilemap.c`""
$lib = "`"$Expat\lib\xmlparse.c`" `"$Expat\lib\xmlrole.c`" `"$Expat\lib\xmltok.c`" `"$Expat\lib\random_rand_s.c`""
cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul && cd /d `"$PSScriptRoot`" && cl /nologo /O2 /DXML_STATIC /D_CRT_RAND_S /DHAVE_EXPAT_CONFIG_H /D_CRT_SECURE_NO_WARNINGS /I cfg /I `"$Expat\lib`" $src $lib advapi32.lib /Fe:xmlwf-expat.exe >build-expat.log && cl /nologo /O2 /DHAVE_EXPAT_CONFIG_H /D_CRT_SECURE_NO_WARNINGS /I cfg /IC:\xpact\xpact-student-Mass\include /I `"$Expat\lib`" $src `"$XpactLib`" /Fe:xmlwf-xpact.exe >build-xpact.log"
