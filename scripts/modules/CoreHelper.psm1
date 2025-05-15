function Set-RunTimestamp {
    param (
        [Parameter(Mandatory = $true)][string]$RegKey
    )
    try {
        Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
        Write-Info "Registry key '$RegKey' set successfully."
    } catch {
        Write-Error "Error setting registry key '$RegKey': $_"
    }
}

function Clear-TempFiles {
    Write-Host "Clearing temporary files..."
    $tempPath = [System.IO.Path]::GetTempPath()
    try {
        Get-ChildItem -Path $tempPath -Recurse -Force | Remove-Item -Force -Recurse
        Write-Info "Temporary files cleared successfully."
    } catch {
        Write-Host "Failed to clear temporary files: $_" -ForegroundColor Yellow
    }
}

function Set-LogContext {
    param (
        [Parameter(Mandatory = $true)][string]$LogName,
        [Parameter(Mandatory = $true)][bool]$IsDebug
    )
    Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
}

function Install-GitClone {
    Write-Host "Using Git to clone the repository..."

    $repoPath = "C:\GitecOps"
    if (Test-Path $repoPath) {
        Write-Host "Repository already exists. Pulling latest changes..."
        try {
            Push-Location $repoPath
            git reset --hard HEAD
            git clean -fd
            git pull --rebase
            Pop-Location
            Write-Info "Repository updated successfully."
        } catch {
            Write-Host "Failed to pull latest changes: $_" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "Cloning repository..."
        try {
            git clone $GitRepository $repoPath
            Write-Info "Repository cloned successfully."
        } catch {
            Write-Host "Failed to clone repository: $_" -ForegroundColor Yellow
            return $false
        }
    }
    return $true
}
