[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $JenkinsWarDirectory,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $JenkinsPluginsDirectory,
    [ValidateNotNullOrEmpty()]
    [string] $JavaPath = "java"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$WarRoot = (Resolve-Path -LiteralPath $JenkinsWarDirectory).ProviderPath
$PluginsRoot = (Resolve-Path -LiteralPath $JenkinsPluginsDirectory).ProviderPath
$WarLibraries = Join-Path $WarRoot "WEB-INF\lib"
$Winstone = Join-Path $WarRoot "executable\winstone.jar"
if (-not (Test-Path -LiteralPath $WarLibraries -PathType Container) -or
    -not (Test-Path -LiteralPath $Winstone -PathType Leaf)) {
    throw "JenkinsWarDirectory must contain WEB-INF/lib and executable/winstone.jar from an unpacked Jenkins WAR."
}
if (-not (Test-Path -LiteralPath $PluginsRoot -PathType Container)) {
    throw "JenkinsPluginsDirectory must name the installed, unpacked Jenkins plugins directory."
}

$Java = (Get-Command $JavaPath -CommandType Application -ErrorAction Stop).Source
$ClasspathEntries = @((Join-Path $WarLibraries "*"), $Winstone)
# Only enumerate unpacked plugin library directories; do not load Jenkins settings or credentials.
foreach ($PluginDirectory in Get-ChildItem -LiteralPath $PluginsRoot -Directory) {
    $PluginLibraries = Join-Path $PluginDirectory.FullName "WEB-INF\lib"
    if (Test-Path -LiteralPath $PluginLibraries -PathType Container) {
        $ClasspathEntries += Join-Path $PluginLibraries "*"
    }
}
$Classpath = ($ClasspathEntries -join [System.IO.Path]::PathSeparator).Replace("\", "/")
$ArgumentDirectory = Join-Path $RepoRoot "build\jenkins-pipeline-validation"
New-Item -ItemType Directory -Force -Path $ArgumentDirectory | Out-Null

function ConvertTo-JavaArgument {
    param([string] $Value)
    '"' + $Value.Replace("\", "/").Replace('"', '\"') + '"'
}

function Invoke-GroovyValidation {
    param([string] $Name, [string] $Script, [string[]] $ScriptArguments)
    $ArgumentPath = Join-Path $ArgumentDirectory "$Name.args"
    $JavaArguments = @("-ea", "-cp", (ConvertTo-JavaArgument $Classpath), "groovy.ui.GroovyMain",
                       (ConvertTo-JavaArgument (Join-Path $RepoRoot $Script)))
    foreach ($ScriptArgument in $ScriptArguments) {
        $JavaArguments += ConvertTo-JavaArgument $ScriptArgument
    }
    [System.IO.File]::WriteAllLines($ArgumentPath, $JavaArguments, [System.Text.UTF8Encoding]::new($false))
    # Java argument files avoid Windows command-line length limits for plugin classpaths.
    # Forward Java warnings without PowerShell 5 treating native stderr as a terminating error.
    $PreviousPreference = $ErrorActionPreference
    $ExitCode = $null
    try {
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = $null
        & $Java "@$ArgumentPath" 2>&1 | ForEach-Object { Write-Host $_ }
        $ExitCode = $global:LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousPreference
    }
    if ($null -eq $ExitCode) {
        throw "$Name could not launch Java."
    }
    if ($ExitCode -ne 0) {
        throw "$Name failed with Java exit code $ExitCode."
    }
}

Write-Host "Validating Declarative syntax with installed Jenkins libraries (offline metadata only)."
Invoke-GroovyValidation -Name "declarative" -Script "tests\jenkins\validate_declarative.groovy" `
    -ScriptArguments @((Join-Path $RepoRoot "ci\Jenkinsfile.windows-phase1"),
                       (Join-Path $RepoRoot "ci\Jenkinsfile.all-tests"))
Write-Host "Checking notification behavior with local Pipeline and mail stubs."
Invoke-GroovyValidation -Name "notifications" -Script "tests\jenkins\test_email_notifications.groovy" `
    -ScriptArguments @($RepoRoot)
Write-Host "Jenkinsfile checks passed. No Jenkins job or SMTP server was contacted."
