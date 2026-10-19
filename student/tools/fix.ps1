[CmdletBinding()]
param(
	# start  - create a fix branch for an issue from the base branch
	# finish - check the branch, push it and open a pull request
	# merge  - squash-merge the pull request into the base branch
	# revert - create a fix branch that reverts one merged fix
	# status - show the current fix branch and its pull request
	[Parameter(Mandatory = $true, Position = 0)]
	[ValidateSet("start", "finish", "merge", "revert", "status")]
	[string] $Action,
	# GitHub issue number the fix belongs to.
	[int] $Issue,
	# Short branch name part, e.g. "include-fallback" (start only).
	[string] $Name,
	# Commit to revert (revert only), e.g. 9eb18bd.
	[string] $Commit,
	[string] $Base = "student-Mass",
	[string] $Repo = "andersoxie/xpact"
)

# ---------------------------------------------------------------------------
# Versioning workflow for fixes; see student/VERSIONING.md.
#
#   .\student\tools\fix.ps1 start  -Issue 2 -Name include-fallback
#   ... edit, test, write reports\issue-0002\report.md, commit ...
#   .\student\tools\fix.ps1 finish
#   .\student\tools\fix.ps1 merge
#   .\student\tools\fix.ps1 revert -Issue 2 -Commit 9eb18bd
# ---------------------------------------------------------------------------

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Gh = (Get-Command gh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
if (-not $Gh) {
	$Gh = Join-Path $env:LOCALAPPDATA "Programs\GitHubCLI\bin\gh.exe"
}

# Runs git and fails on a nonzero exit code. Returns stdout.
function Invoke-Git {
	param([string[]] $Arguments)
	$Output = & git @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
	}
	$Output
}

# Runs gh and fails on a nonzero exit code. Returns stdout.
function Invoke-Gh {
	param([string[]] $Arguments)
	if (-not (Test-Path -LiteralPath $Gh -PathType Leaf)) {
		throw "GitHub CLI not found. See student/VERSIONING.md, section Setup."
	}
	$Output = & $Gh @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "gh $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
	}
	$Output
}

# Stops when tracked files have uncommitted changes. Untracked files are allowed.
function Assert-CleanTree {
	$Changes = @(Invoke-Git @("status", "--porcelain", "--untracked-files=no"))
	if ($Changes.Count -gt 0) {
		throw "Uncommitted changes in tracked files. Commit or stash them first:`n$($Changes -join "`n")"
	}
}

function Get-CurrentBranch {
	"$(Invoke-Git @("rev-parse", "--abbrev-ref", "HEAD"))".Trim()
}

# Returns the issue number from a fix/<issue>-<name> branch.
function Get-BranchIssue {
	param([string] $Branch)
	if ($Branch -notmatch "^fix/(\d+)-") {
		throw "Not on a fix branch (fix/<issue>-<name>): $Branch"
	}
	[int] $Matches[1]
}

# Every fix keeps its report and logs in one folder, e.g. reports/issue-0002.
# Zero-padded so the folders sort by issue number.
function Get-ReportDirectory {
	param([int] $Number)
	"reports/issue-{0:D4}" -f $Number
}

function Update-Base {
	Invoke-Git @("fetch", "--prune", "origin") | Out-Null
	Invoke-Git @("switch", $Base) | Out-Null
	Invoke-Git @("merge", "--ff-only", "origin/$Base") | Out-Null
}

# The script lives in student/tools, so it works from any current directory.
Set-Location -LiteralPath $PSScriptRoot
$RepoRoot = "$(Invoke-Git @("rev-parse", "--show-toplevel"))".Trim()
Set-Location -LiteralPath $RepoRoot

switch ($Action) {
	"start" {
		if ($Issue -le 0 -or [string]::IsNullOrWhiteSpace($Name)) {
			throw "Usage: fix.ps1 start -Issue <number> -Name <short-name>"
		}
		if ($Name -notmatch "^[a-z0-9]+(-[a-z0-9]+)*$") {
			throw "Use lowercase letters, digits and dashes for -Name, e.g. include-fallback"
		}
		$Title = "$(Invoke-Gh @("issue", "view", "$Issue", "--repo", $Repo, "--json", "title", "--jq", ".title"))".Trim()
		Assert-CleanTree
		Update-Base
		$Branch = "fix/$Issue-$Name"
		Invoke-Git @("switch", "-c", $Branch) | Out-Null
		Write-Host "On $Branch, from $Base @ $("$(Invoke-Git @("rev-parse", "--short", "HEAD"))".Trim())"
		$ReportDirectory = Get-ReportDirectory $Issue
		New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot $ReportDirectory) | Out-Null
		Write-Host "Issue #${Issue}: $Title"
		Write-Host "Next: fix, test, write $ReportDirectory/report.md (logs next to it), commit with 'Refs #$Issue', then: fix.ps1 finish"
	}

	"revert" {
		if ($Issue -le 0 -or [string]::IsNullOrWhiteSpace($Commit)) {
			throw "Usage: fix.ps1 revert -Issue <number> -Commit <sha>"
		}
		Assert-CleanTree
		Update-Base
		$Short = "$(Invoke-Git @("rev-parse", "--short", "$Commit^{commit}"))".Trim()
		$Subject = "$(Invoke-Git @("log", "-1", "--format=%s", $Short))".Trim()
		$Branch = "fix/$Issue-revert-$Short"
		Invoke-Git @("switch", "-c", $Branch) | Out-Null
		$Message = "Revert `"$Subject`"`n`nThis reverts commit $("$(Invoke-Git @("rev-parse", $Short))".Trim()).`n`nRefs #$Issue"
		Invoke-Git @("revert", "--no-edit", $Short) | Out-Null
		Invoke-Git @("commit", "--amend", "-m", $Message) | Out-Null
		Write-Host "On $Branch with a revert of $Short ($Subject)."
		Write-Host "Next: test, add to $(Get-ReportDirectory $Issue)/report.md why it was reverted, commit, then: fix.ps1 finish"
	}

	"finish" {
		$Branch = Get-CurrentBranch
		$BranchIssue = Get-BranchIssue $Branch
		Assert-CleanTree
		Invoke-Git @("fetch", "origin", $Base) | Out-Null

		$Commits = @(Invoke-Git @("log", "--format=%H", "origin/$Base..HEAD"))
		if ($Commits.Count -eq 0) {
			throw "No commits on $Branch yet."
		}
		# Traceable: every commit names the issue.
		foreach ($Sha in $Commits) {
			$Body = (Invoke-Git @("log", "-1", "--format=%B", $Sha)) -join "`n"
			if ($Body -notmatch "#$BranchIssue\b") {
				throw "Commit $($Sha.Substring(0, 7)) does not mention #$BranchIssue. Fix it with: git commit --amend (or git rebase)"
			}
		}
		# Tested: the fix report exists and records a verification.
		$Report = "$(Get-ReportDirectory $BranchIssue)/report.md"
		if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Report) -PathType Leaf)) {
			throw "Missing $Report. Every fix needs a report with a Verification section."
		}
		if (-not (Select-String -LiteralPath (Join-Path $RepoRoot $Report) -Pattern "^## Verification" -Quiet)) {
			throw "$Report has no '## Verification' section."
		}

		Invoke-Git @("push", "-u", "origin", $Branch) | Out-Null

		$Existing = "$(Invoke-Gh @("pr", "list", "--repo", $Repo, "--head", $Branch, "--state", "open", "--json", "url", "--jq", ".[0].url"))".Trim()
		if ($Existing) {
			Write-Host "Pushed. Pull request already open: $Existing"
			return
		}

		$Title = "$(Invoke-Git @("log", "--reverse", "--format=%s", "origin/$Base..HEAD") | Select-Object -First 1)".Trim()
		$CommitList = (Invoke-Git @("log", "--reverse", "--format=- %h %s", "origin/$Base..HEAD")) -join "`n"
		# Link by commit, not by branch: the branch is deleted after merging.
		$ReportUrl = "https://github.com/$Repo/blob/$("$(Invoke-Git @("rev-parse", "HEAD"))".Trim())/$Report"
		$PrBody = @"
