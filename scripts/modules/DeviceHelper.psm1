<#
.SYNOPSIS
    DeviceHelper.psm1
.DESCRIPTION
    This module provides helper functions for device management and operations.
    It includes functions for validating and parsing CTE names, as well as managing registry keys.
.EXAMPLE
    Test-CTENameFormat -Name "CTE-1234-ABCD"
    # Validates the CTE name format and returns true or false.

.EXAMPLE
    Convert-CTEName -Name "CTE-1234-ABCD"
    # Converts the CTE name and returns an object with segments and validity status.

.NOTES
    - Module Name: DeviceHelper
#>

function Test-DeviceNameFormat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceName
    )

    if(Test-CTEProperFormat -Name $DeviceName) {
        Write-Verbose "Valid CTE name format: $DeviceName"
        return $true
    } elseif (Test-CTEAlternateFormat -Name $DeviceName) {
        Write-Verbose "Valid CTE alternate format: $DeviceName"
        return $true
    } else {
        Write-Verbose "Invalid CTE name format: $DeviceName"
        return $false
    }
}

function Convert-CTEAlternateFormat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceName
    )

    $room = $DeviceName.Substring(3, 3)
    $asset = $DeviceName.Substring(6, 4)

    $newName = "CTE-$room-$asset"
    return $newName
}


function Test-CTEProperFormat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceName
    )

    $pattern = '^CTE-(\d{3}|[A-Z]\d{3})-([A-Z]\d{4,5}|\d{5})$'

    if ($DeviceName -match $pattern) {
        Write-Verbose "Valid CTE name: $DeviceName"
        return $true
    } else {
        Write-Verbose "Invalid CTE name: $DeviceName"
        return $false
    }
}

function Test-CTEAlternateFormat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceName
    )

    $pattern = '^CTE\d{3}[A-Z]\d{4}$'

    if ($DeviceName -match $pattern) {
        Write-Verbose "Valid CTE format: $DeviceName"
        return $true
    } else {
        Write-Verbose "Invalid CTE format: $DeviceName"
        return $false
    }
}

function Get-NameParts {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DeviceName
    )

    if (-not (Test-DeviceNameFormat -DeviceName $DeviceName)) {
        Write-Error "Invalid device name format: $DeviceName"
        return $null
    }

    $parts = @{
        Room  = ($DeviceName.Split('-')[1] -replace '\D', '')
        Asset = ($DeviceName.Split('-')[2] -replace '\D', '')
    }
    return $parts
}