<#
run_four_way.ps1 - the whole four-way comparison (xpact, expat, xpact via Gobo, xpact-core) in one command.
  .\benchmarks\four_way\run_four_way.ps1                      -> reports\four-way-<date>\ (logs, tables, step summary)
  .\benchmarks\four_way\run_four_way.ps1 -SkipLinux           Windows lanes only
Needs (once): EiffelStudio + Visual Studio C++ (Windows), Python 3.11+ (uv is fine), Git; for the Linux half a WSL
distro with /opt/Eiffel_25.12, /opt/gobo, gcc, python3, libexpat1-dev (see the report, section Environment).
Every step logs to logs\NN-name.log and is recorded in logs\00-steps.tsv; a failing step never stops the run.
#>
param(
    [string]$ReportDir, [string]$ExpatSource = 'C:\xpact\deps\libexpat', [string]$Distro = 'Ubuntu-24.04',
    [int]$SpeedDocs = 16000, [int]$SpeedReps = 5, [int]$LargeXmlMB = 5, [switch]$SkipLinux, [switch]$SkipLarge
)
$ErrorActionPreference = 'Continue'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $ReportDir) { $ReportDir = Join-Path $Repo ("reports\four-way-" + (Get-Date -Format 'yyyy-MM-dd')) }
$L = Join-Path $ReportDir 'logs'; New-Item -ItemType Directory -Force $L, "$ReportDir\w3c", "$ReportDir\regression", "$ReportDir\dual" | Out-Null
$Steps = Join-Path $L '00-steps.tsv'; "step`texit`tminutes" | Set-Content $Steps -Encoding UTF8
Set-Location $Repo

# ---- tools on PATH: Python (uv or real), Visual Studio CMake
$py = (& uv python find 2>$null); if (-not $py) { $py = (Get-Command python -ErrorAction SilentlyContinue).Source }
$cmake = Get-ChildItem 'C:\Program Files\Microsoft Visual Studio' -Recurse -Filter cmake.exe -ErrorAction SilentlyContinue | Where-Object FullName -match 'CMake\\bin' | Select-Object -First 1
$env:Path = (Split-Path $py) + ';' + $(if ($cmake) { (Split-Path $cmake.FullName) + ';' }) + $env:Path

