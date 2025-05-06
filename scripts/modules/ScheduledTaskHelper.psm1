<#
.SYNOPSIS
    Automates the creation, removal, and inspection of Windows Scheduled Tasks with standardized behavior.

.DESCRIPTION
    This module provides a simplified interface to create and manage scheduled tasks using PowerShell.
    It supports multiple trigger types (AtStartup, Daily, OnIdle), forceful recreation of existing tasks,
    running as SYSTEM or current user, and logs all activity if LoggingHelper.psm1 is present.

    All functions are prefixed with "GitecOps" for consistency and are designed for use in deployment,
    automation, and maintenance scenarios.

.EXAMPLE
    New-GitecScheduledTask -TaskName "NightlyCleanup" `
        -ScriptPath "C:\GitecOps\scripts\nightly.ps1" `
        -Trigger "AtStartup" -RunAsCurrentUser -Force

    # Creates a task to run nightly.ps1 at startup, recreating if it already exists

.EXAMPLE
    Remove-GitecScheduledTask -TaskName "NightlyCleanup"
    # Removes a scheduled task if it exists

.EXAMPLE
    $info = Get-GitecScheduledTaskInfo -TaskName "NightlyCleanup"
    # Retrieves task info as an object

.NOTES
    - Only supports AtStartup, Daily, and OnIdle triggers.
    - Runs PowerShell scripts with `-NoProfile -ExecutionPolicy Bypass`.
    - Principal can be SYSTEM, the current user, or a specified username.
    - LoggingHelper.psm1 (optional) will log actions and errors.
    - Task name must be unique; use -Force to overwrite.
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

function New-GitecScheduledTask {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][string]$ScriptPath,
        [string]$Description = "",
        [ValidateSet("AtStartup", "Daily", "OnIdle")][string]$Trigger = "AtStartup",
        [string]$StartTime = "03:00",
        [string]$User = "SYSTEM",
        [switch]$RunAsCurrentUser,
        [switch]$Force
    )

    try {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            if ($Force) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-Log "Removed existing scheduled task: $TaskName" -Level "WARN"
            } else {
                Write-Log "Scheduled task '$TaskName' already exists. Use -Force to recreate." -Level "INFO"
                return
            }
        }

        $triggerObject = switch ($Trigger) {
            "AtStartup" { New-ScheduledTaskTrigger -AtStartup }
            "Daily"     { New-ScheduledTaskTrigger -Daily -At $StartTime }
            "OnIdle"    { New-ScheduledTaskTrigger -AtStartup -Delay "00:05:00" }
        }

        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

        $principal = if ($RunAsCurrentUser) {
            New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest
        } elseif ($User -eq "SYSTEM") {
            New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        } else {
            New-ScheduledTaskPrincipal -UserId $User -LogonType Password -RunLevel Highest
        }

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable `
            -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

        Register-ScheduledTask -TaskName $TaskName `
            -Action $action -Trigger $triggerObject -Principal $principal -Settings $settings -Description $Description

        Write-Log "Scheduled task '$TaskName' created successfully." -Level "INFO"
    } catch {
        Write-Log "Failed to create scheduled task '$TaskName': $_" -Level "ERROR"
        throw
    }
}

function Remove-GitecScheduledTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskName
    )

    try {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "Scheduled task '$TaskName' removed." -Level "INFO"
        } else {
            Write-Log "Scheduled task '$TaskName' not found." -Level "WARN"
        }
    } catch {
        Write-Log "Failed to remove scheduled task '$TaskName': $_" -Level "ERROR"
    }
}

function Get-GitecScheduledTaskInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskName
    )

    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        Write-Log "Retrieved task info for '$TaskName'." -Level "DEBUG"
        return $task
    } catch {
        Write-Log "Failed to get task info for '$TaskName': $_" -Level "WARN"
        return $null
    }
}
