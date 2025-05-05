<#
.SYNOPSIS
    Creates, removes, and manages local administrator accounts.

.DESCRIPTION
    Provides idempotent creation of local users with secure passwords and ensures they're part of the
    local Administrators group. Also allows clean removal of users when needed.

.EXAMPLE
    $secure = ConvertTo-SecureString "R3db34Rd!1" -AsPlainText -Force
    New-GitecLocalAdmin -Username "cteadmin" -Password $secure

.EXAMPLE
    Remove-GitecLocalAdmin -Username "cteadmin"
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

function Test-GitecUserExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Username
    )

    try {
        return $null -ne (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)
    } catch {
        Write-Log "Failed to check if user '$Username' exists: $_" -Level "ERROR"
        return $false
    }
}

function New-GitecLocalAdmin {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][SecureString]$Password
    )

    try {
        if (-not (Test-GitecUserExists -Username $Username)) {
            New-LocalUser -Name $Username -Password $Password -FullName $Username -PasswordNeverExpires:$true
            Write-Log "Created local user '$Username'" -Level "INFO"
        } else {
            exit 0
        }

        if (-not (Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Username })) {
            Add-LocalGroupMember -Group "Administrators" -Member $Username
            Write-Log "User '$Username' added to Administrators group." -Level "INFO"
        } else {
            Write-Log "User '$Username' is already in the Administrators group." -Level "DEBUG"
        }
    } catch {
        Write-Log "Failed to create or configure user '$Username': $_" -Level "ERROR"
        throw
    }
}

function Remove-GitecLocalAdmin {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Username
    )

    try {
        if (Test-GitecUserExists -Username $Username) {
            Remove-LocalUser -Name $Username
            Write-Log "Removed local user '$Username'" -Level "INFO"
        } else {
            Write-Log "User '$Username' does not exist." -Level "WARN"
        }
    } catch {
        Write-Log "Failed to remove local user '$Username': $_" -Level "ERROR"
        throw
    }
}
