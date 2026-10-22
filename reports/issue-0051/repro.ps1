# Loads MSVC the way the build scripts do, with output captured (as when a
# caller redirects it), in a session without MSVC or the VS Installer on PATH.
$env:Path = (($env:Path -split ";") | Where-Object { $_ -notlike "*Microsoft Visual Studio\Installer*" }) -join ";"
Remove-Item Env:VSCMD_VER -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"
& { . (Join-Path $PSScriptRoot "..\..\scripts\import_msvc_environment.ps1") } *>&1 | ForEach-Object { "$_" }
"cl.exe: $((Get-Command cl.exe -ErrorAction SilentlyContinue).Source)"
