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

function Get-GitecRepoVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [string]$Ref = "HEAD",
        [switch]$Short
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Log "Repo path does not exist: $RepoPath" -Level "ERROR"
        return $null
    }

    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        Write-Log "Path is not a Git repository: $RepoPath" -Level "ERROR"
        return $null
    }

    try {
        $gitArgs = "--git-dir=`"$RepoPath\.git`" rev-parse"
        if ($Short) { $gitArgs += " --short" }
        $gitArgs += " $Ref"

        $gitVersion = & git $gitArgs
        Write-Log "Local repo version for '$Ref' is $gitVersion" -Level "DEBUG"
        return $gitVersion
    } catch {
        Write-Log "Failed to get local repo version for '$Ref': $_" -Level "ERROR"
        return $null
    }
}
