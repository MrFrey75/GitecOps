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


#  REMOVE === vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv 

function Copy-ToProd {
    param (
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    Get-ChildItem -Path $SourcePath -Recurse -Force | ForEach-Object {

        $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart('\')
        $targetPath = Join-Path $DestinationPath $relativePath

        if ($_.PSIsContainer) {
            if (-not (Test-Path $targetPath)) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            }
        } else {
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $targetPath -Force
        }

    }
}

Copy-ToProd -SourcePath "D:\GitecOps\scripts\modules" -DestinationPath $moduleDirectory
Copy-ToProd -SourcePath "D:\GitecOps\assets" -DestinationPath $asetsDirectory
Copy-ToProd -SourcePath "D:\GitecOps\assets\MeshCentral" -DestinationPath (Join-Path $asetsDirectory "MeshCentral")

#  REMOVE === ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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

    $DeviceName = $Env:COMPUTERNAME
    $Room = ($DeviceName.Split("-")[1] -replace '\D', '')
    
    if ($Room -match '^\d{3}$') {
        Install-MeshAgent -Room $Room
    }

    Invoke-DiskSpaceCleanup

    Write-Info "All maintenance tasks completed successfully."

} catch {
    Write-Error "Unhandled error during maintenance tasks: $_"
} finally {
    Write-Info "=== DailyRun.ps1 complete ==="
}
