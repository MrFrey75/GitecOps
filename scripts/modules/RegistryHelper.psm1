# RegistryHelper.psm1
# Registry Helper Functions
# This module contains functions to manage registry keys and values.
# Requires: LoggingHelper.psm1 already imported


function Set-RegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Value,
        [string]$Key = "HKEY_LOCAL_MACHINE\SOFTWARE\GitecOps",
        [ValidateSet("String", "DWord", "QWord", "Binary", "MultiString", "ExpandString")]
        [string]$Type = "String"
    )

    try {
        $psPath = $Key -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'

        if (-not (Test-Path $psPath)) {
            New-Item -Path $psPath -Force | Out-Null
            Write-Info "Created registry key: $psPath"
        }

        # Use New-ItemProperty for type support if key doesn't exist
        if (-not (Get-ItemProperty -Path $psPath -Name $Name -ErrorAction SilentlyContinue)) {
            New-ItemProperty -Path $psPath -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop
        } else {
            Set-ItemProperty -Path $psPath -Name $Name -Value $Value -ErrorAction Stop
        }

        Write-Info "Set registry value: $Name = $Value at $psPath"
    } catch {
        Write-Error "Failed to set registry key '$Key' value '$Name': $_"
    }
}

function Get-RegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Key = "HKEY_LOCAL_MACHINE\SOFTWARE\GitecOps"
    )

    try {
        # Normalize registry path
        $psPath = $Key -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'

        if (-not (Test-Path $psPath)) {
            Write-Warning "Registry key does not exist: $psPath"
            return $null
        }

        $item = Get-ItemProperty -Path $psPath -Name $Name -ErrorAction Stop
        $value = $item.$Name

        Write-Info "Retrieved registry value: $Name = $value from $psPath"
        return $value
    } catch {
        Write-Warning "Registry value '$Name' not found at $Key"
        return $null
    }
}
