[CmdletBinding()]
param(
	[ValidateSet("Xpact", "LibexpatWsl", "All")]
	[string] $Target = "Xpact",
	[ValidateSet("Direct", "Buffer", "All")]
	[string] $ParseMode = "All",
	[string] $ChunkSizes = "1,2,3,4,5,7,8,16,31,64,127,1024,whole",
	[string] $OutputDir = "build\chunked-crc",
	[ValidateRange(1, 10000)]
	[int] $CatalogItems = 30,
	[switch] $SkipBuild,
	[switch] $AllowMismatches
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputRoot = Join-Path $RepoRoot $OutputDir
$CorpusRoot = Join-Path $OutputRoot "corpus"
$Harness = Join-Path $PSScriptRoot "run_chunked_crc_harness.ps1"

New-Item -ItemType Directory -Force -Path $CorpusRoot | Out-Null

function Write-CorpusDocument {
	param(
		[string] $Name,
		[string] $Content
	)
	$Path = Join-Path $CorpusRoot $Name
	Set-Content -LiteralPath $Path -Value $Content -Encoding ASCII -NoNewline
	$Path
}

$Documents = New-Object System.Collections.Generic.List[string]

$Documents.Add((Write-CorpusDocument `
	-Name "plain-text.xml" `
	-Content "<?xml version='1.0'?><doc>value 1 value 2 value 3 value 4</doc>"))

$Documents.Add((Write-CorpusDocument `
	-Name "entities.xml" `
	-Content "<!DOCTYPE doc [<!ENTITY company 'AT&amp;T'><!ENTITY phrase 'Hello &company;'>]><doc>&phrase; and &company; again &#65;&#x42;.</doc>"))

$Documents.Add((Write-CorpusDocument `
	-Name "cdata-comments-pi.xml" `
	-Content "<?xml version='1.0'?><doc><?work now?><!-- comment --><![CDATA[raw < text & bytes]]><tail>after</tail></doc>"))

$Documents.Add((Write-CorpusDocument `
	-Name "namespaced-attributes.xml" `
	-Content "<ns:root xmlns:ns='urn:xpact' ns:id='a1'><ns:item code='c1' data='x &amp; y'>z</ns:item><ns:item code='c2'/></ns:root>"))

$Mixed = New-Object System.Text.StringBuilder
[void] $Mixed.Append("<doc>")
for ($Index = 1; $Index -le 40; $Index++) {
	[void] $Mixed.AppendFormat("text-{0}<span n='{0}'>inner-{0}</span>", $Index)
}
[void] $Mixed.Append("</doc>")
$Documents.Add((Write-CorpusDocument -Name "mixed-content.xml" -Content $Mixed.ToString()))

$Nested = New-Object System.Text.StringBuilder
[void] $Nested.Append("<n0>")
for ($Index = 1; $Index -le 64; $Index++) {
	[void] $Nested.AppendFormat("<n{0}>", $Index)
}
[void] $Nested.Append("leaf")
for ($Index = 64; $Index -ge 1; $Index--) {
	[void] $Nested.AppendFormat("</n{0}>", $Index)
}
[void] $Nested.Append("</n0>")
$Documents.Add((Write-CorpusDocument -Name "deep-nesting.xml" -Content $Nested.ToString()))

$Catalog = New-Object System.Text.StringBuilder
[void] $Catalog.Append("<?xml version='1.0'?>`n")
[void] $Catalog.Append("<!DOCTYPE catalog [<!ENTITY company 'AT&amp;T'>]>`n")
[void] $Catalog.Append("<catalog>")
for ($Index = 1; $Index -le $CatalogItems; $Index++) {
	[void] $Catalog.AppendFormat("<item id='{0}' code='c{1}'>value {0} &company;</item>", $Index, ($Index % 17))
}
[void] $Catalog.Append("</catalog>")
$Documents.Add((Write-CorpusDocument -Name "large-catalog.xml" -Content $Catalog.ToString()))

$HarnessArguments = @{
	Target = $Target
	ParseMode = $ParseMode
	ChunkSizes = $ChunkSizes
	OutputDir = $OutputDir
	XmlFile = $Documents.ToArray()
}
if ($SkipBuild) {
	$HarnessArguments.SkipBuild = $true
}
if ($AllowMismatches) {
	$HarnessArguments.AllowMismatches = $true
}

& $Harness @HarnessArguments

Write-Host "Chunked CRC corpus completed for $($Documents.Count) documents."
