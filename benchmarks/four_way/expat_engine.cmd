@echo off
python "%~dp0expat_conformance_engine.py" %*
exit /b %ERRORLEVEL%
