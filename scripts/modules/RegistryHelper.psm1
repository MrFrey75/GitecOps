<#
.SYNOPSIS
    Provides simplified access to the Windows Registry under the GITEC namespace.

.DESCRIPTION
    This module offers functions to read, write, create, and delete registry values and keys
    within `HKLM:\Software\GITEC` or `HKCU:\Software\GITEC`. Designed for internal system config,
    state flags, and preferences across the GITEC admin toolset.

    All entries are automatically scoped under "Software\GITEC" to prevent conflicts
    and standardize configuration persistence.

    Optional integration with LoggingHelper.psm1 enables structured diagnostics.

.EXAMPLE
    Set-GitecRegistryValue -SubPath "Client" -Name "LastUpdated" -Value "2025-05-05"
    # Sets a string value under HKLM:\Software\GITEC\Client

.EXAMPLE
    Get-GitecRegistryValue -SubPath "Client" -Name "LastUpdated"
    # Reads the value back

.EXAMPLE
    Remove-GitecRegistryValue -SubPath "Client" -Name "LastUpdated"
    # Deletes the value from the registry

.EXAMPLE
    New-GitecRegistryKey -SubPath "Client\Config" -Hive HKCU
    # Creates a new key under HKCU:\Software\GITEC\Client\Config

.NOTES
    - Only `HKLM` and `HKCU` are supported as valid hives.
    - All keys are rooted at Software\GITEC to avoid pollution.
    - LoggingHelper.psm1 is optional but strongly recommended.
    - Value types are stored as REG_SZ (string); expand support if needed.
    - Use for internal state/config management, not general-purpose registry editing.
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

function Get-GitecRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubPath,
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet("HKLM", "HKCU")][string]$Hive = "HKLM"
    )

    $base = if ($Hive -eq "HKLM") { "HKLM:\Software\GITEC" } else { "HKCU:\Software\GITEC" }
    $path = Join-Path $base $SubPath

    try {
        $value = Get-ItemProperty -Path $path -Name $Name -ErrorAction Stop
        return $value.$Name
    } catch {
        Write-Log "Registry read failed: $path\$Name - $_" -Level "WARN"
        return $null
    }
}

function Set-GitecRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubPath,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value,
        [ValidateSet("HKLM", "HKCU")][string]$Hive = "HKLM"
    )

    $base = if ($Hive -eq "HKLM") { "HKLM:\Software\GITEC" } else { "HKCU:\Software\GITEC" }
    $path = Join-Path $base $SubPath

    try {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        Set-ItemProperty -Path $path -Name $Name -Value $Value -Force
        Write-Log "Registry value set: $path\$Name = $Value" -Level "INFO"
    } catch {
        Write-Log "Failed to set registry value: $path\$Name - $_" -Level "ERROR"
        throw
    }
}

function Remove-GitecRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubPath,
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet("HKLM", "HKCU")][string]$Hive = "HKLM"
    )

    $base = if ($Hive -eq "HKLM") { "HKLM:\Software\GITEC" } else { "HKCU:\Software\GITEC" }
    $path = Join-Path $base $SubPath

    try {
        Remove-ItemProperty -Path $path -Name $Name -ErrorAction Stop
        Write-Log "Registry value removed: $path\$Name" -Level "INFO"
    } catch {
        Write-Log "Failed to remove registry value: $path\$Name - $_" -Level "WARN"
    }
}

function New-GitecRegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SubPath,
        [ValidateSet("HKLM", "HKCU")][string]$Hive = "HKLM"
    )

    $base = if ($Hive -eq "HKLM") { "HKLM:\Software\GITEC" } else { "HKCU:\Software\GITEC" }
    $path = Join-Path $base $SubPath

    try {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
            Write-Log "Created registry key: $path" -Level "INFO"
        }
    } catch {
        Write-Log "Failed to create registry key: $path - $_" -Level "ERROR"
        throw
    }
}
