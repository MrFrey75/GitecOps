param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "StartUpLastRun",
    [string]$LogName = "StartUp"
)

function Initialize-PathsAndModules {
    $script:scriptDirectory     = Join-Path $BaseDir "scripts"
    $script:moduleDirectory     = Join-Path $scriptDirectory "modules"
    $script:assetsDirectory     = Join-Path $scriptDirectory "assets"
    $script:loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
    $script:utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
    $script:registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"
    $script:deviceModulePath    = Join-Path $moduleDirectory "DeviceHelper.psm1"

    if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
        $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
    }

    Import-Module $utilityModulePath -Force -ErrorAction Stop
    Import-Module $loggingModulePath -Force -ErrorAction Stop
    Import-Module $registryModulePath -Force -ErrorAction Stop
    Import-Module $deviceModulePath -Force -ErrorAction Stop
}

function Set-RunTimestamp {
    try {
        Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
        Write-Info "Registry key '$RegKey' set successfully."
    } catch {
        Write-Error "Failed to set registry key '$RegKey': $_"
    }
}

function Clear-TempFiles {
    $tempPath = "C:\Temp"
    try {
        if (Test-Path $tempPath) {
            Remove-Item "$tempPath\*" -Recurse -Force
            Write-Info "Cleared temporary files in $tempPath."
        } else {
            Write-Warning "Temporary path $tempPath does not exist."
        }
    } catch {
        Write-Error "Failed to clear temporary files: $_"
    }
}

function Ensure-ValidDeviceName {
    try {
        $originalName = $env:COMPUTERNAME
        $correctedName = $originalName

        if (Test-CTEAlternateFormat -DeviceName $originalName) {
            Write-Info "Device name $originalName is in alternate format."
            $correctedName = Convert-CTEAlternateFormat -DeviceName $originalName
        }

        if (Test-CTEProperFormat -DeviceName $correctedName) {
            if ($originalName -ne $correctedName) {
                Write-Info "Renaming computer from $originalName to $correctedName."
                Rename-Computer -NewName $correctedName -Force -Restart
            } else {
                Write-Info "Device name $originalName is valid."
            }
        } else {
            Write-Warning "Corrected device name '$correctedName' is not valid."
        }
    } catch {
        Write-Error "Device name validation failed: $_"
    }
}

function Install-MeshAgentIfMissing {
    try {
        if (Test-CTEProperFormat -DeviceName $env:COMPUTERNAME) {
            if (Test-Path "C:\Program Files\Mesh Agent\MeshAgent.exe") {
                Write-Info "Mesh Agent is already installed."
            } else {
                $Room = ($env:COMPUTERNAME.Split("-")[1] -replace '\D', '')
                $meshInstaller = Join-Path $assetsDirectory "MeshCentral\meshagent64-$Room.exe"

                if (Test-Path $meshInstaller) {
                    Write-Info "Installing Mesh Agent from $meshInstaller"
                    Start-Process -FilePath $meshInstaller -ArgumentList "/install" -Wait
                    Write-Info "Mesh Agent installed successfully."
                } else {
                    Write-Warning "Mesh installer not found: $meshInstaller"
                }
            }
        }
    } catch {
        Write-Error "Failed to install Mesh Agent: $_"
    }
}

function Start-StartupTasks {
    Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
    Write-Info "Starting Start Up script..."

    Set-RunTimestamp
    Clear-TempFiles
    Ensure-ValidDeviceName
    Install-MeshAgentIfMissing

    Write-Info "Start-up tasks completed successfully."
}

# Entrypoint
try {
    Initialize-PathsAndModules
    Start-StartupTasks
} catch {
    Write-Error "An error occurred during Start Up: $_"
} finally {
    Write-Info "Start Up script completed."
}
