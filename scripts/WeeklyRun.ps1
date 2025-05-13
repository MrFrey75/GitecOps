param (
    [string]$BaseDir     = "C:\GitecOps",
    [bool]$IsDebug       = $true,
    [string]$RegKey      = "WeeklyLastRun",
    [string]$LogName     = "WeeklyRun"
)

#  REMOVE
Copy-Item -Path "D:\GitecOps\scripts\*" -Destination "C:\GitecOps\scripts\" -Recurse -Force
#  REMOVE

# Build module paths
$moduleDirectory     = Join-Path -Path $BaseDir -ChildPath "scripts\modules"
$loggingModulePath   = Join-Path -Path $moduleDirectory -ChildPath "LoggingHelper.psm1"
$utilityModulePath   = Join-Path -Path $moduleDirectory -ChildPath "Utilities.psm1"
$registryModulePath  = Join-Path -Path $moduleDirectory -ChildPath "RegistryHelper.psm1"

# Add to PSModulePath if not already present
if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
    $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
}

# Import required modules
try {
    Import-Module -Name $loggingModulePath  -Force -ErrorAction Stop
    Import-Module -Name $utilityModulePath  -Force -ErrorAction Stop
    Import-Module -Name $registryModulePath -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# Configure logging
Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
Write-Info "=== Weekly Run script started ==="

# Record the last run timestamp
try {
    Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
    Write-Info "Registry key '$RegKey' set successfully."
} catch {
    Write-Error "Error setting registry key '$RegKey': $_"
}

# ===============================
# Main Weekly Task Logic Block
# ===============================
try {
    Write-Info "Performing weekly tasks..."

    # ===========================
    # Windows Updates
    # ===========================
    try {
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Info "Installing PSWindowsUpdate module..."
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
        }

        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        Write-Info "PSWindowsUpdate module imported successfully."

        $windowsUpdates = Get-WindowsUpdate -AcceptAll -IgnoreReboot

        if ($windowsUpdates) {
            Write-Info "Installing available Windows updates..."
            #Install-WindowsUpdate -AcceptAll -IgnoreReboot
        } else {
            Write-Info "No Windows updates available."
        }
    } catch {
        Write-Error "Windows Update step failed: $_"
    }

    # ===========================
    # Weekly Maintenance Tasks
    # ===========================
    Write-Info "Running weekly maintenance tasks..."

    # Add weekly operations here (examples below):
    # Invoke-SoftwareUpdater -DryRun:$false
    # Clean-OldLogs -LogDir "C:\GitecOps\Logs" -Days 30
    # Optimize-Database -Path "C:\GitecOps\data.db"

    Write-Info "Weekly maintenance tasks completed."

} catch {
    Write-Error "An error occurred during Weekly Run: $_"
} finally {
    Write-Info "=== Weekly Run script completed ==="
}
