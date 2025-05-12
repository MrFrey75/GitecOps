param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "DailyLastRun",
    [string]$LogName = "DailyRun"
)

# Initialize module paths
$moduleDirectory       = Join-Path $BaseDir "scripts\modules"
$loggingModulePath     = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath     = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath    = Join-Path $moduleDirectory "RegistryHelper.psm1"

# Add to PSModulePath if not already included
if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
    $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
}

# Import modules
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath -Force -ErrorAction Stop
Import-Module -Name $registryModulePath -Force -ErrorAction Stop

# Set up logging
Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
Write-Info "Starting Daily Run script..."

# Record last run timestamp
if (-not (Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String)) {
    Write-Error "Failed to set registry key '$RegKey'."
} else {
    Write-Info "Registry key '$RegKey' set successfully."
}

# ------------------------------------------
# Run Daily Tasks
# ------------------------------------------
try {
    Write-Info "Performing daily maintenance tasks..."

    # Toggle dry run mode globally here:
    $dryRunMode = $true

    Invoke-DiskSpaceCleanup -DryRun:$dryRunMode
    Remove-InactiveUserProfiles -DryRun:$dryRunMode

    Write-Info "Daily maintenance tasks completed successfully."
} catch {
    Write-Error "An error occurred during Daily Run: $_"
} finally {
    Write-Info "Daily Run script completed."
}
