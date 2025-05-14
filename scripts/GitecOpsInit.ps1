param (
    [string]$BaseDir        = "C:\GitecOps",
    [bool]$IsDebug          = $true,
    [string]$RegKey         = "InitLastRun",
    [string]$LogName        = "Initialization",
    [string]$adminUser      = "cteadmin",
    [string]$adminPassword  = "S1lv#rBaCk!1",

    [string]$GitRepository = "https://github.com/MrFrey75/GitecOps.git"
)

# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

# Construct module paths
$scriptDirectory    = Join-Path $BaseDir "scripts"
$moduleDirectory     = Join-Path $scriptDirectory "modules"
$asetsDirectory     = Join-Path $scriptDirectory "assets"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"

#  REMOVE === vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv 

function Copy-ToProd {
    param (
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    Get-ChildItem -Path $SourcePath -Recurse -Force | ForEach-Object {

        $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart('\')
        $targetPath = Join-Path $DestinationPath $relativePath

        if ($_.PSIsContainer) {
            if (-not (Test-Path $targetPath)) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            }
        } else {
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $targetPath -Force
        }

    }
}

Copy-ToProd -SourcePath "D:\GitecOps\scripts\modules" -DestinationPath $moduleDirectory
Copy-ToProd -SourcePath "D:\GitecOps\assets" -DestinationPath $asetsDirectory
Copy-ToProd -SourcePath "D:\GitecOps\assets\MeshCentral" -DestinationPath (Join-Path $asetsDirectory "MeshCentral")

#  REMOVE === ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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
        Write-Info "Scheduled task '$fullTaskName' already exists. Deleting..."
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

function Install-GitClone{
    Write-Host "Using Git to clone the repository..."

    # check if repo exists
    $repoPath = "C:\GitecOps"
    $repoExists = Test-Path $repoPath
    if ($repoExists) {
        # pull latest changes
        Write-Host "Repository already exists. Pulling latest changes..."
        try {
            $location = Get-Location
            Set-Location -Path $repoPath
            git reset --hard HEAD
            git clean -fd
            git pull --rebase
            Set-Location -Path $location
            Write-Info "Repository updated successfully."
        } catch {
            Write-Host "Failed to pull latest changes: $_" -ForegroundColor Yellow
            return $false
        }
    } else {
        # clone the repository
        Write-Host "Cloning repository..."
        try {
            $location = Get-Location
            Set-Location -Path $repoPath
            git clone $repoUrl $repoPath
            Set-Location -Path $location
            Write-Info "Repository cloned successfully."
        } catch {
            Write-Host "Failed to clone repository: $_" -ForegroundColor Yellow
            return $false
        }
        
    }
    return $true
}

# Import modules
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath -Force -ErrorAction Stop
Import-Module -Name $registryModulePath -Force -ErrorAction Stop

# Record the last run timestamp
try {
    Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
    Write-Info "Registry key '$RegKey' set successfully."
} catch {
    Write-Error "Error setting registry key '$RegKey': $_"
}

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

    Install-GitWithWinget
    Install-GitClone


    try{
        # Add module path if missing
        if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
            $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
            Write-Info "Module directory added to PSModulePath."
        }
    } catch {
        Write-Error "Failed to add module directory to PSModulePath: $_"
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
            @{ Name = "Initialize";       Path = Join-Path $BaseDir "scripts\GitecOpsInit.ps1"; Trigger = "Startup" }
            ,@{ Name = "DailyRun";   Path = Join-Path $BaseDir "scripts\DailyRun.ps1";     Trigger = "Daily";  Time = "12:00PM" }
            #,@{ Name = "WeeklyRun";  Path = Join-Path $BaseDir "scripts\WeeklyRun.ps1";    Trigger = "Weekly"; Time = "08:00AM"; DaysOfWeek = "Monday" }
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
