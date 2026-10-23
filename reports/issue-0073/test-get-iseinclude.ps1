# Tests Get-IseInclude from the native build scripts without a real Jenkins
# machine. The function is taken from the script, and the two known install
# roots in it are replaced by fake folders under a temporary directory, so
# each case controls which installs "exist". Usage, from the repository root:
#   powershell -NoProfile -File reports\issue-0073\test-get-iseinclude.ps1
# Exit code 0 when every case gives the expected result, 1 otherwise.
param(
	[string[]] $Script = @("scripts\build_native_eiffel.ps1", "scripts\run_native_runtime_smoke.ps1")
)

$ErrorActionPreference = "Stop"
$Jenkins = "C:\El2502E"
$Student = "C:\Program Files\Eiffel Software\EiffelStudio 25.12 Standard"
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("iseinclude-" + [guid]::NewGuid())
$FakeJenkins = Join-Path $Temp "El2502E"
$FakeStudent = Join-Path $Temp "Studio2512"
$FakeIse = Join-Path $Temp "IseEiffel"
$Include = "studio\spec\win64\include"
$RealEcRoot = $null
$RealEc = Get-Command ec -ErrorAction SilentlyContinue
if ($RealEc) {
	$RealEcRoot = (Resolve-Path (Join-Path (Split-Path -Parent $RealEc.Source) "..\..\..\..")).Path
}
$EcFolder = if ($RealEc) { Split-Path -Parent $RealEc.Source } else { "" }
$PathWithoutEc = (@($env:Path -split ";" | Where-Object { $_ -and $_.TrimEnd("\") -ne $EcFolder.TrimEnd("\") }) -join ";")
$SavedPath = $env:Path
$SavedIse = $env:ISE_EIFFEL

function Set-Install([string] $Root, [bool] $Present) {
	$Folder = Join-Path $Root $Include
	if ($Present) {
		New-Item -ItemType Directory -Force -Path $Folder | Out-Null
	} elseif (Test-Path -LiteralPath $Root) {
		Remove-Item -LiteralPath $Root -Recurse -Force
	}
}

# Name, ISE_EIFFEL, fake Jenkins install, fake student install, ec on PATH, expected
$Cases = @(
	@{ Name = "1 Jenkins: no ISE_EIFFEL, only C:\El2502E, no ec on PATH"; Ise = ""; J = $true; S = $false; Ec = $false; Expect = "jenkins" },
	@{ Name = "2 Student: no ISE_EIFFEL, only 25.12 Standard, no ec on PATH"; Ise = ""; J = $false; S = $true; Ec = $false; Expect = "student" },
	@{ Name = "3 ISE_EIFFEL valid wins over both installs"; Ise = "valid"; J = $true; S = $true; Ec = $false; Expect = "ise" },
	@{ Name = "4 ISE_EIFFEL without include folder is skipped"; Ise = "invalid"; J = $true; S = $false; Ec = $false; Expect = "jenkins" },
	@{ Name = "5 Both installs: C:\El2502E comes first"; Ise = ""; J = $true; S = $true; Ec = $false; Expect = "jenkins" },
	@{ Name = "6 No known install, ec on PATH"; Ise = ""; J = $false; S = $false; Ec = $true; Expect = "ec" },
	@{ Name = "7 Nothing at all: clear error"; Ise = ""; J = $false; S = $false; Ec = $false; Expect = "throw" }
)

$Failures = 0
try {
	foreach ($File in $Script) {
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $File).Path, [ref] $null, [ref] $null)
		$Function = $Ast.Find({ param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq "Get-IseInclude" }, $true)
		$Text = $Function.Extent.Text.Replace($Jenkins, $FakeJenkins).Replace($Student, $FakeStudent)
		Write-Host "== $File"
		foreach ($Case in $Cases) {
			if ($Case.Expect -eq "ec" -and -not $RealEcRoot) {
				Write-Host ("  SKIP  {0} (no ec on PATH on this machine)" -f $Case.Name)
				continue
			}
			Set-Install $FakeJenkins $Case.J
			Set-Install $FakeStudent $Case.S
			Set-Install $FakeIse ($Case.Ise -eq "valid")
			New-Item -ItemType Directory -Force -Path $FakeIse | Out-Null
			$env:ISE_EIFFEL = if ($Case.Ise) { $FakeIse } else { $null }
			$env:Path = if ($Case.Ec) { $SavedPath } else { $PathWithoutEc }
			$Expected = switch ($Case.Expect) {
				"jenkins" { Join-Path $FakeJenkins $Include }
				"student" { Join-Path $FakeStudent $Include }
				"ise" { Join-Path $FakeIse $Include }
				"ec" { Join-Path $RealEcRoot $Include }
				default { "(error)" }
			}
			try {
				Invoke-Expression $Text
				$Actual = Get-IseInclude
			} catch {
				$Actual = "(error) $($_.Exception.Message)"
			}
			$Pass = if ($Case.Expect -eq "throw") { $Actual -like "(error)*" } else { $Actual -eq $Expected }
			if (-not $Pass) { $Failures++ }
			Write-Host ("  {0}  {1}" -f $(if ($Pass) { "PASS" } else { "FAIL" }), $Case.Name)
			Write-Host ("        expected: {0}" -f $Expected.Replace($Temp, "<tmp>"))
			Write-Host ("        actual:   {0}" -f ([string] $Actual).Replace($Temp, "<tmp>"))
		}
	}
} finally {
	$env:Path = $SavedPath
	$env:ISE_EIFFEL = $SavedIse
	if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Recurse -Force }
}
Write-Host ("{0} failure(s)" -f $Failures)
exit ([int] ($Failures -ne 0))
