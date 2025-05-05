# ==========================================
# GITEC Start Script – Module Import Section
# ==========================================

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Join-Path $scriptRoot "modules"

# List of all module files to import
$gitecModules = @(
    "LoggingHelper",
    "FileDirectoryHelper",
    "CredentialHelper",
    "DiskHelper",
    "EnvVarHelper",
    "RegistryHelper",
    "ScheduledTaskHelper",
    "ServiceHelper",
    "SoftwareHelper",
    "UpdateHelper",
    "HPAssetHelper",
    "LocalAdminHelper",
    "GitVersionHelper"
)

function Install-GitWithRetries {
    param (
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )

    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {
        $attempt++
        Write-Log "Attempt $attempt : Installing Git via winget..." -Level "INFO"

        try {
            winget install --id Git.Git -e --source winget `
                --accept-package-agreements --accept-source-agreements --silent

            Start-Sleep -Seconds 5

            if (Get-Command git.exe -ErrorAction SilentlyContinue) {
                $version = git --version
                Write-Log "Git installed successfully on attempt $attempt : $version" -Level "INFO"
                $success = $true
            } else {
                Write-Log "Git not found after install attempt $attempt." -Level "WARNING"
                if ($attempt -lt $MaxRetries) {
                    Write-Log "Retrying in $DelaySeconds seconds..." -Level "INFO"
                    Start-Sleep -Seconds $DelaySeconds
                }
            }
        } catch {
            Write-Log "Error during Git install attempt $attempt : $_" -Level "ERROR"
            if ($attempt -lt $MaxRetries) {
                Write-Log "Retrying in $DelaySeconds seconds..." -Level "INFO"
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }

    if (-not $success) {
        Write-Log "Git installation failed after $MaxRetries attempts." -Level "ERROR"
        exit 3
    }
}

# Attempt to import each module, log or display any issues
foreach ($mod in $gitecModules) {
    $modPath = Join-Path $moduleRoot "$mod.psm1"

    if (Test-Path $modPath) {
        try {
            Import-Module $modPath -Force -ErrorAction Stop
            Write-Host "Loaded: $mod" -ForegroundColor Green
        } catch {
            Write-Host "Failed to load module: $mod ($($_.Exception.Message))" -ForegroundColor Red
        }
    } else {
        Write-Host "Module not found: $modPath" -ForegroundColor Yellow
    }
}

# ==========================================
# GITEC Start Script – Main Execution Section
# ==========================================


# --------------------------------------
# --- Create Local Admin ---

try {
    $adminUser = "cteadmin"
    $adminPassword = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force

    # Check if the local admin account already exists
    if (-not (Test-GitecUserExists -Username $adminUser)) {
        Write-Log "Creating local admin account '$adminUser'..." -Level "INFO"
        New-GitecLocalAdmin -Username $adminUser -Password $adminPassword -ErrorAction Stop
    }

} catch {
    Write-Log "Failed to create local admin: $_" -Level "ERROR"
    exit 1
}

# ==========================================
# Install Git if not already installed

Install-GitWithRetries -MaxRetries 3 -DelaySeconds 5

# ==========================================
# Install Chocolatey if not already installed

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Chocolatey is not installed. Installing..." -Level "INFO"
    $chocoInstallScript = "https://chocolatey.org/install.ps1"
    try {
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString($chocoInstallScript)
        Write-Log "Chocolatey installed successfully." -Level "INFO"
    } catch {
        Write-Log "Failed to install Chocolatey: $_" -Level "ERROR"
        exit 5
    }
}

# ==========================================
# Check for git repository and clone if not present



