<#
.SYNOPSIS
    Manages 64-bit software installation, uninstallation, and version discovery via registry or external installers.

.DESCRIPTION
    This module scans for system-installed (64-bit only) software in the local machine registry, provides version lookup,
    supports silent uninstallation, and automates the installation of MSI, EXE, or Winget packages.

    It is restricted to 64-bit software listed under:
    HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall

    All actions are optionally logged using LoggingHelper.psm1.

.EXAMPLE
    Get-GitecInstalledSoftware -NameLike "7-Zip"
    # Returns details of installed 64-bit software with matching name

.EXAMPLE
    Get-GitecSoftwareVersion -Name "7-Zip"
    # Returns just the version string of the matching software

.EXAMPLE
    Uninstall-GitecSoftware -NameLike "7-Zip" -Silent
    # Attempts to silently uninstall the target application

.EXAMPLE
    Install-GitecSoftware -InstallerPath "C:\Installers\App.msi" -Type MSI
    # Installs an MSI silently using msiexec

.EXAMPLE
    Install-GitecSoftware -InstallerPath "Google.Chrome" -Type Winget
    # Installs software using Winget by ID

.NOTES
    - This module only searches 64-bit HKLM paths. It excludes WOW6432Node and HKCU installs.
    - Winget install assumes the system has Winget v1.3+ installed and configured.
    - LoggingHelper.psm1 (optional) enables visibility into all operations.
    - Installations and uninstallations run in a new cmd.exe process for compatibility.
    - You must run as admin for most software install/remove operations.
#>


function Import-LoggingIfAvailable {
    if (-not (Get-Command -Name Write-Log -ErrorAction SilentlyContinue)) {
        $logPath = Join-Path $PSScriptRoot "LoggingHelper.psm1"
        if (Test-Path $logPath) {
            Import-Module $logPath -Force
        }
    }
}

Import-LoggingIfAvailable

function Get-GitecInstalledSoftware {
    [CmdletBinding()]
    param(
        [string]$NameLike
    )

    $registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"

    $apps = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and ($null -eq $NameLike -or $_.DisplayName -like "*$NameLike*")
    } | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString

    Write-Log "Queried 64-bit installed software for '$NameLike'" -Level "DEBUG"
    return $apps | Sort-Object DisplayName -Unique
}

function Get-GitecSoftwareVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $app = Get-GitecInstalledSoftware -NameLike $Name | Select-Object -First 1
    return $app.DisplayVersion
}

function Uninstall-GitecSoftware {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$NameLike,
        [switch]$Silent
    )

    $app = Get-GitecInstalledSoftware -NameLike $NameLike | Select-Object -First 1
    if (-not $app) {
        Write-Log "Software '$NameLike' not found for uninstall." -Level "WARN"
        return
    }

    $uninstallCmd = $app.UninstallString
    if (-not $uninstallCmd) {
        Write-Log "No uninstall command found for '$($app.DisplayName)'." -Level "WARN"
        return
    }

    if ($uninstallCmd -match "msiexec\.exe" -and $Silent) {
        $uninstallCmd += " /qn /norestart"
    } elseif ($Silent) {
        $uninstallCmd += " /quiet /norestart"
    }

    if ($PSCmdlet.ShouldProcess($app.DisplayName, "Uninstall")) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $uninstallCmd -Wait
        Write-Log "Uninstalled '$($app.DisplayName)' using command: $uninstallCmd" -Level "INFO"
    }
}

function Install-GitecSoftware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InstallerPath,
        [ValidateSet("MSI", "EXE", "Winget")][string]$Type,
        [string]$Arguments = ""
    )

    try {
        switch ($Type) {
            "MSI" {
                $cmd = "msiexec.exe"
                $installArgs = "/i `"$InstallerPath`" /qn /norestart $Arguments"
            }
            "EXE" {
                $cmd = $InstallerPath
                $installArgs = "$Arguments /quiet /norestart"
            }
            "Winget" {
                $cmd = "winget"
                $installArgs = "install $InstallerPath --silent --accept-package-agreements --accept-source-agreements $Arguments"
            }
        }

        Write-Log "Installing software via $Type : $cmd $installArgs" -Level "INFO"
        Start-Process -FilePath $cmd -ArgumentList $installArgs -Wait -NoNewWindow
    } catch {
        Write-Log "Software installation failed: $_" -Level "ERROR"
        throw
    }
}