Refs #$BranchIssue

## What changed
$CommitList

## Evidence
- Fix report: [$Report]($ReportUrl)
- Revision tested: $("$(Invoke-Git @("rev-parse", "--short", "HEAD"))".Trim())

## Revert
After merging, this pull request is one squashed commit on ``$Base``. Revert it with:
``.\student\tools\fix.ps1 revert -Issue $BranchIssue -Commit <merged sha>``
"@
		$BodyFile = [System.IO.Path]::GetTempFileName()
		try {
			[System.IO.File]::WriteAllText($BodyFile, $PrBody, (New-Object System.Text.UTF8Encoding($false)))
			$Url = Invoke-Gh @("pr", "create", "--repo", $Repo, "--base", $Base, "--head", $Branch, "--title", $Title, "--body-file", $BodyFile)
		} finally {
			Remove-Item -LiteralPath $BodyFile -Force -ErrorAction SilentlyContinue
		}
		Write-Host "Pull request: $Url"
		Write-Host "Next, when the checks pass: fix.ps1 merge"
	}

	"merge" {
		$Branch = Get-CurrentBranch
		$BranchIssue = Get-BranchIssue $Branch
		Assert-CleanTree
		$Number = "$(Invoke-Gh @("pr", "list", "--repo", $Repo, "--head", $Branch, "--state", "open", "--json", "number", "--jq", ".[0].number"))".Trim()
		if (-not $Number) {
			throw "No open pull request for $Branch. Run: fix.ps1 finish"
		}
		$Title = "$(Invoke-Gh @("pr", "view", $Number, "--repo", $Repo, "--json", "title", "--jq", ".title"))".Trim()
		# One squashed commit per fix: easy to find, easy to revert.
		Invoke-Gh @("pr", "merge", $Number, "--repo", $Repo, "--squash",
			"--subject", "$Title (#$Number)", "--body", "Refs #$BranchIssue") | Out-Null
		Update-Base
		Invoke-Git @("push", "origin", "--delete", $Branch) | Out-Null
		Invoke-Git @("branch", "-D", $Branch) | Out-Null
		$Merged = "$(Invoke-Git @("log", "-1", "--format=%h %s"))".Trim()
		Write-Host "Merged into ${Base}: $Merged"
		Write-Host "To revert later: fix.ps1 revert -Issue $BranchIssue -Commit $($Merged.Split(' ')[0])"
	}

	"status" {
		$Branch = Get-CurrentBranch
		Write-Host "Branch: $Branch"
		if ($Branch -match "^fix/(\d+)-") {
			Invoke-Gh @("pr", "list", "--repo", $Repo, "--head", $Branch, "--state", "all")
		}
		Invoke-Git @("log", "--oneline", "-5")
	}
}
