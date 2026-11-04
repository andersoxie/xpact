@echo off
rem tr.bat <dll dir> <list file> <chunk> <out>: trace.exe (events handler set) on the listed files with that DLL.
set PATH=%~1;%PATH%
"C:\xpact\xpact-student-Mass\build\mass-xpact-0002-tools\trace.exe" events %3 < "%~2" > "%~4" 2>&1
