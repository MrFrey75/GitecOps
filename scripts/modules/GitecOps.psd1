@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'GitecOps.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = '{00000000-0000-0000-0000-000000000001}'

    # Author of this module
    Author = 'Arthur'

    # Company or vendor of this module
    CompanyName = 'GitecOps'

    # Description of the functionality provided by this module
    Description = 'Provides logging, system cleanup, Git operations, registry access, device naming, and file utilities for GitecOps management.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = '*'

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = '*'

    # Private data to pass to the module specified in RootModule
    PrivateData = @{}

    # Default command prefix to prevent name conflicts
    DefaultCommandPrefix = 'Gitec'
}