function Step([string]$name, [string]$command) {
    # runs in a fresh PowerShell with the MSVC environment; stderr is logged, not treated as an error
    $t0 = Get-Date
    cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -Command "". .\scripts\import_msvc_environment.ps1 *> `$null; $command"" > ""$L\$name.log"" 2>&1"
    $code = $LASTEXITCODE; $min = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    "$name`t$code`t$min" | Add-Content $Steps; Write-Host ("{0,-34} exit={1,-3} {2} min" -f $name, $code, $min)
}
function Latest([string]$dir) { (Get-ChildItem (Join-Path $Repo "build\$dir") -Directory | Sort-Object Name | Select-Object -Last 1).FullName }
function WslPath([string]$p) { ((wsl -d $Distro wslpath -a ($p -replace '\\', '/')) -replace "`0", '').Trim() }

# ---- 1. builds
Step '01-build-implementations' '.\scripts\build_implementations.ps1'
Step '02-build-native-eiffel' '.\scripts\build_native_eiffel.ps1'

# ---- 2. dual lanes (xpact vs xpact-core); exit 1 = parser gaps recorded
foreach ($lane in 'w3c', 'regression', 'catalog') { Step "03-dual-$lane" ".\scripts\run_dual_$lane.ps1"
    $d = Latest "dual-$lane"; foreach ($f in 'summary.md', 'comparison.tsv', 'run.json') { if (Test-Path "$d\$f") { Copy-Item "$d\$f" "$ReportDir\dual\dual-$lane-$f" } } }
$Dual = Latest 'dual-w3c'

# ---- 3. libexpat suite through xpact's ABI
if (-not (Test-Path "$ExpatSource\.git")) { git clone -q --depth 1 --branch R_2_8_1 https://github.com/libexpat/libexpat.git $ExpatSource }
Step '04-libexpat-configure' ".\scripts\run_libexpat_adapter.ps1 -ExpatSourceDir $ExpatSource -Mode All"
Step '05-libexpat-native-suite' ".\scripts\run_libexpat_adapter.ps1 -ExpatSourceDir $ExpatSource -Mode NativeSuite"

# ---- 4. expat on Windows: W3C (exact dual case list) + regression
$F = Join-Path $Repo 'benchmarks\four_way'
Step '06-w3c-expat-windows' "python $F\run_manifest_engine.py --manifest $Dual\suite-manifest.json --suite-root $Dual\suite\xmlconf --name expat_win --out $ReportDir\w3c\expat-windows.tsv --jobs 8 -- python $F\expat_conformance_engine.py"
Step '07-regression-expat-windows' "python $F\run_regression_engine.py --name expat_win --out $ReportDir\regression\expat-windows.tsv -- python $F\expat_trace_engine.py"

# ---- 5. Linux half: Gobo + Linux EiffelStudio + Linux expat (WSL)
if (-not $SkipLinux) {
    $impl = Latest 'implementations'; $core = (Get-ChildItem "$Repo\build\dependencies\xpact-core" -Directory | Select-Object -First 1).FullName
    $t0 = Get-Date
    wsl -d $Distro -u root -- bash (WslPath "$F\wsl_four_way.sh") (WslPath $Repo) (WslPath "$impl\xpact\metadata") (WslPath "$impl\xpact-core\metadata") (WslPath $core) (WslPath $Dual) (WslPath $ReportDir) $SpeedDocs $SpeedReps > "$L\08-linux-four-way.log" 2>&1
    "08-linux-four-way`t$LASTEXITCODE`t$([math]::Round(((Get-Date) - $t0).TotalMinutes, 1))" | Add-Content $Steps
}

# ---- 6. xpact's own test sets (the native ABI tests need a WSL default distro with bash)
$prevDefault = ((wsl -l) -replace "`0", '' | Where-Object { $_ -match '\(Default\)|\(Standard\)' } | Select-Object -First 1) -replace '\s*\(.*$', ''
wsl --set-default $Distro | Out-Null
foreach ($a in 'Off', 'On') { foreach ($b in 'Workbench', 'Finalized') { Step "10-test-matrix-assert$a-$b" ".\scripts\run_eiffel_test_matrix.ps1 -AssertionMode $a -BuildMode $b" } }
Step '11-chunked-crc-harness' '.\scripts\run_chunked_crc_harness.ps1'
Step '12-chunked-crc-corpus' '.\scripts\run_chunked_crc_corpus.ps1'
Step '13-native-abi-tests' '.\scripts\run_native_abi_tests.ps1'
Step '14-native-runtime-smoke' '.\scripts\run_native_runtime_smoke.ps1'
Step '15-contributed-examples' '.\scripts\run_contributed_examples.ps1'
Step '16-incremental-shim-audit' '.\scripts\run_incremental_shim_audit.ps1'
Step '17-python-unittests' 'python -m unittest discover -s tests\python -p "test_*.py"'
Step '17b-dotnet-dll-tests' "dotnet build tests\dotnet\XpactDllTests -c Release -v q; build\dotnet\XpactDllTests\bin\Release\net10.0\XpactDllTests.exe --out \dotnet-dll-tests"
if ($prevDefault -and $prevDefault.Trim() -ne $Distro) { wsl --set-default $prevDefault.Trim() | Out-Null }

# ---- 7. W3C all cases (xpact) and large XML; both republish docs, which are restored afterwards
Step '18-w3c-all-cases-xpact' '.\scripts\run_benchmarks.ps1 -EiffelBuild FinalizedAssertions -W3cAllCases'
if (-not $SkipLarge) {
    $big = Join-Path $Repo 'build\four-way\large-catalog.xml'
    & python "$F\make_large_xml.py" $big $LargeXmlMB
    $rel = (Resolve-Path -Relative (New-Item -ItemType Directory -Force "$ReportDir\large-xml").FullName) -replace '^\.\\',''
    Step '19-large-xml' ".\scripts\run_large_xml_benchmarks.ps1 -XmlFile $big -OutputDir $rel -NoPublish"
}
foreach ($doc in git status --porcelain -- docs) { $p = $doc.Substring(3); Copy-Item $p (Join-Path $L ("published-" + ($p -replace '[\\/]', '_'))); git checkout -- $p }

# ---- 8. tables
& python "$F\summarize_four_way.py" $Dual "$ReportDir\w3c" "$ReportDir\w3c-four-way.md" | Out-Null
& python "$F\expat_lenient_cases.py" $Dual "$ReportDir\w3c\expat-windows.tsv" "$ReportDir\w3c\expat-lenient-cases.md" | Out-Null
Write-Host "`nsteps: $Steps"; Import-Csv $Steps -Delimiter "`t" | Format-Table -AutoSize | Out-String | Write-Host
