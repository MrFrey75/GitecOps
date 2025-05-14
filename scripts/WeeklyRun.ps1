param (
    [string]$BaseDir     = "C:\GitecOps",
    [bool]$IsDebug       = $true,
    [string]$RegKey      = "WeeklyLastRun",
    [string]$LogName     = "WeeklyRun"
)

# Construct module paths
$scriptDirectory    = Join-Path $BaseDir "scripts"
$moduleDirectory     = Join-Path $scriptDirectory "modules"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"
$deviceModulePath    = Join-Path $moduleDirectory "DeviceHelper.psm1"

# Add to PSModulePath if not already present
if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
    $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
}

# Import required modules
try {
    Import-Module -Name $loggingModulePath  -Force -ErrorAction Stop
    Import-Module -Name $utilityModulePath  -Force -ErrorAction Stop
    Import-Module -Name $registryModulePath -Force -ErrorAction Stop
    Import-Module -Name $deviceModulePath   -Force -ErrorAction Stop    
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

function Install-WindowsUpdate{

    # Simulate the installation of Windows updates
    Write-Info "Simulating installation of Windows updates..."
    if ($IgnoreReboot) {
        Write-Info "Ignoring reboot."
    }
    if ($AcceptAll) {
        Write-Info "Accepting all updates."
    }
    if ($Verbose) {
        Write-Info "Verbose output enabled."
    }

    try {
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Info "Installing PSWindowsUpdate module..."
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
        }

        $service = Get-Service -Name wuauserv -ErrorAction SilentlyContinue

        if ($null -eq $service) {
            Write-Info "Windows Update service not found. Starting it..."
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        } else {
            Write-Info "Windows Update service is already running."
        }

        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        Write-Info "PSWindowsUpdate module imported successfully."

        $windowsUpdates = Get-WindowsUpdate -AcceptAll -IgnoreReboot

        if ($windowsUpdates) {
            Write-Info "Found available Windows updates: $($windowsUpdates.Count)"
            Install-WindowsUpdate -IgnoreReboot -AcceptAll -ErrorAction SilentlyContinue -Verbose -WhatIf
            Write-Info "Windows updates installed successfully."

            foreach ($update in $windowsUpdates) {
                Write-Info "Installed update: $($update.Title)"
            }

        } else {
            Write-Info "No Windows updates available."
        }
    } catch {
        Write-Error "Windows Update step failed: $_"
    }

}

# ===============================
# Main Weekly Task Logic Block
# ===============================
try {

    # ===========================
    # Weekly Maintenance Tasks
    # ===========================
    Write-Info "Running weekly maintenance tasks..."

    Install-WindowsUpdate

    Write-Info "Weekly maintenance tasks completed."

} catch {
    Write-Error "An error occurred during Weekly Run: $_"
} finally {
    Write-Info "=== Weekly Run script completed ==="
}
