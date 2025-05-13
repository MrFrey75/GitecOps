param (
    [string]$BaseDir     = "C:\GitecOps",
    [bool]$IsDebug       = $true,
    [string]$RegKey      = "WeeklyLastRun",
    [string]$LogName     = "WeeklyRun"
)

# Construct module paths
$scriptDirectory    = Join-Path $BaseDir "scripts"
$moduleDirectory     = Join-Path $scriptDirectory "modules"
$asetsDirectory     = Join-Path $scriptDirectory "assets"
$loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
$utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
$registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"

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
            Install-WindowsUpdate -AcceptAll -IgnoreReboot
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

    Write-Info "Weekly maintenance tasks completed."

} catch {
    Write-Error "An error occurred during Weekly Run: $_"
} finally {
    Write-Info "=== Weekly Run script completed ==="
}
