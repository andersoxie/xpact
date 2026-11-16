# Build libexpat 2.8.1 (Release, shared) for the fair speed test, like reports\issue-0121\expat-build.cmd.
# Downloads the official release tarball into build\libexpat-2.8.1, checks its SHA-256, builds with the CMake
# that ships with Visual Studio. Prints the path and SHA-256 of libexpat.dll.
#   powershell -File reports\perf-allocations\build_expat.ps1
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$Root = Join-Path $Repo "build\libexpat-2.8.1"
$Url = "https://github.com/libexpat/libexpat/releases/download/R_2_8_1/expat-2.8.1.tar.gz"
$Sha = "a52eb72108be160e190b5cafa5bba8663f1313f2013e26060d1c18e26e31067b"
New-Item -ItemType Directory -Force $Root | Out-Null
$Tar = Join-Path $Root "expat-2.8.1.tar.gz"
if (-not (Test-Path $Tar)) { Invoke-WebRequest -UseBasicParsing $Url -OutFile $Tar }
$Got = (Get-FileHash $Tar -Algorithm SHA256).Hash.ToLower()
if ($Got -ne $Sha) { Remove-Item $Tar; throw "SHA-256 mismatch: $Got (expected $Sha)" }
$Src = Join-Path $Root "expat-2.8.1"
# Run tar inside the folder with a plain file name: "C:\..." can be read as a remote host.
if (-not (Test-Path $Src)) { Push-Location $Root; try { tar -xzf "expat-2.8.1.tar.gz" } finally { Pop-Location } }
if (-not (Test-Path (Join-Path $Src "CMakeLists.txt"))) { throw "extraction failed: $Src" }
. (Join-Path $Repo "scripts\import_msvc_environment.ps1") | Out-Null
$CMake = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$Build = Join-Path $Root "build"
& $CMake -S $Src -B $Build -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF -DEXPAT_SHARED_LIBS=ON | Select-Object -Last 2
if ($LASTEXITCODE) { throw "cmake configure failed" }
& $CMake --build $Build | Select-Object -Last 2
if ($LASTEXITCODE) { throw "cmake build failed" }
$Dll = Get-ChildItem $Build -Filter "libexpat*.dll" -Recurse | Select-Object -First 1
"libexpat.dll: $($Dll.FullName) SHA-256 $((Get-FileHash $Dll.FullName).Hash.Substring(0,16))"
