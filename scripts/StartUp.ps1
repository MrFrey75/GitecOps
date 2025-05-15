param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "StartUpLastRun",
    [string]$LogName = "StartUp"
)

Import-Module -Name "$BaseDir\scripts\modules\CoreHelper.psm1"   -Force -ErrorAction Stop

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