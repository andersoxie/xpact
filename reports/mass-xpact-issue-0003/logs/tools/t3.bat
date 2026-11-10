@echo off
rem t3.bat <dll dir> <out file>: trace.exe (default handler only, whole document) on ibm68n03.xml with that DLL (mass-xpact #3).
set PATH=%~1;%PATH%
"C:\xpact\xpact-student-Mass\build\mass-xpact-0002-tools\trace.exe" default 100000 < "C:\xpact\xpact-student-Mass\build\mass-xpact-0002-tools\one.txt" > "%~2" 2>&1
echo exit=%ERRORLEVEL%
