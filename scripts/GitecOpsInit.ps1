param (
    [string]$BaseDir        = "C:\GitecOps",
    [bool]$IsDebug          = $true,
    [string]$RegKey         = "InitLastRun",
    [string]$LogName        = "Initialization",
    [string]$adminUser      = "cteadmin",
    [string]$adminPassword  = "S1lv#rBaCk!1",
    [string]$GitRepository  = "https://github.com/MrFrey75/GitecOps.git"
)

# Ensure script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

# Construct paths
$scriptDirectory     = Join-Path $BaseDir "scripts"
$moduleDirectory     = Join-Path $scriptDirectory "modules"
$assetsDirectory     = Join-Path $scriptDirectory "assets"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"

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
    $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath "\$taskFolder\" -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Info "Scheduled task '$fullTaskName' already exists. Deleting..."
        Unregister-ScheduledTask -TaskName $taskName -TaskPath "\$taskFolder\" -Confirm:$false
    }

    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

    switch ($triggerType) {
        "Startup" {
            $trigger = New-ScheduledTaskTrigger -AtStartup
        }
        "Daily" {
            $trigger = New-ScheduledTaskTrigger -Daily -At ([datetime]::Parse($startTime))
        }
        "Weekly" {
            if (-not $daysOfWeek) {
                throw "Weekly trigger requires -daysOfWeek parameter (e.g., 'Monday')"
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

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -TaskPath "\$taskFolder\" -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -RunLevel Highest
    Write-Info "Scheduled task '$fullTaskName' created successfully."
}

function Install-GitWithWinget {
    Write-Info "Using winget to install or upgrade Git..."
    try {
        $gitInstalled = winget list --name Git.Git -q | Select-String "Git.Git"
        if ($gitInstalled) {
            winget upgrade --id Git.Git --silent --accept-package-agreements --accept-source-agreements
            Write-Info "Git upgrade completed successfully."
        } else {
            winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
            Write-Info "Git installation completed successfully."
        }
    } catch {
        Write-Info "Failed using winget: $_" -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Install-GitClone {
    Write-Host "Using Git to clone the repository..."

    $repoPath = "C:\GitecOps"
    if (Test-Path $repoPath) {
        Write-Host "Repository already exists. Pulling latest changes..."
        try {
            Push-Location $repoPath
            git reset --hard HEAD
            git clean -fd
            git pull --rebase
            Pop-Location
            Write-Info "Repository updated successfully."
        } catch {
            Write-Host "Failed to pull latest changes: $_" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "Cloning repository..."
        try {
            git clone $GitRepository $repoPath
            Write-Info "Repository cloned successfully."
        } catch {
            Write-Host "Failed to clone repository: $_" -ForegroundColor Yellow
            return $false
        }
    }
    return $true
}

function Set-LocalAdminUser {
    param (
        [string]$UserName,
        [string]$Password
    )
    try {
        if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
            Write-Info "Local user '$UserName' already exists."
        } else {
            $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            New-LocalUser -Name $UserName -Password $securePassword -FullName "CTE Admin" -Description "Local admin account for CTE"
            Add-LocalGroupMember -Group "Administrators" -Member $UserName
            Write-Info "Local user '$UserName' created and added to Administrators group."
        }
    } catch {
        Write-Error "Failed to create local user '$UserName': $_"
    }
}

# Import modules
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath -Force -ErrorAction Stop
Import-Module -Name $registryModulePath -Force -ErrorAction Stop

# Configure logging and set registry key
Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
Write-Info "Starting initialization script..."

try {
    Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
    Write-Info "Registry key '$RegKey' set successfully."
} catch {
    Write-Error "Error setting registry key '$RegKey': $_"
}

# Main execution
try {
    Write-Info "Performing initialization tasks..."

    Install-GitWithWinget
    Install-GitClone
    Set-LocalAdminUser -UserName $adminUser -Password $adminPassword

    if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
        $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
        Write-Info "Module directory added to PSModulePath."
    }

    $taskFolder = "GitecOps"
    $tasks = @(
        @{ Name = "Initialize"; Path = Join-Path $scriptDirectory "GitecOpsInit.ps1"; Trigger = "Startup" }
        @{ Name = "DailyRun";   Path = Join-Path $scriptDirectory "DailyRun.ps1";     Trigger = "Daily";  Time = "12:00PM" }
        # @{ Name = "WeeklyRun";  Path = Join-Path $scriptDirectory "WeeklyRun.ps1";    Trigger = "Weekly"; Time = "08:00AM"; DaysOfWeek = "Monday" }
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
    Write-Error "An error occurred during initialization: $_"
} finally {
    Write-Info "Initialization script completed."
}
