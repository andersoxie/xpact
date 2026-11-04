@echo off
rem ct.bat <dll dir> <file> <chunk> <repeat>: chunk_time.exe with that DLL first on PATH.
set PATH=%~1;%PATH%
"C:\xpact\xpact-student-Mass\build\mass-xpact-0002-tools\chunk_time.exe" "%~2" %3 %4
