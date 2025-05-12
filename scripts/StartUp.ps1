param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "StartUpLastRun",
    [string]$LogName = "StartUp"
)

# Module paths
$moduleDirectory = Join-Path -Path $BaseDir -ChildPath "scripts\modules"
$loggingModulePath = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath = Join-Path $moduleDirectory "RegistryHelper.psm1"
$deviceModulePath = Join-Path $moduleDirectory "DeviceHelper.psm1"

# Add to PSModulePath if not already there
if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
    $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
}

# Import modules
Import-Module $utilityModulePath -Force -ErrorAction Stop
Import-Module $loggingModulePath -Force -ErrorAction Stop
Import-Module $registryModulePath -Force -ErrorAction Stop
Import-Module $deviceModulePath -Force -ErrorAction Stop

Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
Write-Info "Starting Start Up script..."

# Update registry with run time
Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
if ($null -eq $?) {
    Write-Error "Failed to set registry key '$RegKey'."
} else {
    Write-Info "Registry key '$RegKey' set successfully."
}


# ===================================================
# Start-up logic
# ===================================================

try{
    # Example logic: Perform start-up tasks
    Write-Info "Performing start-up tasks..."
    
    # Clear temp files
    try {
        $tempPath = "C:\Temp"
        if (Test-Path $tempPath) {
            Remove-Item "$tempPath\*" -Recurse -Force
            Write-Info "Cleared temporary files in $tempPath."
        } else {
            Write-Warning "Temporary path $tempPath does not exist."
        }
    } catch {
        Write-Error "Failed to clear temporary files: $_"
    }

    # Validate and correct device name
    try {
        $originalDeviceName = $env:COMPUTERNAME
        $correctedDeviceName = $originalDeviceName

        if (Test-CTEAlternateFormat -DeviceName $originalDeviceName) {
            Write-Info "Device name $originalDeviceName is in the alternate format."
            $correctedDeviceName = Convert-CTEAlternateFormat -DeviceName $originalDeviceName
        }

        if (Test-CTEProperFormat -DeviceName $correctedDeviceName) {
            if ($originalDeviceName -ne $correctedDeviceName) {
                Write-Info "Changing device name from $originalDeviceName to $correctedDeviceName."
                Rename-Computer -NewName $correctedDeviceName -Force -Restart
            } else {
                Write-Info "Device name $originalDeviceName is in the correct format."
            }
        } else {
            Write-Warning "Device name $correctedDeviceName is not in a valid format after conversion."
        }
    } catch {
        Write-Error "Failed during device name validation: $_"
    }
    
    Write-Info "Start-up tasks completed successfully."

}
catch{
    Write-Error "An error occurred during Start Up: $_"
}
finally{
    Write-Info "Start Up script completed."
}