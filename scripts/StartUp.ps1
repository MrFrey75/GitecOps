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
    $script:CoreHelperModulePath   = Join-Path $moduleDirectory "GitecOps.psm1"

    if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
        $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
    }

    Import-Module -Name $script:CoreHelperModulePath   -Force -ErrorAction Stop
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