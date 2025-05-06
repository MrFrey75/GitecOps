<#
.SYNOPSIS
    Provides disk and volume management utilities for retrieving disk usage,
    SMART health, volume data, and removable media information.

.DESCRIPTION
    This module offers a set of helper functions for collecting disk statistics, volume
    details, and hardware info including SMART health. It supports selective drive
    queries and integrates seamlessly with LoggingHelper.psm1 for consistent reporting.

    All functions are prefixed with "Get-GitecOps*" and are intended for system
    administration, diagnostics, or inventory automation within GitecOps environments.

.EXAMPLE
    Get-GitecDiskUsage
    # Returns used, free, and total space info for all volumes

.EXAMPLE
    Get-GitecSMARTStatus
    # Returns SMART status for physical drives using WMI

.EXAMPLE
    Get-GitecMountedVolumes
    # Lists all currently mounted volumes

.EXAMPLE
    Get-GitecDiskType
    # Displays type and serial info for physical disks

.EXAMPLE
    Get-GitecRemovableDrives
    # Returns all removable media like USB drives

.NOTES
    - Requires PowerShell access to `Get-Volume`, `Get-PhysicalDisk`, and WMI.
    - LoggingHelper.psm1 (optional) provides diagnostics and status logging.
    - Drive usage uses `Get-PSDrive` limited to FileSystem providers.
    - SMART checks require WMI namespace root\wmi and may need admin privileges.
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

function Get-GitecDiskUsage {
    [CmdletBinding()]
    param(
        [string[]]$DriveLetters = @()
    )

    try {
        $drives = Get-PSDrive -PSProvider FileSystem
        if ($DriveLetters.Count -gt 0) {
            $drives = $drives | Where-Object { $DriveLetters -contains $_.Name }
        }

        $result = $drives | Select-Object Name,
            @{Name = "SizeGB"; Expression = { "{0:N2}" -f ($_.Used + $_.Free) / 1GB }},
            @{Name = "FreeGB"; Expression = { "{0:N2}" -f $_.Free / 1GB }},
            @{Name = "UsedGB"; Expression = { "{0:N2}" -f $_.Used / 1GB }},
            @{Name = "FreePercent"; Expression = { "{0:N0}" -f (($_.Free / ($_.Used + $_.Free)) * 100) }}

        Write-Log "Disk usage collected" -Level "DEBUG"
        return $result
    } catch {
        Write-Log "Failed to get disk usage: $_" -Level "ERROR"
        throw
    }
}

function Get-GitecDiskType {
    [CmdletBinding()]
    param()

    try {
        $disks = Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size, SerialNumber
        Write-Log "Disk types retrieved" -Level "DEBUG"
        return $disks
    } catch {
        Write-Log "Failed to retrieve physical disk type: $_" -Level "ERROR"
        throw
    }
}

function Get-GitecSMARTStatus {
    [CmdletBinding()]
    param()

    try {
        $status = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus |
            Select-Object InstanceName, PredictFailure, @{Name = "DriveOK"; Expression = { -not $_.PredictFailure }}

        Write-Log "SMART status retrieved" -Level "DEBUG"
        return $status
    } catch {
        Write-Log "Failed to retrieve SMART status: $_" -Level "ERROR"
        throw
    }
}

function Get-GitecMountedVolumes {
    [CmdletBinding()]
    param()

    try {
        $volumes = Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem, SizeRemaining, Size, Path, DriveType
        Write-Log "Mounted volumes retrieved" -Level "DEBUG"
        return $volumes
    } catch {
        Write-Log "Failed to retrieve mounted volumes: $_" -Level "ERROR"
        throw
    }
}

function Get-GitecRemovableDrives {
    [CmdletBinding()]
    param()

    try {
        $removable = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' } |
            Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size

        Write-Log "Removable drives found: $($removable.Count)" -Level "DEBUG"
        return $removable
    } catch {
        Write-Log "Failed to retrieve removable drives: $_" -Level "ERROR"
        throw
    }
}
