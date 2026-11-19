# Set up the Gobo Eiffel environment in the current PowerShell session (dot-source it):
#   . .\reports\gobo-2026-11-16\gobo-env.ps1 [-CC msc|zig] [-Gobo <folder with bin\gec.exe>]
# GOBO       - the Gobo folder (default: %USERPROFILE%\tools\gobo-26.11.14\gobo)
# GOBO_CC    - C compiler for gec: "msc" (Visual Studio, same as EiffelStudio uses) or "zig" (bundled clang)
# PATH       - gec first; for msc also the Visual Studio x64 tools (vcvars64)
# GC tuning that worked best in the thread test (Boehm GC): GC_FREE_SPACE_DIVISOR=1, GC_MARKERS=8 (set by -TunedGc).
param([ValidateSet("msc", "zig")] [string] $CC = "msc", [string] $Gobo = "$env:USERPROFILE\tools\gobo-26.11.14\gobo", [switch] $TunedGc)
$Repo = (Resolve-Path "$PSScriptRoot\..\..").Path
if (-not (Test-Path (Join-Path $Gobo "bin\gec.exe"))) { throw "gec.exe not found under $Gobo" }
$env:GOBO = $Gobo
$env:GOBO_CC = $CC
if ($env:PATH -notlike "*$Gobo\bin*") { $env:PATH = "$Gobo\bin;$env:PATH" }
if ($CC -eq "msc" -and -not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
	. (Join-Path $Repo "scripts\import_msvc_environment.ps1") | Out-Null
}
if ($TunedGc) { $env:GC_FREE_SPACE_DIVISOR = "1"; $env:GC_MARKERS = "8" }
"GOBO=$env:GOBO  GOBO_CC=$env:GOBO_CC  gec: $((& gec --version) -join ' ')  cl: $(if (Get-Command cl.exe -ErrorAction SilentlyContinue) { 'yes' } else { 'no' })"
