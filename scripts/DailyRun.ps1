param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "DailyLastRun",
    [string]$LogName = "DailyRun"
)

# Construct module paths
$scriptDirectory    = Join-Path $BaseDir "scripts"
$moduleDirectory     = Join-Path $scriptDirectory "modules"
$asetsDirectory     = Join-Path $scriptDirectory "assets"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"
$deviceModulePath    = Join-Path $moduleDirectory "DeviceHelper.psm1"

# Import required modules
Import-Module -Name $utilityModulePath   -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath   -Force -ErrorAction Stop
Import-Module -Name $registryModulePath  -Force -ErrorAction Stop
Import-Module -Name $deviceModulePath    -Force -ErrorAction Stop

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

    Invoke-DiskSpaceCleanup

    Write-Info "All maintenance tasks completed successfully."

} catch {
    Write-Error "Unhandled error during maintenance tasks: $_"
} finally {
    Write-Info "=== DailyRun.ps1 complete ==="
}
