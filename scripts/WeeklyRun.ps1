param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "WeeklyLastRun",
    [string]$LogName = "WeeklyRun"
)

# Construct module path using Join-Path for cross-platform compatibility
$moduleDirectory = Join-Path -Path $BaseDir -ChildPath "scripts\modules"
$loggingModulePath = Join-Path -Path $moduleDirectory -ChildPath "LoggingHelper.psm1"
$utilityModulePath = Join-Path -Path $moduleDirectory -ChildPath "Utilities.psm1"
$registryModulePath = Join-Path -Path $moduleDirectory -ChildPath "RegistryHelper.psm1"

# Add module directory to PSModulePath if not already present
if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
    $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
}

# Import logging module and configure settings
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath -Force -ErrorAction Stop
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $registryModulePath -Force -ErrorAction Stop

Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug

# Start log
Write-Info "Starting Weekly Run script..."

Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
if ($null -eq $?) {
    Write-Error "Failed to set registry key '$RegKey'."
} else {
    Write-Info "Registry key '$RegKey' set successfully."
}

# ===================================================================
# Weekly Run script logic goes here
# ===================================================================


try{

    Write-Info "Performing weekly tasks..."

    # Example logic: Install Windows updates
    try{
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Info "Installing PSWindowsUpdate module..."
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
        }
    
        # Import the module
        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        Write-Info "PSWindowsUpdate module imported successfully."
    
        $windowsUpdates = Get-WindowsUpdate -AcceptAll -IgnoreReboot
        if ($windowsUpdates) {
            Write-Info "Installing Windows updates..."
            Install-WindowsUpdate -AcceptAll -IgnoreReboot
        } else {
            Write-Info "No Windows updates available."
        }
    } catch{
        Write-Error "Failed to install Windows updates: $_"
    }

    # Example logic: Perform weekly maintenance tasks
    Write-Info "Performing weekly maintenance tasks..."



    # Add your weekly tasks here
    # For example, clean up old logs, update software, etc.
    
    Write-Info "Weekly maintenance tasks completed successfully."


}
catch{
    Write-Error "An error occurred during Weekly Run: $_"
}
finally{
    Write-Info "Weekly Run script completed."
}