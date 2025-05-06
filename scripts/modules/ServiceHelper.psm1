<#
.SYNOPSIS
    Provides streamlined management of Windows services including start, stop, restart, and health checking.

.DESCRIPTION
    This module wraps standard service management operations in friendly, logged commands under the
    GitecOps naming convention. It includes error handling, WMI-based hung service detection, and can
    report service status for diagnostics or automation scripts.

    Optional integration with LoggingHelper.psm1 provides structured logs for all actions.

.EXAMPLE
    Start-GitecService -ServiceName "Spooler"
    # Starts the Print Spooler service if it's not already running

.EXAMPLE
    Stop-GitecService -ServiceName "Spooler"
    # Stops the service with force if necessary

.EXAMPLE
    Restart-GitecService -ServiceName "W32Time"
    # Restarts a named service

.EXAMPLE
    $svc = Get-GitecServiceStatus -ServiceName "BITS"
    if ($svc.Status -eq "Running") { ... }

.EXAMPLE
    Test-GitecServiceHung -ServiceName "WinDefend"
    # Returns $true if the service is stuck in StartPending or StopPending state

.NOTES
    - Built on top of Get-Service and Restart-Service with additional logging.
    - Uses WMI for hung state detection (Win32_Service).
    - LoggingHelper.psm1 is optional but strongly encouraged for diagnostics.
    - Restart and Stop use -Force to bypass stuck services.
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

function Get-GitecServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        Write-Log "Service '$ServiceName' status is $($service.Status)." -Level "DEBUG"
        return $service
    } catch {
        Write-Log "Failed to get status for service '$ServiceName': $_" -Level "ERROR"
        return $null
    }
}

function Start-GitecService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($service.Status -ne 'Running') {
            Start-Service -Name $ServiceName
            Write-Log "Service '$ServiceName' started." -Level "INFO"
        } else {
            Write-Log "Service '$ServiceName' is already running." -Level "DEBUG"
        }
    } catch {
        Write-Log "Failed to start service '$ServiceName': $_" -Level "ERROR"
    }
}

function Stop-GitecService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $ServiceName -Force
            Write-Log "Service '$ServiceName' stopped." -Level "INFO"
        } else {
            Write-Log "Service '$ServiceName' is already stopped." -Level "DEBUG"
        }
    } catch {
        Write-Log "Failed to stop service '$ServiceName': $_" -Level "ERROR"
    }
}

function Restart-GitecService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    try {
        Restart-Service -Name $ServiceName -Force
        Write-Log "Service '$ServiceName' restarted." -Level "INFO"
    } catch {
        Write-Log "Failed to restart service '$ServiceName': $_" -Level "ERROR"
    }
}

function Test-GitecServiceHung {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ServiceName
    )

    try {
        $svc = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
        if ($svc.State -eq 'Start Pending' -or $svc.State -eq 'Stop Pending') {
            Write-Log "Service '$ServiceName' appears hung in state: $($svc.State)" -Level "WARN"
            return $true
        }
        return $false
    } catch {
        Write-Log "Failed to check hung state for '$ServiceName': $_" -Level "ERROR"
        return $false
    }
}
