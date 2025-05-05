<#
.SYNOPSIS
    Sets asset and service tags on HP systems using HP.ClientManagement module.

.DESCRIPTION
    This module depends on HP.ClientManagement being available and loaded. It wraps
    BIOS-level asset tag and system ID (service tag) modification functionality for automation.

.NOTES
    Requires elevated privileges and supported HP hardware.

.EXAMPLE
    Set-GitecHPAssetTag -AssetTag "CTE603A2716"

.EXAMPLE
    Set-GitecHPServiceTag -ServiceTag "5CD12345AB"
#>


function Import-HPModuleIfAvailable {
    if (-not (Get-Command -Name Set-HPBiosAssetTag -ErrorAction SilentlyContinue)) {
        $modulePath = Join-Path $PSScriptRoot "HP\HP.ClientManagement\HP.ClientManagement.psm1"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
        } else {
            throw "HP.ClientManagement module not found at expected path: $modulePath"
        }
    }
}

Import-HPModuleIfAvailable

function Set-GitecHPAssetTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$AssetTag
    )
    try {
        Set-HPBiosAssetTag -AssetTag $AssetTag -ErrorAction Stop
        Write-Log "Asset tag set to '$AssetTag'" -Level "INFO"
    } catch {
        Write-Log "Failed to set asset tag: $_" -Level "ERROR"
        throw
    }
}

function Set-GitecHPServiceTag {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$ServiceTag
    )
    try {
        Set-HPBiosUUID -UUID $ServiceTag -ErrorAction Stop
        Write-Log "Service tag set to '$ServiceTag'" -Level "INFO"
    } catch {
        Write-Log "Failed to set service tag: $_" -Level "ERROR"
        throw
    }
}
