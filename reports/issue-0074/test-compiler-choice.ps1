# Tests which ISE_C_COMPILER the native build scripts use for their Eiffel
# compile, without compiling. From each script it takes the statement that
# saves the old value ($OldCompiler = $env:ISE_C_COMPILER) and the statement
# right after it (the one that selects the backend), and runs both for each
# starting value. Usage, from the repository root:
#   powershell -NoProfile -File reports\issue-0074\test-compiler-choice.ps1
# Exit code 0 when every case gives the expected backend, 1 otherwise.
param(
	[string[]] $Script = @("scripts\build_native_eiffel.ps1", "scripts\run_native_runtime_smoke.ps1")
)

$ErrorActionPreference = "Stop"
$Saved = $env:ISE_C_COMPILER
# Starting value -> expected backend for the compile
$Cases = [ordered]@{
	"(unset)" = "msc_vc140"
	"mingw" = "msc_vc140"
	"msc" = "msc"
	"msc_vc140" = "msc_vc140"
}

$Failures = 0
try {
	foreach ($File in $Script) {
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $File).Path, [ref] $null, [ref] $null)
		$Statements = @($Ast.EndBlock.Statements)
		$Index = -1
		for ($I = 0; $I -lt $Statements.Count; $I++) {
			if ($Statements[$I].Extent.Text -match '^\$OldCompiler\s*=\s*\$env:ISE_C_COMPILER') {
				$Index = $I
				break
			}
		}
		if ($Index -lt 0) {
			throw "No `$OldCompiler = `$env:ISE_C_COMPILER statement in $File"
		}
		$Code = $Statements[$Index].Extent.Text + "`n" + $Statements[$Index + 1].Extent.Text
		Write-Host "== $File"
		foreach ($Start in $Cases.Keys) {
			$env:ISE_C_COMPILER = if ($Start -eq "(unset)") { $null } else { $Start }
			Invoke-Expression $Code
			$Actual = $env:ISE_C_COMPILER
			$Pass = $Actual -eq $Cases[$Start]
			if (-not $Pass) { $Failures++ }
			Write-Host ("  {0}  start {1,-10} expected {2,-10} actual {3}" -f $(if ($Pass) { "PASS" } else { "FAIL" }), $Start, $Cases[$Start], $Actual)
		}
	}
} finally {
	$env:ISE_C_COMPILER = $Saved
}
Write-Host ("{0} failure(s)" -f $Failures)
exit ([int] ($Failures -ne 0))
