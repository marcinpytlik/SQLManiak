# DBACentralRepository.Common

Wspólny moduł PowerShell dla wszystkich kolektorów i eksporterów.

## Eksportowane funkcje

```text
New-DBACentralSqlConnection
Invoke-DBACentralDataTable
Invoke-DBACentralNonQuery
Invoke-DBACentralScalar
Write-DBACentralBulkCopy
Add-DBACentralCommonColumns
Add-DBACentralScanIdentityColumns
ConvertFrom-DBACentralDataTable
ConvertTo-DBACentralSafePathName
ConvertTo-DBACentralHtml
Get-DBACentralDataRowValue
```

## Test załadowania

```powershell
Import-Module `
    '.\modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1' `
    -Force

Get-Command -Module DBACentralRepository.Common
```

## Test DataTable

```powershell
$table = Invoke-DBACentralDataTable `
    -ServerInstance 'scrambler\sql2022' `
    -DatabaseName 'DBACentralRepository' `
    -Sql 'SELECT TOP (5) * FROM dbo.Instance;'

$table.GetType().FullName
$table.Rows.Count
```

Oczekiwany typ:

```text
System.Data.DataTable
```
