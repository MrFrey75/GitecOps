param (
    [string]$BaseDir = "C:\GitecOps",
    [bool]$IsDebug = $true,
    [string]$RegKey = "InitLastRun",
    [string]$LogName = "Initialization",
    [string]$adminUser = "cteadmin",
    [string]$adminPassword = "S1lv#rBaCk!1"
)

# Construct module path using Join-Path for cross-platform compatibility
$moduleDirectory = Join-Path -Path $BaseDir -ChildPath "scripts\modules"
$loggingModulePath = Join-Path -Path $moduleDirectory -ChildPath "LoggingHelper.psm1"
$utilityModulePath = Join-Path -Path $moduleDirectory -ChildPath "Utilities.psm1"
$registryModulePath = Join-Path -Path $moduleDirectory -ChildPath "RegistryHelper.psm1"



# Import logging module and configure settings
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $loggingModulePath -Force -ErrorAction Stop
Import-Module -Name $utilityModulePath -Force -ErrorAction Stop
Import-Module -Name $registryModulePath -Force -ErrorAction Stop

Set-GitecLogSettings -Name $LogName -ConsoleOutput:$IsDebug

# Start log
Write-Info "Starting initialization script..."

Set-RegistryKey -Name $RegKey -Value (Get-Date) -Type String
if ($null -eq $?) {
    Write-Error "Failed to set registry key '$RegKey'."
} else {
    Write-Info "Registry key '$RegKey' set successfully."
}

# ===================================================================
# Initialization script logic goes here
# ===================================================================

try{

    # Example logic: Perform initialization tasks
    Write-Info "Performing initialization tasks..."


    # ===========================================================
    # Add module directory to PSModulePath if not already present
    # ===========================================================

    try{
        if (-not ($env:PSModulePath -split ";" | Where-Object { $_ -eq $moduleDirectory })) {
            $env:PSModulePath = "$moduleDirectory;$env:PSModulePath"
        } 
        Write-Info "Module directory added to PSModulePath."
    } catch{
        Write-Error "Failed to add module directory to PSModulePath: $_"
    }
    
    # ===========================================================
    # Create local Admin user "cteadmin" / "S1lv#rBaCk!1"
    # ===========================================================

    try{
    # Check if the user already exists
        if (Get-LocalUser -Name $adminUser -ErrorAction SilentlyContinue) {
            Write-Info "Local user '$adminUser' already exists."
        } else {
            $password = ConvertTo-SecureString $adminPassword -AsPlainText -Force
            New-LocalUser -Name $adminUser -Password $password -FullName "CTE Admin" -Description "Local admin account for CTE"
            Add-LocalGroupMember -Group "Administrators" -Member $adminUser
            Write-Info "Local user '$adminUser' created and added to Administrators group."
        }
        
        Write-Info "Initialization tasks completed successfully."

    } catch{
        Write-Error "Failed to create local user '$adminUser': $_"
    }
}
catch{
    Write-Error "An error occurred during initialization: $_"
}
finally{
    Write-Info "Initialization script completed."
}
