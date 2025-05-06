<#
.SYNOPSIS
    Provides helper functions to manage system and user-level environment variables.

.DESCRIPTION
    This module allows reading, writing, and removing Windows environment variables
    at the "User" or "Machine" level using the .NET System.Environment class. It
    integrates with LoggingHelper.psm1 to track changes and issues.

    These functions are ideal for automating persistent configuration changes or
    modifying PATH variables in deployment and provisioning scripts.

.EXAMPLE
    Set-GitecEnvVar -Name "GITEC_PATH" -Value "C:\GitecOps" -Scope Machine
    # Creates or updates a system-level environment variable.

.EXAMPLE
    $val = Get-GitecEnvVar -Name "GITEC_PATH" -Scope Machine
    # Retrieves the value of an existing environment variable.

.EXAMPLE
    Remove-GitecEnvVar -Name "GITEC_PATH" -Scope Machine
    # Deletes the environment variable at the specified scope.

.NOTES
    - Scope must be either 'User' or 'Machine'.
    - No support for 'Process' scope by design — this is for persistent config only.
    - LoggingHelper.psm1 (optional) provides structured feedback and diagnostics.
    - Machine-scope changes may require elevated permissions.
    - No immediate session reload — environment variables will apply to new processes.
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

function Get-GitecEnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet("User", "Machine")][string]$Scope = "User"
    )

    try {
        $target = if ($Scope -eq "Machine") { [System.EnvironmentVariableTarget]::Machine } else { [System.EnvironmentVariableTarget]::User }
        $value = [System.Environment]::GetEnvironmentVariable($Name, $target)
        Write-Log "Retrieved env var '$Name' at $Scope scope" -Level "DEBUG"
        return $value
    } catch {
        Write-Log "Failed to get env var '$Name': $_" -Level "ERROR"
        throw
    }
}

function Set-GitecEnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value,
        [ValidateSet("User", "Machine")][string]$Scope = "User"
    )

    try {
        $target = if ($Scope -eq "Machine") { [System.EnvironmentVariableTarget]::Machine } else { [System.EnvironmentVariableTarget]::User }
        [System.Environment]::SetEnvironmentVariable($Name, $Value, $target)
        Write-Log "Set env var '$Name' = '$Value' at $Scope scope" -Level "INFO"
    } catch {
        Write-Log "Failed to set env var '$Name': $_" -Level "ERROR"
        throw
    }
}

function Remove-GitecEnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet("User", "Machine")][string]$Scope = "User"
    )

    try {
        $target = if ($Scope -eq "Machine") { [System.EnvironmentVariableTarget]::Machine } else { [System.EnvironmentVariableTarget]::User }
        [System.Environment]::SetEnvironmentVariable($Name, $null, $target)
        Write-Log "Removed env var '$Name' at $Scope scope" -Level "INFO"
    } catch {
        Write-Log "Failed to remove env var '$Name': $_" -Level "ERROR"
        throw
    }
}
