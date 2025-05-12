param (
    [string]$BaseDir        = "C:\GitecOps",
    [bool]$IsDebug          = $true,
    [string]$RegKey         = "InitLastRun",
    [string]$LogName        = "Initialization",
    [string]$adminUser      = "cteadmin",
    [string]$adminPassword  = "S1lv#rBaCk!1"
)

# Construct module paths
$moduleDirectory      = Join-Path $BaseDir "scripts\modules"
$loggingModulePath    = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath    = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath   = Join-Path $moduleDirectory "RegistryHelper.psm1"

# Helper: Register a scheduled task
function Set-TaskAction {
    param (
        [string]$taskFolder,
        [string]$taskName,
        [string]$scriptPath,
        [string]$triggerType,
        [string]$startTime,
        [string[]]$daysOfWeek
    )

    $fullTaskName = "\$taskFolder\$taskName"

    # Remove existing task
    $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath "\$taskFolder\" -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Scheduled task '$fullTaskName' already exists. Deleting..."
        Unregister-ScheduledTask -TaskName $taskName -TaskPath "\$taskFolder\" -Confirm:$false
    }

    # Create action
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

    # Create trigger
    switch ($triggerType) {
        "Startup" {
            $trigger = New-ScheduledTaskTrigger -AtStartup
        }
        "Daily" {
            $trigger = New-ScheduledTaskTrigger -Daily -At ([datetime]::Parse($startTime))
        }
        "Weekly" {
            if (-not $daysOfWeek) {
                throw "Weekly trigger requires -daysOfWeek parameter (e.g. 'Monday')"
            }
    
            $parsedDays = $daysOfWeek | ForEach-Object { 
                [System.Enum]::Parse([System.DayOfWeek], $_, $true) 
            }
    
            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $parsedDays -At ([datetime]::Parse($startTime))
        }
        default {
            throw "Unsupported trigger type: $triggerType"
        }
    }

    # Settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    # Register
    Register-ScheduledTask -TaskName $taskName -TaskPath "\$taskFolder\" -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -RunLevel Highest
    Write-Host "Scheduled task '$fullTaskName' created successfully."
}

# Import modules
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath -Force -ErrorAction Stop
Import-Module -Name $registryModulePath -Force -ErrorAction Stop

# Configure logging
Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
Write-Info "Starting initialization script..."

# Set registry value for last run
Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
if ($null -eq $?) {
    Write-Error "Failed to set registry key '$RegKey'."
} else {
    Write-Info "Registry key '$RegKey' set successfully."
}

try {
    Write-Info "Performing initialization tasks..."

    # Add module path if missing
    if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
        $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
        Write-Info "Module directory added to PSModulePath."
    }

    # Create local admin user
    try {
        if (Get-LocalUser -Name $adminUser -ErrorAction SilentlyContinue) {
            Write-Info "Local user '$adminUser' already exists."
        } else {
            $password = ConvertTo-SecureString $adminPassword -AsPlainText -Force
            New-LocalUser -Name $adminUser -Password $password -FullName "CTE Admin" -Description "Local admin account for CTE"
            Add-LocalGroupMember -Group "Administrators" -Member $adminUser
            Write-Info "Local user '$adminUser' created and added to Administrators group."
        }
    } catch {
        Write-Error "Failed to create local user '$adminUser': $_"
    }

    # Scheduled Tasks Setup
    try {
        $taskFolder = "GitecOps"
        $tasks = @(
            @{ Name = "Initialize";       Path = Join-Path $BaseDir "scripts\GitecOpsInit.ps1"; Trigger = "Startup" },
            @{ Name = "DailyRun";   Path = Join-Path $BaseDir "scripts\DailyRun.ps1";     Trigger = "Daily";  Time = "12:00PM" },
            @{ Name = "WeeklyRun";  Path = Join-Path $BaseDir "scripts\WeeklyRun.ps1";    Trigger = "Weekly"; Time = "08:00AM"; DaysOfWeek = "Monday" }
        )

        foreach ($task in $tasks) {
            Set-TaskAction -taskFolder $taskFolder `
                           -taskName $task.Name `
                           -scriptPath $task.Path `
                           -triggerType $task.Trigger `
                           -startTime $task.Time `
                           -daysOfWeek $task.DaysOfWeek
        }
    } catch {
        Write-Error "An error occurred creating tasks: $_"
    } finally {
        Write-Host "Task creation complete."
    }

} catch {
    Write-Error "An error occurred during initialization: $_"
} finally {
    Write-Info "Initialization script completed."
}
