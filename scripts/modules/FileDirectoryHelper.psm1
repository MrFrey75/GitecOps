<#
.SYNOPSIS
    Provides simplified and standardized file and directory operations for use across GitecOps tooling.

.DESCRIPTION
    This module contains helper functions for safely creating, reading, writing, and deleting files
    and directories, as well as listing their contents. It includes logging support and robust error handling,
    ensuring scripts and services behave consistently during filesystem manipulation.

    Intended for use in scripting environments, automation setups, and admin utilities where consistent,
    minimal file logic is essential.

.EXAMPLE
    New-GitecDirectory -Path "C:\GitecOps\data"
    # Ensures the directory exists, creating it if needed

.EXAMPLE
    Write-GitecFile -Path "C:\GitecOps\data\notes.txt" -Content "Test log"
    # Writes (or creates and writes) the file at the path

.EXAMPLE
    $data = Read-GitecFile -Path "C:\GitecOps\data\notes.txt"
    # Reads the contents of a text file as a raw string

.EXAMPLE
    Get-GitecDirectoryFiles -Path "C:\GitecOps\data" -Filter "*.json"
    # Lists JSON files in the target directory

.NOTES
    - Files are always assumed to be plain text.
    - LoggingHelper.psm1 (optional) enables debug and audit trails.
    - File creation auto-creates parent directories if missing.
    - Append mode is supported via the Write-GitecFile `-Append` switch.
    - Use Remove-GitecDirectory with -Recurse to delete non-empty folders.
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

function New-GitecDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "Created directory: $Path" -Level "INFO"
    }
}

function New-GitecFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        $parent = Split-Path $Path -Parent
        New-GitecDirectory -Path $parent
        New-Item -ItemType File -Path $Path -Force | Out-Null
        Write-Log "Created file: $Path" -Level "INFO"
    }
}

function Read-GitecFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (Test-Path $Path) {
        return Get-Content -Path $Path -Raw
    } else {
        Write-Log "File not found: $Path" -Level "WARN"
        return $null
    }
}

function Write-GitecFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content,
        [switch]$Append
    )

    Ensure-GitecFile -Path $Path

    if ($Append) {
        Add-Content -Path $Path -Value $Content
        Write-Log "Appended content to file: $Path" -Level "DEBUG"
    } else {
        Set-Content -Path $Path -Value $Content
        Write-Log "Wrote content to file: $Path" -Level "INFO"
    }
}

function Remove-GitecFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force
        Write-Log "Removed file: $Path" -Level "INFO"
    }
}

function Remove-GitecDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Recurse
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -Recurse:$Recurse
        Write-Log "Removed directory: $Path" -Level "INFO"
    }
}

function Get-GitecDirectoryFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Filter = "*",
        [switch]$Recurse
    )

    if (Test-Path $Path) {
        return Get-ChildItem -Path $Path -Filter $Filter -File -Recurse:$Recurse
    } else {
        Write-Log "Directory not found: $Path" -Level "WARN"
        return @()
    }
}
