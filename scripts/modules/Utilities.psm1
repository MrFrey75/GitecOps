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