# Build xpact.dll with Gobo Eiffel (gec) and Microsoft's C compiler, next to the EiffelStudio build.
#   powershell -File reports\gobo-dll\build_gobo_dll.ps1 [-OutputDir build\gobo-dll\out] [-CC msc|zig]
# 1. gec --finalize --cc=no: Eiffel -> C (xpact_native_library_gobo.ecf: same root and sources as the
#    EiffelStudio DLL target, Gobo's free_elks).
# 2. cl: the generated C with Gobo's own flags and -Dmain=xp_gobo_main (start-up is called from DllMain),
#    plus native\xpact_native.c, native\xpact_eiffel_runtime_bridge.c (unchanged, against Gobo's eif_*.h
#    compatibility headers) and gobo_dllmain.c.
# 3. link -DLL -> xpact.dll + xpact.lib. Never writes into build\native-eiffel (the tested EiffelStudio DLLs).
param([string] $OutputDir = "build\gobo-dll\out", [ValidateSet("msc")] [string] $CC = "msc")
$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Repo = (Resolve-Path "$Here\..\..").Path
. (Join-Path $Repo "reports\gobo-2026-11-16\gobo-env.ps1") -CC $CC | Out-Host
$Out = [System.IO.Path]::GetFullPath((Join-Path $Repo $OutputDir))
# Only ever delete a build-owned output folder: inside build\ (not build\ itself, never build\native-eiffel),
# and either empty or holding an earlier Gobo output (the marker below, or gen\ from builds before it existed).
# A mistyped -OutputDir (src, website, .) stops here instead of being wiped. Literal paths: no wildcard expansion.
$BuildRoot = [System.IO.Path]::GetFullPath((Join-Path $Repo "build")).TrimEnd('\') + '\'
$Marker = ".xpact-gobo-dll-out"
if (-not $Out.StartsWith($BuildRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $Out.TrimEnd('\') + '\' -eq $BuildRoot) {
	throw "refusing to use $Out as output: -OutputDir must be a folder inside $BuildRoot"
}
if ($Out -like "*native-eiffel*") { throw "refusing to write into $Out" }
if (Test-Path -LiteralPath $Out) {
	$Old = @(Get-ChildItem -LiteralPath $Out -Force)
	$Earlier = (Test-Path -LiteralPath (Join-Path $Out $Marker)) -or (Test-Path -LiteralPath (Join-Path $Out "gen") -PathType Container)
	if ($Old.Count -and -not $Earlier) {
		throw "$Out is not empty and is not an earlier Gobo DLL output (no $Marker or gen\): not deleting it."
	}
	Remove-Item -LiteralPath $Out -Recurse -Force
}
$Gen = Join-Path $Out "gen"
New-Item -ItemType Directory -Force $Gen | Out-Null
Set-Content -LiteralPath (Join-Path $Out $Marker) -Value "Output of reports\gobo-dll\build_gobo_dll.ps1: may be deleted and rebuilt by it."

Push-Location $Gen
try {
	& gec --finalize --cc=no (Join-Path $Here "xpact_native_library_gobo.ecf") | Select-Object -Last 2 | Out-Host
	if ($LASTEXITCODE) { throw "gec failed" }
	$Bat = Get-Content ".gobo\xpact_native_library.bat"
	$Flags = (($Bat | Where-Object { $_ -like "cl *" } | Select-Object -First 1) -replace '^cl ', '' -replace ' -c \S+$', '')
	$Flags = $Flags -replace '%BOEHM_GC%', "$env:GOBO\tool\gec\backend\c\boehm_gc"
	$Runtime = "$env:GOBO\tool\gec\backend\c\runtime"
	# The ECF's relative include paths are resolved from the wrong folder here: add them as absolute paths.
	$Flags += " -I`"$Repo\include`" -I`"$Repo\native`""
	$Objects = @()
	# Append the thread adoption (uses Gobo runtime internals) to the generated file that contains the runtime.
	$RuntimeC = Get-ChildItem ".gobo\*.c" | Where-Object { Select-String -Path $_.FullName -Pattern "^void GE_init_thread" -Quiet } | Select-Object -First 1
	Add-Content -Path $RuntimeC.FullName -Value (Get-Content (Join-Path $Here "gobo_thread_adopt.c") -Raw)
	foreach ($C in Get-ChildItem ".gobo\*.c") {
		$Obj = Join-Path $Out ($C.BaseName + ".obj")
		cmd /c "cl $Flags -Dmain=xp_gobo_main -DWinMain=xp_gobo_winmain -c `"$($C.FullName)`" -Fo:`"$Obj`"" | Select-Object -Last 1 | Out-Host
		if ($LASTEXITCODE) { throw "cl failed on $($C.Name)" }
		$Objects += $Obj
	}
	# GE_USE_BOEHM_GC / GE_USE_THREADS as in Gobo's generated header: with the Boehm GC an EIF_OBJECT is a
	# pointer to a slot, and eif_access must dereference it (without the define the bridge used the slot itself).
	$Common = "-nologo -MT -O2 -DNDEBUG -D_WIN32_WINNT=0x0600 -DXPACT_BUILDING_DLL -DXP_GOBO_RUNTIME -DGE_USE_BOEHM_GC -DGE_USE_THREADS -I`"$Repo\include`" -I`"$Repo\native`" -I`"$Runtime`" -I`"$env:GOBO\tool\gec\backend\c\boehm_gc\include`" -I`"$env:GOBO\tool\gec\backend\c\boehm_gc\libatomic_ops\src`""
	foreach ($Src in "$Repo\native\xpact_native.c", "$Repo\native\xpact_eiffel_runtime_bridge.c", "$Here\gobo_dllmain.c") {
		$Obj = Join-Path $Out ([IO.Path]::GetFileNameWithoutExtension($Src) + ".obj")
		cmd /c "cl $Common -c `"$Src`" -Fo:`"$Obj`"" | Select-Object -Last 1 | Out-Host
		if ($LASTEXITCODE) { throw "cl failed on $Src" }
		$Objects += $Obj
	}
	$Libs = "USER32.lib WS2_32.lib ADVAPI32.lib GDI32.lib SHELL32.lib MSIMG32.lib COMDLG32.lib UUID.lib OLE32.lib OLEAUT32.lib COMCTL32.lib MPR.LIB SHLWAPI.LIB WINSPOOL.LIB"
	$Dll = Join-Path $Out "xpact.dll"
	$Objs = ($Objects | ForEach-Object { "`"$_`"" }) -join " "
	cmd /c "link -nologo -DLL -DEBUG -STACK:5000000 -NODEFAULTLIB:libc -OUT:`"$Dll`" -IMPLIB:`"$Out\xpact.lib`" $Objs $Libs" | Select-Object -Last 3 | Out-Host
	if ($LASTEXITCODE) { throw "link failed" }
	"Built $Dll SHA-256 $((Get-FileHash $Dll).Hash.Substring(0,16))"
} finally { Pop-Location }
