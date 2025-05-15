param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "StartUpLastRun",
    [string]$LogName = "StartUp"
)
function Initialize-GitecModules {
    param (
        [Parameter(Mandatory = $true)][string]$BaseDir
    )

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
    Import-Module -Name "$BaseDir\scripts\modules\CoreHelper.psm1"   -Force -ErrorAction Stop
}

try {
    Initialize-GitecModules -BaseDir $BaseDir
    Set-LogContext -LogName $LogName -IsDebug $IsDebug
    Write-Info "=== StartUp script started ==="
    Set-RunTimestamp -RegKey $RegKey

    Clear-TempFiles
    Ensure-ValidDeviceName
    Install-MeshAgentIfMissing
} catch {
    Write-Error "An error occurred during StartUp: $_"
} finally {
    Write-Info "=== StartUp script completed ==="
}