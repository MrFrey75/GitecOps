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

    # Example logic: Perform weekly maintenance tasks
    Write-Info "Performing weekly maintenance tasks..."
    

    # ===========================================================
    # Update system packages
    # ===========================================================
    $packages = @("git.exe", "powershell.msi")
    foreach ($package in $packages) {
        try{
            $installed = Get-Package -Name $package -ErrorAction SilentlyContinue
            if ($null -eq $installed) {
                Write-Info "Installing package: $package"
                Install-Package -Name $package -Force
            } else {
                Write-Info "Package $package is already installed."
            }
        } catch{
            Write-Error "Failed to update package '$package': $_"
        }

    }

    # ===========================================================
    # Check for Windows updates
    # ===========================================================
    $windowsUpdates = Get-WindowsUpdate -AcceptAll -IgnoreReboot
    if ($windowsUpdates) {
        Write-Info "Installing Windows updates..."
        Install-WindowsUpdate -AcceptAll -IgnoreReboot
    } else {
        Write-Info "No Windows updates available."
    }

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