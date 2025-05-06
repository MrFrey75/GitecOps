<#
.SYNOPSIS
    Provides helper functions to manage credentials stored in Windows Credential Manager
    under the "GitecOps:" namespace.

.DESCRIPTION
    This module allows secure storage, retrieval, and removal of credentials using the
    native cmdkey.exe tool and CredentialManager PowerShell module. All credentials are
    stored under the prefix "GitecOps:" for organizational consistency.

    Optional integration with LoggingHelper.psm1 provides consistent output and diagnostics.

.EXAMPLE
    $cred = Get-Credential
    Set-GitecCredential -Name "EntraAdmin" -Credential $cred

    # Retrieve credential later
    $stored = Get-GitecCredential -Name "EntraAdmin"

    # Use it for a secure API call or authentication
    Invoke-RestMethod -Uri $url -Credential $stored

.EXAMPLE
    Remove-GitecCredential -Name "EntraAdmin"

.NOTES
    - Credentials are stored in Windows Credential Manager under the "GitecOps:" prefix.
    - Requires the `CredentialManager` module to retrieve credentials.
    - Compatible with both user and system context (cmdkey supports system storage).
    - LoggingHelper.psm1 (optional) enables structured logging for all operations.
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

function Set-GitecCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][System.Management.Automation.PSCredential]$Credential
    )

    $target = "GitecOps:$Name"

    try {
        cmdkey.exe /add:$target /user:$Credential.UserName /pass:($Credential.GetNetworkCredential().Password) | Out-Null
        Write-Log "Credential saved for $target" -Level "INFO"
    } catch {
        Write-Log "Failed to save credential for $target : $_" -Level "ERROR"
        throw
    }
}

function Get-GitecCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $target = "GitecOps:$Name"

    try {
        if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
            Import-Module CredentialManager -ErrorAction Stop
        }

        $cred = Get-StoredCredential -Target $target
        if ($cred) {
            Write-Log "Credential retrieved for $target" -Level "DEBUG"
            return New-Object System.Management.Automation.PSCredential (
                $cred.UserName,
                ($cred.Password | ConvertTo-SecureString -AsPlainText -Force)
            )
        } else {
            Write-Log "No credential found for $target" -Level "WARN"
            return $null
        }
    } catch {
        Write-Log "Failed to retrieve credential for $target : $_" -Level "ERROR"
        return $null
    }
}

function Remove-GitecCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $target = "GitecOps:$Name"

    try {
        cmdkey.exe /delete:$target | Out-Null
        Write-Log "Credential removed for $target" -Level "INFO"
    } catch {
        Write-Log "Failed to remove credential for $target : $_" -Level "ERROR"
        throw
    }
}
