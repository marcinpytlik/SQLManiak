@{
    RootModule = 'DBACentralRepository.Common.psm1'
    ModuleVersion = '3.1.0'
    GUID = 'b73fbe28-744e-4cbc-a77b-a1d96e863f95'
    Author = 'Marcin Pytlik'
    CompanyName = 'DBACentralRepository'
    Copyright = '(c) 2026'
    Description = 'Wspólne funkcje SQL, DataTable, BulkCopy, HTML i ścieżek dla DBACentralRepository.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport = @(
        'New-DBACentralSqlConnection',
        'Invoke-DBACentralDataTable',
        'Invoke-DBACentralNonQuery',
        'Invoke-DBACentralScalar',
        'Write-DBACentralBulkCopy',
        'Add-DBACentralCommonColumns',
        'Add-DBACentralScanIdentityColumns',
        'ConvertFrom-DBACentralDataTable',
        'ConvertTo-DBACentralSafePathName',
        'ConvertTo-DBACentralHtml',
        'Get-DBACentralDataRowValue'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('SQLServer', 'DBA', 'Repository', 'Confluence')
            ProjectUri = 'https://github.com/marcinpytlik'
        }
    }
}
