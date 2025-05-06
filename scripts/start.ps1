
$repoUrl = "https://github.com/MrFrey75/GitecOps.git"
$repoName = "GitecOps"
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

# ==========================================
# GitecOps Start Script – Module Import Section
# ==========================================

$baseRoot = Join-Path "c:/" $repoName
$scriptRoot = Join-Path $baseRoot "scripts"
$moduleRoot = Join-Path $scriptRoot "modules"
$assetsRoot = Join-Path $baseRoot "assets"
$packagesRoot = Join-Path $baseRoot "packages"


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
# GitecOps Start Script – Main Execution Section
# ==========================================


# --------------------------------------
# --- Create Local Admin ---

$isInstalled = Get-GitecRegistryValue -SubPath "Client" -Name "GITECOPS"

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

if($null -eq $isInstalled) {
    Write-Log "GITECOPS is not installed." -Level "INFO"

    $oldDirs = @(
        "GITEC",
        "GitecOps",
        "gitecshell",
        "gitecshellx"
    )

    # Remove Old Directory if it exists
    foreach ($dir in $oldDirs) {
        $oldDirPath = Join-Path "C:/" $dir
        if (Test-Path $oldDirPath) {
            Write-Log "Removing old directory $oldDirPath..." -Level "INFO"
            Remove-Item $oldDirPath -Recurse -Force
        }
    }
} else {
    Write-Log "GITECOPS is already installed." -Level "INFO"
}


# ==========================================
# Check for git repository and clone if not present

if (-not (Test-Path $repoName)) {
    Write-Log "Cloning repository from $repoUrl..." -Level "INFO"
    try {
        Set-Location "C:/"
        git clone $repoUrl
        Write-Log "Repository cloned successfully." -Level "INFO"
        New-GitecRegistryKey -SubPath "Client" -Name "GIT" -Value "1"
    } catch {
        Write-Log "Failed to clone repository: $_" -Level "ERROR"
        New-GitecRegistryKey -SubPath "Client" -Name "GIT" -Value "0"
        exit 6
    }
}

# ==========================================
#  Make sure git repo is up to date
# ==========================================

try {
    Set-Location "C:/"
    git -C $baseRoot pull origin main
} catch {
    Write-Log "Failed to update repository: $_" -Level "ERROR"
    exit 7
}



