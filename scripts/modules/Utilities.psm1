function Add-ToPSModulePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Prepend
    )

    # Normalize and split current PSModulePath
    $normalizedPath = (Resolve-Path -Path $Path).Path
    $currentPaths = $env:PSModulePath -split ';'

    if ($currentPaths -notcontains $normalizedPath) {
        $env:PSModulePath = if ($Prepend) {
            "$normalizedPath;$env:PSModulePath"
        } else {
            "$env:PSModulePath;$normalizedPath"
        }
    }
}

function Invoke-DiskSpaceCleanup {
    param (
        [string]$TempPath = "C:\Windows\Temp",
        [switch]$DryRun
    )

    Write-Info "Checking disk space on drive C:..."

    try {
        $disk = Get-PSDrive -Name C
        $usedGB = [math]::Round($disk.Used / 1GB, 2)
        $freeGB = [math]::Round($disk.Free / 1GB, 2)

        Write-Info "Drive C: Used = $usedGB GB, Free = $freeGB GB"

        if ($freeGB -lt 20) {
            Write-Warning "Disk remaining below 20 GB. Cleanup recommended."

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
        } elseif ($usedGB -lt 30) {
            Write-Info "Disk usage below 30 GB. Consider expanding storage."
        } else {
            Write-Info "Disk space within acceptable limits."
        }
    } catch {
        Write-Error "Disk space check failed: $_"
    }
}

function Clean-OldLogs {
    [CmdletBinding()]
    param (
        [string]$LogDir = "C:\GitecOps\Logs",
        [int]$Days = 30,
        [switch]$DryRun
    )

    Write-Info "Cleaning logs older than $Days days in '$LogDir'..."

    try {
        if (-not (Test-Path $LogDir)) {
            Write-Warning "Log directory not found: $LogDir"
            return
        }

        $threshold = (Get-Date).AddDays(-$Days)

        $oldLogs = Get-ChildItem -Path $LogDir -Recurse -File -Force |
                   Where-Object { $_.LastWriteTime -lt $threshold }

        foreach ($log in $oldLogs) {
            if ($DryRun) {
                Write-Warning "DRY RUN: Would remove $($log.FullName)"
            } else {
                Remove-Item -LiteralPath $log.FullName -Force -ErrorAction SilentlyContinue
                Write-Info "Deleted $($log.FullName)"
            }
        }

        Write-Info "Log cleanup complete. $($oldLogs.Count) files processed."
    } catch {
        Write-Error "Failed during log cleanup: $_"
    }
}

function Update-InstalledApps {
    [CmdletBinding()]
    param (
        [switch]$DryRun
    )

    Write-Info "Checking for application updates..."

    # Placeholder: Extend this to real software sources or package managers
    $apps = @("7-Zip", "VLC media player", "Google Chrome")

    foreach ($app in $apps) {
        if ($DryRun) {
            Write-Warning "DRY RUN: Would check/update $app"
        } else {
            Write-Info "Simulated update for: $app"
            # Real logic might invoke winget, Chocolatey, or vendor installers
        }
    }

    Write-Info "Application update process completed."
}

function Rotate-Snapshots {
    [CmdletBinding()]
    param (
        [string]$SnapshotPath = "C:\GitecOps\Snapshots",
        [int]$MaxSnapshots = 5,
        [switch]$DryRun
    )

    Write-Info "Rotating snapshots in '$SnapshotPath'..."

    try {
        if (-not (Test-Path $SnapshotPath)) {
            Write-Warning "Snapshot path not found: $SnapshotPath"
            return
        }

        $snapshots = Get-ChildItem -Path $SnapshotPath -Directory |
                     Sort-Object LastWriteTime -Descending

        if ($snapshots.Count -le $MaxSnapshots) {
            Write-Info "No rotation needed. $($snapshots.Count) snapshots present."
            return
        }

        $toDelete = $snapshots | Select-Object -Skip $MaxSnapshots

        foreach ($snap in $toDelete) {
            if ($DryRun) {
                Write-Warning "DRY RUN: Would delete snapshot $($snap.FullName)"
            } else {
                Remove-Item -LiteralPath $snap.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Info "Deleted snapshot: $($snap.FullName)"
            }
        }

        Write-Info "Snapshot rotation complete."
    } catch {
        Write-Error "Snapshot rotation failed: $_"
    }
}

function Backup-Configs {
    [CmdletBinding()]
    param (
        [string[]]$PathsToBackup = @(
            "C:\GitecOps\config.json",
            "C:\GitecOps\settings.ini"
        ),
        [string]$BackupDir = "C:\GitecOps\Backups",
        [switch]$DryRun
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupTarget = Join-Path -Path $BackupDir -ChildPath "ConfigBackup-$timestamp"

    Write-Info "Backing up configs to '$backupTarget'..."

    try {
        if (-not (Test-Path $BackupDir)) {
            if ($DryRun) {
                Write-Warning "DRY RUN: Would create backup directory '$BackupDir'"
            } else {
                New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            }
        }

        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $backupTarget -Force | Out-Null
        }

        foreach ($path in $PathsToBackup) {
            if (Test-Path $path) {
                $dest = Join-Path $backupTarget (Split-Path $path -Leaf)

                if ($DryRun) {
                    Write-Warning "DRY RUN: Would copy '$path' to '$dest'"
                } else {
                    Copy-Item -Path $path -Destination $dest -Force
                    Write-Info "Backed up: $path"
                }
            } else {
                Write-Warning "Config path not found: $path"
            }
        }

        Write-Info "Backup process complete."
    } catch {
        Write-Error "Backup failed: $_"
    }
}
