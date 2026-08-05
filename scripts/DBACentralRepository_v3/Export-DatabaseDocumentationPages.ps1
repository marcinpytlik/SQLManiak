[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$OutputPath =
        (Join-Path $PSScriptRoot 'ConfluenceExport\03. Dokumentacja baz'),

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [int]$CommandTimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path `
    $PSScriptRoot `
    'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

Import-Module -Name $modulePath -Force -ErrorAction Stop


function Invoke-RepositoryTable {
    param(
        [Parameter(Mandatory)]
        [string]$Sql,

        [hashtable]$Parameters = @{}
    )

    Invoke-DBACentralDataTable `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Sql $Sql `
        -Credential $RepositorySqlCredential `
        -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository Database Documentation'
}


function Invoke-RepositoryNonQuery {
    param(
        [Parameter(Mandatory)]
        [string]$Sql,

        [hashtable]$Parameters = @{}
    )

    [void](Invoke-DBACentralNonQuery `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Sql $Sql `
        -Credential $RepositorySqlCredential `
        -Parameters $Parameters `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository Database Documentation')
}


function Convert-TableToHtmlFragment {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$Table
    )

    if ($Table.Rows.Count -eq 0) {
        return '<div class="empty">Brak danych.</div>'
    }

    $objects = @(
        ConvertFrom-DBACentralDataTable -DataTable $Table
    )

    return (
        $objects |
        ConvertTo-Html -Fragment
    ) -join [Environment]::NewLine
}


function Get-RowValue {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataRow]$Row,

        [Parameter(Mandatory)]
        [string]$Name
    )

    Get-DBACentralDataRowValue -Row $Row -ColumnName $Name
}


[System.IO.Directory]::CreateDirectory($OutputPath) | Out-Null

Invoke-RepositoryNonQuery `
    -Sql 'EXEC [db].[usp_SyncDatabaseDocumentationRegistry];'

$databases = Invoke-RepositoryTable -Sql @'
SELECT *
FROM [report].[vDatabaseDocumentationPages]
WHERE [DatabaseName] NOT IN
(
    N'master',N'model',N'msdb',N'tempdb'
)
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [DatabaseName];
'@

$manifest = New-Object System.Collections.Generic.List[object]

foreach ($database in $databases.Rows) {
    $instanceId = [long]$database['InstanceId']
    $databaseName = [string](Get-RowValue $database 'DatabaseName')
    $serverInstance = [string](Get-RowValue $database 'ServerInstance')
    $environmentCode = [string](Get-RowValue $database 'EnvironmentCode')
    $pageTitle = [string](Get-RowValue $database 'PageTitle')

    if ([string]::IsNullOrWhiteSpace($environmentCode)) {
        $environmentCode = 'UNASSIGNED'
    }

    if ([string]::IsNullOrWhiteSpace($pageTitle)) {
        $pageTitle = "$serverInstance - $databaseName"
    }

    $serverFolder = Join-Path `
        (Join-Path `
            $OutputPath `
            (ConvertTo-DBACentralSafePathName -Name $environmentCode)) `
        (ConvertTo-DBACentralSafePathName -Name $serverInstance)

    [System.IO.Directory]::CreateDirectory($serverFolder) | Out-Null

    $filePath = Join-Path `
        $serverFolder `
        (
            (ConvertTo-DBACentralSafePathName `
                -Name $databaseName `
                -MaximumLength 140) +
            '.html'
        )

    $parameters = @{
        InstanceId = $instanceId
        DatabaseName = $databaseName
    }

    try {
        $files = Invoke-RepositoryTable `
            -Parameters $parameters `
            -Sql @'
SELECT
    [LogicalName],
    [FileTypeDesc],
    [FilegroupName],
    [PhysicalName],
    [SizeMB],
    [GrowthValue],
    [GrowthUnit],
    [MaxSizeMB],
    [IsPercentGrowth]
FROM [report].[vCurrentDatabaseFiles]
WHERE [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName
ORDER BY [FileTypeDesc],[FileId];
'@

        $largest = Invoke-RepositoryTable `
            -Parameters $parameters `
            -Sql @'
SELECT TOP (30)
    [SchemaName],
    [TableName],
    [RowCount],
    [ReservedMB],
    [DataMB],
    [IndexMB]
FROM [report].[vCurrentLargestTables]
WHERE [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName
ORDER BY [ReservedMB] DESC,[SchemaName],[TableName];
'@

        $objects = Invoke-RepositoryTable `
            -Parameters $parameters `
            -Sql @'
SELECT
    [SchemaName],
    [ObjectName],
    [ObjectTypeDesc],
    [CreateDate],
    [ModifyDate]
FROM [report].[vCurrentDatabaseObjects]
WHERE [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName
ORDER BY [ObjectTypeDesc],[SchemaName],[ObjectName];
'@

        $columns = Invoke-RepositoryTable `
            -Parameters $parameters `
            -Sql @'
SELECT
    [SchemaName],
    [ObjectName],
    [ColumnId],
    [ColumnName],
    [DataTypeName],
    [MaxLength],
    [PrecisionValue],
    [ScaleValue],
    [IsNullable],
    [IsIdentity],
    [IsComputed]
FROM [report].[vCurrentDatabaseColumns]
WHERE [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName
ORDER BY [SchemaName],[ObjectName],[ColumnId];
'@

        $changes = Invoke-RepositoryTable `
            -Parameters $parameters `
            -Sql @'
SELECT
    [EntityType],
    [SchemaName],
    [ObjectName],
    [ChildName],
    [ChangeType],
    [OldValue],
    [NewValue],
    [PreviousScanRunId],
    [CurrentScanRunId]
FROM [report].[vDatabaseSchemaChanges]
WHERE [InstanceId]=@InstanceId
  AND [DatabaseName]=@DatabaseName
ORDER BY [ChangeType],[SchemaName],[ObjectName],[ChildName];
'@

        $filesHtml = Convert-TableToHtmlFragment $files
        $largestHtml = Convert-TableToHtmlFragment $largest
        $objectsHtml = Convert-TableToHtmlFragment $objects
        $columnsHtml = Convert-TableToHtmlFragment $columns
        $changesHtml = Convert-TableToHtmlFragment $changes

        $encodedTitle = ConvertTo-DBACentralHtml $pageTitle
        $encodedServer = ConvertTo-DBACentralHtml $serverInstance
        $encodedDatabase = ConvertTo-DBACentralHtml $databaseName
        $encodedEnvironment = ConvertTo-DBACentralHtml $environmentCode

        $html = @"
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="utf-8" />
<title>$encodedTitle</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #222; }
h2 { margin-top: 28px; border-bottom: 1px solid #ccc; padding-bottom: 5px; }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th,td { border: 1px solid #ddd; padding: 6px; vertical-align: top; }
th { background: #f2f2f2; }
.meta { background: #f7f7f7; border: 1px solid #ddd; padding: 12px; }
.empty { color: #666; font-style: italic; padding: 8px; }
</style>
</head>
<body>
<h1>$encodedTitle</h1>

<div class="meta">
<strong>Środowisko:</strong> $encodedEnvironment<br />
<strong>Instancja:</strong> $encodedServer<br />
<strong>Baza:</strong> $encodedDatabase<br />
<strong>Status:</strong> $(ConvertTo-DBACentralHtml (Get-RowValue $database 'StateDesc'))<br />
<strong>Recovery model:</strong> $(ConvertTo-DBACentralHtml (Get-RowValue $database 'RecoveryModelDesc'))<br />
<strong>Compatibility level:</strong> $(ConvertTo-DBACentralHtml (Get-RowValue $database 'CompatibilityLevel'))<br />
<strong>Rozmiar MB:</strong> $(ConvertTo-DBACentralHtml (Get-RowValue $database 'TotalSizeMB'))<br />
<strong>Status dokumentacji:</strong> $(ConvertTo-DBACentralHtml (Get-RowValue $database 'DocumentationStatus'))
</div>

<h2>1. Informacje biznesowe</h2>
<table>
<tr><th>Aplikacja</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'ApplicationName'))</td></tr>
<tr><th>Przeznaczenie</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'PurposeDescription'))</td></tr>
<tr><th>Właściciel techniczny</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'TechnicalOwner'))</td></tr>
<tr><th>Właściciel biznesowy</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'BusinessOwner'))</td></tr>
<tr><th>Krytyczność</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'Criticality'))</td></tr>
<tr><th>RPO [min]</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'RpoMinutes'))</td></tr>
<tr><th>RTO [min]</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'RtoMinutes'))</td></tr>
</table>

