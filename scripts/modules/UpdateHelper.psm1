<#
.SYNOPSIS
    Checks for, installs, and monitors Windows Updates using the COM-based Microsoft Update API.

.DESCRIPTION
    This module provides GITEC-friendly PowerShell functions for querying and installing pending
    Windows updates. It supports optional inclusion of driver updates, silent installs,
    and automatic reboots. It also detects whether a system reboot is pending based on registry keys.

    COM objects are used directly, ensuring native update handling without relying on Windows Update CLI wrappers.

.EXAMPLE
    Get-GitecPendingUpdates
    # Returns a list of available software updates

.EXAMPLE
    Install-GitecUpdates -IncludeDrivers -AutoReboot
    # Installs all updates including drivers and reboots the system if required

.EXAMPLE
    if (Test-GitecRebootRequired) {
        Restart-Computer -Force
    }
    # Manually check if a reboot is needed

.NOTES
    - Requires Windows Update service to be running.
    - Uses COM object Microsoft.Update.Session and related interfaces.
    - LoggingHelper.psm1 (optional) will provide structured output.
    - Installation requires elevation (admin).
    - Driver updates are excluded by default unless -IncludeDrivers is specified.
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

function Get-GitecPendingUpdates {
    [CmdletBinding()]
    param(
        [switch]$IncludeDrivers
    )

    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $criteria = "IsInstalled=0"
        if (-not $IncludeDrivers) {
            $criteria += " AND Type='Software'"
        }

        $result = $searcher.Search($criteria)
        Write-Log "Found $($result.Updates.Count) pending updates." -Level "INFO"
        return $result.Updates | Select-Object Title, KBArticleIDs, IsMandatory, EulaAccepted
    } catch {
        Write-Log "Failed to query updates: $_" -Level "ERROR"
        throw
    }
}

function Install-GitecUpdates {
    [CmdletBinding()]
    param(
        [switch]$AutoReboot,
        [switch]$IncludeDrivers
    )

    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $criteria = "IsInstalled=0"
        if (-not $IncludeDrivers) {
            $criteria += " AND Type='Software'"
        }

        $updates = $searcher.Search($criteria).Updates
        if ($updates.Count -eq 0) {
            Write-Log "No updates to install." -Level "INFO"
            return
        }

        $downloadList = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $updates) {
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            [void]$downloadList.Add($update)
        }

        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $downloadList
        $downloader.Download()

        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $downloadList
        $result = $installer.Install()

        Write-Log "Installed updates. Result code: $($result.ResultCode)" -Level "INFO"

        if ($result.RebootRequired -and $AutoReboot) {
            Write-Log "Reboot required. Rebooting now..." -Level "WARN"
            Restart-Computer -Force
        } elseif ($result.RebootRequired) {
            Write-Log "Reboot required, but AutoReboot not set." -Level "WARN"
        }
    } catch {
        Write-Log "Failed to install updates: $_" -Level "ERROR"
        throw
    }
}

function Test-GitecRebootRequired {
    [CmdletBinding()]
    param()

    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
    )

    foreach ($key in $keys) {
        if (Test-Path $key) {
            Write-Log "Reboot pending due to: $key" -Level "WARN"
            return $true
        }
    }

    Write-Log "No reboot required." -Level "DEBUG"
    return $false
}
