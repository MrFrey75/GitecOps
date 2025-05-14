param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "StartUpLastRun",
    [string]$LogName = "StartUp"
)

# Construct module paths
$scriptDirectory    = Join-Path $BaseDir "scripts"
$moduleDirectory     = Join-Path $scriptDirectory "modules"
$asetsDirectory     = Join-Path $scriptDirectory "assets"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"
$deviceModulePath    = Join-Path $moduleDirectory "DeviceHelper.psm1"

#  REMOVE === vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv 

function Copy-ToProd {
    param (
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source path '$SourcePath' does not exist."
        return
    }
    if (-not (Test-Path $DestinationPath)) {
        Write-Info "Destination path '$DestinationPath' does not exist. Creating..."
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    Get-ChildItem -Path $SourcePath -Recurse -Force | ForEach-Object {
        try {
            $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart('\')
            $targetPath = Join-Path $DestinationPath $relativePath

            if ($_.PSIsContainer) {
                if (-not (Test-Path $targetPath)) {
                    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                    Write-Info "Created directory: $targetPath"
                }
            } else {
                $targetDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $targetPath -Force
                Write-Info "Copied: $($_.FullName) → $targetPath"
            }
        } catch {
            Write-Warning "Error copying '$($_.FullName)': $_"
        }
    }
}

Copy-ToProd -SourcePath "D:\GitecOps\scripts\modules" -DestinationPath $moduleDirectory
Copy-ToProd -SourcePath "D:\GitecOps\assets" -DestinationPath $asetsDirectory
Copy-ToProd -SourcePath "D:\GitecOps\assets\MeshCentral" -DestinationPath (Join-Path $asetsDirectory "MeshCentral")

#  REMOVE === ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

# Add to PSModulePath if not already there
if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
    $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
}

# Import modules
Import-Module $utilityModulePath -Force -ErrorAction Stop
Import-Module $loggingModulePath -Force -ErrorAction Stop
Import-Module $registryModulePath -Force -ErrorAction Stop
Import-Module $deviceModulePath -Force -ErrorAction Stop

# Record the last run timestamp
try {
    Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
    Write-Info "Registry key '$RegKey' set successfully."
} catch {
    Write-Error "Error setting registry key '$RegKey': $_"
}

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