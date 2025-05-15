function Initialize-GitecModules {
    param (
        [Parameter(Mandatory = $true)][string]$BaseDir
    )

    $script:scriptDirectory     = Join-Path $BaseDir "scripts"
    $script:moduleDirectory     = Join-Path $scriptDirectory "modules"
    $script:assetsDirectory     = Join-Path $scriptDirectory "assets"
    $script:loggingModulePath   = Join-Path $moduleDirectory "LoggingHelper.psm1"
    $script:utilityModulePath   = Join-Path $moduleDirectory "Utilities.psm1"
    $script:registryModulePath  = Join-Path $moduleDirectory "RegistryHelper.psm1"
    $script:deviceModulePath    = Join-Path $moduleDirectory "DeviceHelper.psm1"

    if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
        $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
    }

    Import-Module -Name $utilityModulePath   -Force -ErrorAction Stop
    Import-Module -Name $loggingModulePath   -Force -ErrorAction Stop
    Import-Module -Name $registryModulePath  -Force -ErrorAction Stop
    Import-Module -Name $deviceModulePath    -Force -ErrorAction Stop
}

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

function Set-LogContext {
    param (
        [Parameter(Mandatory = $true)][string]$LogName,
        [Parameter(Mandatory = $true)][bool]$IsDebug
    )
    Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug
}
