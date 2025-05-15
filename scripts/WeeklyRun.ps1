param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "WeeklyLastRun",
    [string]$LogName = "WeeklyRun"
)

. "$BaseDir\scripts\modules\CoreHelper.psm1"

try {
    Initialize-GitecModules -BaseDir $BaseDir
    Set-LogContext -LogName $LogName -IsDebug $IsDebug
    Write-Info "=== WeeklyRun script started ==="
    Set-RunTimestamp -RegKey $RegKey

    Install-WindowsUpdate
} catch {
    Write-Error "An error occurred during WeeklyRun: $_"
} finally {
    Write-Info "=== WeeklyRun script completed ==="
}