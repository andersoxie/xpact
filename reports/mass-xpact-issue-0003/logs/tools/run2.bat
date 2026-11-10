@echo off
rem run2.bat: trace-probe.exe (default handler only, whole document) on ibm68n03.xml with the assertions DLL relinked with a map (mass-xpact #3).
set PATH=%~dp0..\asrt-map2;%PATH%
set XPACT_CRASH_DIR=%~dp0out2
if not exist "%~dp0out2" mkdir "%~dp0out2"
"%~dp0trace-probe.exe" default 100000 < "C:\xpact\xpact-student-Mass\build\mass-xpact-0002-tools\one.txt" > "%~dp0out2\trace.txt" 2>&1
echo exit=%ERRORLEVEL%
