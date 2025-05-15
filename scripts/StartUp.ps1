param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "StartUpLastRun",
    [string]$LogName = "StartUp"
)

$script:scriptDirectory     = Join-Path $BaseDir "scripts"
$script:moduleDirectory     = Join-Path $scriptDirectory "modules"
$script:assetsDirectory     = Join-Path $scriptDirectory "assets"
$script:GitecOpsModulePath   = Join-Path $moduleDirectory "GitecOps.psm1"

try {
    Import-Module -Name $script:GitecOpsModulePath   -Force -ErrorAction Stop
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