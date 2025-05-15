param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "DailyLastRun",
    [string]$LogName = "DailyRun"
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

    Import-Module -Name $utilityModulePath   -Force -ErrorAction Stop
    Import-Module -Name $loggingModulePath   -Force -ErrorAction Stop
    Import-Module -Name $registryModulePath  -Force -ErrorAction Stop
    Import-Module -Name $deviceModulePath    -Force -ErrorAction Stop
}

function Set-RunTimestamp {
    try {
        Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
        Write-Info "Registry key '$RegKey' set successfully."
    } catch {
        Write-Error "Error setting registry key '$RegKey': $_"
    }
}

function Invoke-WindowsUpdateCheck {
    Write-Info "Checking for Windows updates..."

    try {
        $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop
        if ($updates) {
            Write-Info "$($updates.Count) updates found."
        } else {
            Write-Info "No updates available."
        }
    } catch {
        Write-Warning "Windows Update check failed: $_"
    }
}

function Invoke-TempFileCleanup {
    Write-Info "Clearing system and user temp files..."

    $paths = @(
        "$env:TEMP",
        "C:\Windows\Temp",
        "$env:USERPROFILE\AppData\Local\Temp"
    )

    foreach ($path in $paths) {
        try {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Info "Cleared temp files in $path"
            } else {
                Write-Warning "Path not found: $path"
            }
        } catch {
            Write-Warning "Failed to clean temp files in $path : $_"
        }
    }
}

function Test-NetworkConnectivity {
    $targets = @("8.8.8.8", "1.1.1.1", "microsoft.com", "github.com")
    $reachable = $false

    foreach ($target in $targets) {
        Write-Info "Pinging $target..."
        if (Test-Connection -ComputerName $target -Count 2 -Quiet -ErrorAction SilentlyContinue) {
            Write-Info "Connected to $target"
            $reachable = $true
            break
        }
    }

    if (-not $reachable) {
        Write-Warning "No network targets responded. Connectivity may be down."
    }
}

function Test-CriticalServiceStatus {
    $services = @("wuauserv", "bits", "WinDefend", "LanmanWorkstation", "Dhcp")

    foreach ($svc in $services) {
        try {
            $status = Get-Service -Name $svc -ErrorAction Stop
            if ($status.Status -ne 'Running') {
                Write-Warning "Service '$svc' is $($status.Status). Consider investigating."
            } else {
                Write-Info "Service '$svc' is running."
            }
        } catch {
            Write-Warning "Could not check status of service '$svc': $_"
        }
    }
}

function Invoke-DailyMaintenance {
    Write-Info "Beginning daily maintenance tasks..."

    Invoke-DiskSpaceCleanup
    Invoke-WindowsUpdateCheck
    Invoke-TempFileCleanup
    Test-NetworkConnectivity
    Test-CriticalServiceStatus

    Write-Info "All maintenance tasks completed successfully."
}

function Start-DailyRun {
    Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
    Write-Info "=== DailyRun.ps1 started ==="

    Set-RunTimestamp
    Invoke-DailyMaintenance

    Write-Info "=== DailyRun.ps1 complete ==="
}

# Entrypoint
try {
    Initialize-PathsAndModules
    Start-DailyRun
} catch {
    Write-Error "Unhandled error during DailyRun: $_"
}
