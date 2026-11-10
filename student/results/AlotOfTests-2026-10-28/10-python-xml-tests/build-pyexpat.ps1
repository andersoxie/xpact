# Test 10: build CPython 3.14.0's pyexpat module (Modules/pyexpat.c) against xpact.lib instead of Expat.
# Result: build\<Tag>\pyexpat.pyd + the xpact DLL next to it. Nothing in the Python installation is changed.
param(
	[string] $Repo = "C:\Users\masou\Desktop\Lia\xpact\w9-latest",
	[string] $Lib = "xpact",          # or xpact_assertions
	[string] $Tag = "xpact"
)
$Py = Join-Path $env:LOCALAPPDATA "Programs\Python\Python314"
$Src = Join-Path $PSScriptRoot "download\cpython\Modules"
$Out = Join-Path $PSScriptRoot "build\$Tag"
New-Item -ItemType Directory -Force $Out | Out-Null
$env:Path = "C:\Program Files (x86)\Microsoft Visual Studio\Installer;$env:Path"
Push-Location $Repo
. .\scripts\import_msvc_environment.ps1 | Out-Null
Pop-Location
$ErrorActionPreference = "Continue"
$Native = Join-Path $Repo "build\native-eiffel"
& cl /nologo /LD /O2 /MD /DNDEBUG /I (Join-Path $PSScriptRoot "shim") /I (Join-Path $Repo "include") `
	/I (Join-Path $Py "include") /I (Join-Path $Py "include\internal") /I $Src (Join-Path $Src "pyexpat.c") `
	/Fo"$Out\pyexpat.obj" /link /OUT:"$Out\pyexpat.pyd" "/LIBPATH:$Py\libs" python314.lib "$Native\$Lib.lib" 2>&1 | Out-Host
"cl exit code: $LASTEXITCODE" | Out-Host
Copy-Item "$Native\$Lib.dll" $Out -Force
