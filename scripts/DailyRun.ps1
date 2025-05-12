param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "DailyLastRun",
    [string]$LogName = "DailyRun"
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
Write-Info "Starting Daily Run script..."

Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
if ($null -eq $?) {
    Write-Error "Failed to set registry key '$RegKey'."
} else {
    Write-Info "Registry key '$RegKey' set successfully."
}

# ===================================================================
# Daily Run script logic goes here
# ===================================================================

try{

    # Example logic: Perform daily maintenance tasks
    Write-Info "Performing daily maintenance tasks..."
    
    # Add your daily tasks here
    # For example, clean up old logs, update software, etc.
    
    Write-Info "Daily maintenance tasks completed successfully."

}
catch{
    Write-Error "An error occurred during Daily Run: $_"
}
finally{
    Write-Info "Daily Run script completed."
}