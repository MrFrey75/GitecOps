param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "DailyLastRun",
    [string]$LogName = "DailyRun"
)

. "$BaseDir\scripts\modules\CoreHelper.psm1"

try {
    Initialize-GitecModules -BaseDir $BaseDir
    
    Set-LogContext -LogName $LogName -IsDebug $IsDebug
    Write-Info "=== DailyRun script started ==="
    Install-GitClone
    Set-RunTimestamp -RegKey $RegKey

    Invoke-DailyMaintenance
} catch {
    Write-Error "An error occurred during DailyRun: $_"
} finally {
    Write-Info "=== DailyRun script completed ==="
}