# Test 6: Expat 2.8.1's own C unit tests (runtests) against xpact.dll, the way the Jenkins
# "libexpat Adapter" stage does it with RUN_LIBEXPAT_NATIVE_SUITE (Manifest, then NativeSuite).
# Output goes to this folder's logs\, not into the repository's build folder.
param(
	[string] $Repo = "C:\Users\masou\Desktop\Lia\xpact\w9-latest",
	[string] $ExpatSource = "C:\Users\masou\Desktop\Lia\xpact\xpactGit\build\libexpat-R_2_8_1\libexpat-R_2_8_1\expat",
	[string] $Library = "build\native-eiffel\xpact.lib",
	[string] $Tag = "xpact"
)
$Out = Join-Path $PSScriptRoot "logs\$Tag"
New-Item -ItemType Directory -Force $Out | Out-Null
$env:Path = "C:\Program Files (x86)\Microsoft Visual Studio\Installer;C:\Program Files\CMake\bin;$env:Path"
Set-Location $Repo
. .\scripts\import_msvc_environment.ps1 | Out-Null
$ErrorActionPreference = "Continue"
foreach ($Mode in "Manifest", "NativeSuite") {
	"=== $Mode ===" | Out-Host
	& powershell -ExecutionPolicy Bypass -File .\scripts\run_libexpat_adapter.ps1 -Mode $Mode -ExpatSourceDir $ExpatSource `
		-OutputDir $Out -XpactLibrary $Library -SkipNativeBuild 2>&1 | Out-Host
	"exit code ($Mode): $LASTEXITCODE" | Out-Host
}
