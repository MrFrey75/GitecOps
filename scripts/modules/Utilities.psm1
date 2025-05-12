function Add-ToPSModulePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [switch]$Prepend
    )

    # Normalize and split current PSModulePath
    $normalizedPath = (Resolve-Path -Path $Path).Path
    $currentPaths = $env:PSModulePath -split ';'

    if ($currentPaths -notcontains $normalizedPath) {
        if ($Prepend) {
            $env:PSModulePath = "$normalizedPath;$env:PSModulePath"
        } else {
            $env:PSModulePath = "$env:PSModulePath;$normalizedPath"
        }
    }
}

function Invoke-DiskSpaceCleanup {
    param (
        [int64]$HighThresholdGB = 80,
        [int64]$LowThresholdGB  = 20,
        [string]$TempPath = "C:\Windows\Temp",
        [switch]$DryRun
    )

    try {
        $disk = Get-PSDrive -Name C
        $usedGB = [math]::Round($disk.Used / 1GB, 2)
        $freeGB = [math]::Round($disk.Free / 1GB, 2)

        Write-Info "Drive C: Used = $usedGB GB, Free = $freeGB GB"

        if ($usedGB -gt $HighThresholdGB) {
            Write-Warning "Disk usage above $HighThresholdGB GB. Cleanup recommended."

            if (Test-Path $TempPath) {
                if ($DryRun) {
                    Write-Warning "DRY RUN: Would remove contents of $TempPath"
                    Get-ChildItem "$TempPath\*" -Recurse -Force -ErrorAction SilentlyContinue |
                        Select-Object FullName, LastWriteTime | Format-Table -AutoSize
                } else {
                    Write-Info "Cleaning $TempPath..."
                    Remove-Item "$TempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Info "Temporary files cleaned up."
                }
            } else {
                Write-Error "Temp path '$TempPath' not found."
            }
        } elseif ($usedGB -lt $LowThresholdGB) {
            Write-Info "Disk usage below $LowThresholdGB GB. Consider expanding storage."
        } else {
            Write-Info "Disk space within acceptable limits."
        }
    } catch {
        Write-Error "Disk space check failed: $_"
    }
}

function Remove-InactiveUserProfiles {
    param (
        [string]$UsersRoot = "C:\Users",
        [int]$DaysInactive = 90,
        [string[]]$ExcludedUsers = @(
            'Public', 'Default', 'Default User', 'All Users',
            'cteadmin', 'DefaultAppPool', 'ArthurFrey'
        ),
        [switch]$DryRun
    )

    $threshold = (Get-Date).AddDays(-$DaysInactive)
    $deletedCount = 0

    $userFolders = Get-ChildItem $UsersRoot -Directory |
                   Where-Object { $ExcludedUsers -notcontains $_.Name }

    foreach ($folder in $userFolders) {
        $userFolder = $folder.FullName
        $userName = $folder.Name

        Write-Info "Scanning: $userFolder"

        try {
            $latest = Get-ChildItem $userFolder -Recurse -Force -ErrorAction SilentlyContinue |
                      Where-Object { -not $_.PSIsContainer } |
                      Sort-Object LastWriteTime -Descending |
                      Select-Object -First 1

            if ($latest) {
                $lastActive = $latest.LastWriteTime
                $shouldDelete = $lastActive -lt $threshold

                [PSCustomObject]@{
                    User         = $userName
                    LastActivity = $lastActive
                    Path         = $latest.FullName
                    Action       = if ($shouldDelete) { if ($DryRun) { "Would Delete" } else { "Deleting" } } else { "Preserving" }
                } | Format-Table -AutoSize

                if ($shouldDelete) {
                    if ($DryRun) {
                        Write-Warning "DRY RUN: Would delete $userFolder (Last Active: $lastActive)"
                    } else {
                        Write-Warning "Deleting $userFolder (Last Active: $lastActive)"
                        Remove-Item -LiteralPath $userFolder -Recurse -Force -ErrorAction SilentlyContinue
                        $deletedCount++
                    }
                }
            } else {
                Write-Warning "No files found in $userFolder – skipping."
            }
        } catch {
            Write-Error "Error reading $userFolder : $_"
        }
    }

    if ($DryRun) {
        Write-Info "`nDRY RUN complete. No folders were deleted."
    } else {
        Write-Info "`nTotal deleted: $deletedCount"
    }
}