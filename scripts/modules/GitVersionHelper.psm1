<#
.SYNOPSIS
    Retrieves the current Git commit hash from a local repository.

.DESCRIPTION
    Validates the target path and retrieves the commit hash from the specified Git ref (e.g., HEAD, origin/main).
    Supports short and full commit hash output. Designed for use in automation pipelines or update checks.

.EXAMPLE
    Get-GitecRepoVersion -RepoPath "C:\MyRepo"

.EXAMPLE
    Get-GitecRepoVersion -RepoPath "C:\MyRepo" -Ref "origin/main" -Short
#>

function Import-LoggingIfAvailable {
    if (-not (Get-Command -Name Write-Log -ErrorAction SilentlyContinue)) {
        $logPath = Join-Path $PSScriptRoot "LoggingHelper.psm1"
        if (Test-Path $logPath) {
            Import-Module $logPath -Force
        }
    }
}

Import-LoggingIfAvailable

function Get-RemoteRepoVersion {
    param (
        [Parameter(Mandatory)][string]$RepoPath,
        [string]$Branch = "main",
        [switch]$Short
    )

    $gitDir = Join-Path $RepoPath ".git"
    $gitArgs = @("--git-dir=$gitDir", "ls-remote", "origin", "refs/heads/$Branch")
    
    $output = & git @gitArgs 2>&1
    if ($LASTEXITCODE -eq 0 -and $output -match "^[0-9a-f]{40}") {
        $hash = ($output -split "\t")[0]
        if ($Short) {
            $shortHash = & git --git-dir=$gitDir rev-parse --short $hash
            return $shortHash.Trim()
        }
        return $hash.Trim()
    } else {
        Write-Log "Error getting remote git version: $output" -Level "ERROR"
        return $null
    }
}

function Get-LocalRepoVersion {
    param (
        [Parameter(Mandatory)][string]$RepoPath,
        [string]$Ref = "HEAD",
        [switch]$Short
    )

    $gitDir = Join-Path $RepoPath ".git"
    $gitArgs = @("--git-dir=$gitDir", "--work-tree=$RepoPath", "rev-parse")
    if ($Short) { $gitArgs += "--short" }
    $gitArgs += $Ref

    $output = & git @gitArgs 2>&1
    if ($LASTEXITCODE -eq 0 -and $output -notmatch "usage:") {
        return $output.Trim()
    } else {
        Write-Log "Error getting local git version: $output" -Level "ERROR"
        return $null
    }
}