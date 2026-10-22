# Runs a list of lanes ("On/Workbench", "Off/Finalized", "native/On", ...)
# with XPACT_META_FAIL set to -MetaFail (unset when empty) and writes
# <prefix>-<lane>.txt next to this script, each ending with its
# exit status. Example: .\run-set.ps1 -Prefix assert -MetaFail assert -Lanes Off/Workbench,native/Off
param([string] $Prefix, [string[]] $Lanes, [string] $MetaFail = "")
if ($MetaFail) { $env:XPACT_META_FAIL = $MetaFail } else { Remove-Item Env:XPACT_META_FAIL -ErrorAction SilentlyContinue }
Write-Host "XPACT_META_FAIL=[$env:XPACT_META_FAIL]"
foreach ($Lane in $Lanes) {
	$Parts = $Lane.Split("/")
	$Name = "$Prefix-$($Lane.Replace('/', '-').ToLower()).txt"
	$Log = Join-Path $PSScriptRoot $Name
	$Runner = Join-Path $PSScriptRoot "run-lane.ps1"
	if ($Parts[0] -eq "native") {
		$Arguments = "-AssertionMode $($Parts[1]) -Native"
	} else {
		$Arguments = "-AssertionMode $($Parts[0]) -BuildMode $($Parts[1])"
	}
	cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$Runner`" $Arguments > `"$Log`" 2>&1"
	$Code = $LASTEXITCODE
	Start-Sleep -Seconds 2
	Add-Content -LiteralPath $Log -Value "EXIT STATUS: $Code" -Encoding ascii
	Write-Host "$Lane exit $Code"
}