<h2>2. Konfiguracja</h2>
<table>
<tr><th>Owner SQL</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'OwnerName'))</td></tr>
<tr><th>Collation</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'CollationName'))</td></tr>
<tr><th>PAGE_VERIFY</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'PageVerifyOptionDesc'))</td></tr>
<tr><th>AUTO_CLOSE</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'IsAutoCloseOn'))</td></tr>
<tr><th>AUTO_SHRINK</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'IsAutoShrinkOn'))</td></tr>
<tr><th>RCSI</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'IsReadCommittedSnapshotOn'))</td></tr>
<tr><th>Query Store</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'IsQueryStoreOn'))</td></tr>
<tr><th>Szyfrowanie</th><td>$(ConvertTo-DBACentralHtml (Get-RowValue $database 'IsEncrypted'))</td></tr>
</table>

<h2>3. Pliki</h2>
$filesHtml

<h2>4. Największe tabele</h2>
$largestHtml

<h2>5. Tabele i widoki</h2>
$objectsHtml

<h2>6. Kolumny</h2>
$columnsHtml

<h2>7. Ostatnie zmiany struktury</h2>
$changesHtml
</body>
</html>
"@

        Set-Content -LiteralPath $filePath -Value $html -Encoding UTF8

        Invoke-RepositoryNonQuery `
            -Sql @'
EXEC [db].[usp_MarkDatabaseDocumentationGenerated]
    @InstanceId=@InstanceId,
    @DatabaseName=@DatabaseName,
    @PageTitle=@PageTitle;
'@ `
            -Parameters @{
                InstanceId = $instanceId
                DatabaseName = $databaseName
                PageTitle = $pageTitle
            }

        $manifest.Add(
            [pscustomobject]@{
                InstanceId = $instanceId
                ServerInstance = $serverInstance
                EnvironmentCode = $environmentCode
                DatabaseName = $databaseName
                PageTitle = $pageTitle
                FilePath = $filePath
                Status = 'SUCCESS'
                Error = $null
            }
        )

        Write-Host "Wygenerowano: $pageTitle" -ForegroundColor Green
    }
    catch {
        $manifest.Add(
            [pscustomobject]@{
                InstanceId = $instanceId
                ServerInstance = $serverInstance
                EnvironmentCode = $environmentCode
                DatabaseName = $databaseName
                PageTitle = $pageTitle
                FilePath = $filePath
                Status = 'FAILED'
                Error = $_.Exception.Message
            }
        )

        Write-Warning (
            "Błąd dokumentacji $serverInstance/$databaseName: " +
            $_.Exception.Message
        )
    }
}

$manifestPath = Join-Path $OutputPath '_Manifest stron baz.csv'

$manifest |
    Export-Csv `
        -LiteralPath $manifestPath `
        -Delimiter ';' `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ''
Write-Host "Manifest: $manifestPath" -ForegroundColor Cyan
