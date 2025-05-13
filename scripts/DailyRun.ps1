param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "DailyLastRun",
    [string]$LogName = "DailyRun"
)

#  REMOVE
Copy-Item -Path "D:\GitecOps\scripts\*" -Destination "C:\GitecOps\scripts\" -Recurse -Force
#  REMOVE

# Construct module paths
$moduleDirectory     = Join-Path $BaseDir "scripts\modules"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"

Write-Host "Module Directory: $moduleDirectory"
Write-Host "Logging Module Path: $loggingModulePath"
Write-Host "Utility Module Path: $utilityModulePath"
Write-Host "Registry Module Path: $registryModulePath"


# Import required modules
Import-Module -Name $utilityModulePath   -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath   -Force -ErrorAction Stop
Import-Module -Name $registryModulePath  -Force -ErrorAction Stop

# Configure logging
Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
Write-Info "=== DailyRun.ps1 started ==="

# Record the last run timestamp
try {
    Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
    Write-Info "Registry key '$RegKey' set successfully."
} catch {
    Write-Error "Error setting registry key '$RegKey': $_"
}

# ---------------------------------------
# Run Daily Maintenance Tasks
# ---------------------------------------
try {
    Write-Info "Beginning daily maintenance tasks..."

    # DRY RUN toggle for testing
    $dryRunMode = $false

    Invoke-DiskSpaceCleanup     -DryRun:$dryRunMode

    Write-Info "All maintenance tasks completed successfully."

} catch {
    Write-Error "Unhandled error during maintenance tasks: $_"
} finally {
    Write-Info "=== DailyRun.ps1 complete ==="
}
