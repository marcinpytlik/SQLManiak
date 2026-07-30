[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$OutputPath = '.\ConfluenceExport\03. Dokumentacja jobów',

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [int]$CommandTimeoutSeconds = 180,

    [switch]$IncludeCommandText = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path `
    $PSScriptRoot `
    'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

Import-Module `
    -Name $modulePath `
    -Force `
    -ErrorAction Stop



function Invoke-RepositoryDataTable {
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
        -ApplicationName 'DBACentralRepository Job Documentation'
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
        -ApplicationName 'DBACentralRepository Job Documentation')
}

function Convert-TableToHtml {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$Table,

        [string[]]$ExcludeColumns = @()
    )

    if ($Table.Rows.Count -eq 0) {
        return '<div class="empty">Brak danych.</div>'
    }

    $columns = @(
        $Table.Columns |
            Where-Object {
                $ExcludeColumns -notcontains $_.ColumnName
            }
    )

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('<table>')
    [void]$builder.AppendLine('<thead><tr>')

    foreach ($column in $columns) {
        [void]$builder.Append(
            '<th>' + (ConvertTo-DBACentralHtml $column.ColumnName) + '</th>'
        )
    }

    [void]$builder.AppendLine('</tr></thead>')
    [void]$builder.AppendLine('<tbody>')

    foreach ($row in $Table.Rows) {
        [void]$builder.AppendLine('<tr>')

        foreach ($column in $columns) {
            $value = $row[$column.ColumnName]

            if ($value -is [DBNull]) {
                $value = ''
            }

            $text = ConvertTo-DBACentralHtml $value
            $text = $text -replace "`r?`n", '<br />'

            [void]$builder.Append(
                '<td>' + $text + '</td>'
            )
        }

        [void]$builder.AppendLine('</tr>')
    }

    [void]$builder.AppendLine('</tbody></table>')

    return $builder.ToString()
}


New-Item `
    -ItemType Directory `
    -Path $OutputPath `
    -Force |
    Out-Null


Write-Host 'Synchronizacja rejestru dokumentacji...' -ForegroundColor Cyan

Invoke-RepositoryNonQuery `
    -Sql 'EXEC [audit].[usp_SyncJobDocumentationRegistry];' `
    -Parameters @{}


$jobs = Invoke-RepositoryDataTable -Sql @'
SELECT
    [InstanceId],
    [ServerInstance],
    [EnvironmentCode],
    [JobId],
    [JobName],
    [CategoryName],
    [OwnerName],
    [Description],
    [IsEnabled],
    [DateCreated],
    [DateModified],
    [OperatorName],
    [NotifyLevelEmail],
    [StepCount],
    [ScheduleCount],
    [ExecutionMode],
    [PageTitle],
    [ConfluencePageUrl],
    [TechnicalOwner],
    [BusinessOwner],
    [Criticality],
    [DocumentationStatus],
    [LastReviewedAt],
    [ReviewedBy],
    [Notes]
FROM [report].[vJobDocumentationPages]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@


$manifest = New-Object System.Collections.Generic.List[object]
$generatedCount = 0
$failedCount = 0

foreach ($job in $jobs.Rows) {
    $instanceId = [long]$job['InstanceId']
    $jobId = [Guid]$job['JobId']
    $environmentCode = Get-DBACentralDataRowValue $job 'EnvironmentCode'
    $serverInstance = Get-DBACentralDataRowValue $job 'ServerInstance'
    $jobName = Get-DBACentralDataRowValue $job 'JobName'

    if ([string]::IsNullOrWhiteSpace($environmentCode)) {
        $environmentCode = 'UNASSIGNED'
    }

    $environmentFolder =
        ConvertTo-DBACentralSafePathName -Name $environmentCode

    $instanceFolder =
        ConvertTo-DBACentralSafePathName -Name $serverInstance

    $pageTitle =
        if ([string]::IsNullOrWhiteSpace(
            (Get-DBACentralDataRowValue $job 'PageTitle')
        )) {
            $jobName
        }
        else {
            Get-DBACentralDataRowValue $job 'PageTitle'
        }

    $fileName =
        (ConvertTo-DBACentralSafePathName -Name $jobName) + '.html'

    $folderPath =
        Join-Path `
            (Join-Path $OutputPath $environmentFolder) `
            $instanceFolder

    New-Item `
        -ItemType Directory `
        -Path $folderPath `
        -Force |
        Out-Null

    $htmlPath =
        Join-Path $folderPath $fileName

    Write-Host (
        '[{0}] {1} - {2}' -f
        $environmentCode,
        $serverInstance,
        $jobName
    ) -ForegroundColor Cyan

    try {
        $parameters = @{
            InstanceId = $instanceId
            JobId = $jobId
        }

        $steps = Invoke-RepositoryDataTable -Parameters $parameters -Sql @'
SELECT
    [StepId],
    [StepName],
    [Subsystem],
    [DatabaseName],
    [ProxyName],
    [RetryAttempts],
    [RetryInterval],
    [OutputFileName],
    [OnSuccessAction],
    [OnSuccessStepId],
    [OnFailAction],
    [OnFailStepId],
    [CommandText]
FROM [audit].[vCurrentJobSteps]
WHERE [InstanceId] = @InstanceId
  AND [JobId] = @JobId
ORDER BY [StepId];
'@

        $schedules = Invoke-RepositoryDataTable -Parameters $parameters -Sql @'
SELECT
    [ScheduleId],
    [ScheduleName],
    [IsEnabled],
    [FreqType],
    [FreqInterval],
    [FreqSubdayType],
    [FreqSubdayInterval],
    [FreqRelativeInterval],
    [FreqRecurrenceFactor],
    [ActiveStartDate],
    [ActiveEndDate],
    [ActiveStartTime],
    [ActiveEndTime],
    [NextRunAt]
FROM [audit].[vCurrentJobSchedules]
WHERE [InstanceId] = @InstanceId
  AND [JobId] = @JobId
ORDER BY [ScheduleName];
'@

        $categories = Invoke-RepositoryDataTable -Parameters $parameters -Sql @'
SELECT
    [CategoryCode],
    [CategoryName]
FROM [report].[vJobCategoryMembership]
WHERE [InstanceId] = @InstanceId
  AND [JobId] = @JobId
ORDER BY [CategoryName];
'@

        $findings = Invoke-RepositoryDataTable -Parameters $parameters -Sql @'
SELECT
    [RuleCode],
    [RuleName],
    [Severity],
    [CurrentValue],
    [ExpectedValue],
    [Recommendation],
    [EffectiveFindingStatus],
    [FirstDetectedAt],
    [LastDetectedAt]
FROM [report].[vCurrentJobComplianceFindings]
WHERE [InstanceId] = @InstanceId
  AND
  (
      [ObjectKey] = CONVERT(nvarchar(36), @JobId)
      OR [ObjectName] =
         (
             SELECT TOP (1) [JobName]
             FROM [report].[vCurrentJobs]
             WHERE [InstanceId] = @InstanceId
               AND [JobId] = @JobId
         )
  )
ORDER BY
    [SeverityOrder],
    [RuleCode];
'@

        $changes = Invoke-RepositoryDataTable -Parameters $parameters -Sql @'
SELECT TOP (100)
    [DetectedAt],
    [NormalizedChangeType],
    [ChangeArea],
    [ObjectType],
    [ObjectName],
    [PropertyName],
    [OldValue],
    [NewValue],
    [AuthorizationStatus],
    [TicketNumber]
FROM [report].[vJobChanges]
WHERE [InstanceId] = @InstanceId
  AND [JobId] = @JobId
ORDER BY
    [DetectedAt] DESC,
    [JobChangeId] DESC;
'@

        $executions = Invoke-RepositoryDataTable -Parameters $parameters -Sql @'
SELECT TOP (50)
    [RunAt],
    [RunStatus],
    [RunStatusDescription],
    [DurationSeconds],
    [DurationHHMMSS],
    [RetriesAttempted],
    [MessageText]
FROM [job].[JobExecution]
WHERE [InstanceId] = @InstanceId
  AND [JobId] = @JobId
ORDER BY [RunAt] DESC;
'@

        $categoriesHtml =
            Convert-TableToHtml -Table $categories

        $excludeStepColumns =
            if ($IncludeCommandText) {
                @()
            }
            else {
                @('CommandText')
            }

        $stepsHtml =
            Convert-TableToHtml `
                -Table $steps `
                -ExcludeColumns $excludeStepColumns

        $schedulesHtml =
            Convert-TableToHtml -Table $schedules

        $findingsHtml =
            Convert-TableToHtml -Table $findings

        $changesHtml =
            Convert-TableToHtml -Table $changes

        $executionsHtml =
            Convert-TableToHtml -Table $executions

        $generatedAt =
            [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')

        $encodedPageTitle = ConvertTo-DBACentralHtml $pageTitle
        $encodedJobName = ConvertTo-DBACentralHtml $jobName
        $encodedServer = ConvertTo-DBACentralHtml $serverInstance
        $encodedEnvironment = ConvertTo-DBACentralHtml $environmentCode

        $statusText =
            if ([bool]$job['IsEnabled']) {
                'Aktywny'
            }
            else {
                'Wyłączony'
            }

        $html = @"
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="utf-8" />
<title>$encodedPageTitle</title>
<style>
body {
    font-family: Arial, Helvetica, sans-serif;
    font-size: 13px;
    color: #172B4D;
    margin: 24px;
}
h1, h2 {
    color: #172B4D;
}
h2 {
    margin-top: 30px;
    border-bottom: 1px solid #DFE1E6;
    padding-bottom: 5px;
}
.metadata, .manual {
    background: #F4F5F7;
    border: 1px solid #DFE1E6;
    padding: 14px;
    margin-bottom: 18px;
}
.manual {
    background: #FFFAE6;
}
table {
    border-collapse: collapse;
    width: 100%;
    margin-bottom: 18px;
}
th {
    background: #F4F5F7;
    font-weight: bold;
}
th, td {
    border: 1px solid #DFE1E6;
    padding: 6px;
    text-align: left;
    vertical-align: top;
    word-break: break-word;
}
tr:nth-child(even) {
    background: #FAFBFC;
}
.empty {
    padding: 12px;
    border: 1px solid #DFE1E6;
    background: #FAFBFC;
}
code, pre {
    white-space: pre-wrap;
    word-break: break-word;
}
</style>
</head>
<body>

<h1>$encodedPageTitle</h1>

<div class="metadata">
<strong>Środowisko:</strong> $encodedEnvironment<br />
<strong>Instancja:</strong> $encodedServer<br />
<strong>Job:</strong> $encodedJobName<br />
<strong>JobId:</strong> $(ConvertTo-DBACentralHtml $jobId)<br />
<strong>Status:</strong> $(ConvertTo-DBACentralHtml $statusText)<br />
<strong>Właściciel SQL Agent:</strong> $(ConvertTo-DBACentralHtml $job['OwnerName'])<br />
<strong>Kategoria SQL Agent:</strong> $(ConvertTo-DBACentralHtml $job['CategoryName'])<br />
<strong>Tryb wykonania:</strong> $(ConvertTo-DBACentralHtml $job['ExecutionMode'])<br />
<strong>Operator:</strong> $(ConvertTo-DBACentralHtml $job['OperatorName'])<br />
<strong>Data utworzenia:</strong> $(ConvertTo-DBACentralHtml $job['DateCreated'])<br />
<strong>Data modyfikacji:</strong> $(ConvertTo-DBACentralHtml $job['DateModified'])<br />
<strong>Data wygenerowania strony:</strong> $generatedAt
</div>

<h2>1. Cel i odpowiedzialność</h2>

<div class="manual">
<strong>Cel biznesowy:</strong> do uzupełnienia<br /><br />
<strong>Właściciel techniczny:</strong> $(ConvertTo-DBACentralHtml $job['TechnicalOwner'])<br /><br />
<strong>Właściciel biznesowy:</strong> $(ConvertTo-DBACentralHtml $job['BusinessOwner'])<br /><br />
<strong>Krytyczność:</strong> $(ConvertTo-DBACentralHtml $job['Criticality'])<br /><br />
<strong>Zależności:</strong> do uzupełnienia<br /><br />
<strong>Procedura obsługi błędu:</strong> do uzupełnienia<br /><br />
<strong>RTO / RPO:</strong> do uzupełnienia<br /><br />
<strong>Okno wykonania:</strong> do uzupełnienia
</div>

<h2>2. Opis joba</h2>
<p>$(ConvertTo-DBACentralHtml $job['Description'])</p>

<h2>3. Kategorie techniczne i funkcjonalne</h2>
$categoriesHtml

<h2>4. Kroki joba</h2>
$stepsHtml

<h2>5. Harmonogramy</h2>
$schedulesHtml

<h2>6. Powiadomienia</h2>
<table>
<tr><th>Operator</th><td>$(ConvertTo-DBACentralHtml $job['OperatorName'])</td></tr>
<tr><th>NotifyLevelEmail</th><td>$(ConvertTo-DBACentralHtml $job['NotifyLevelEmail'])</td></tr>
</table>

<h2>7. Wyniki audytu zgodności</h2>
$findingsHtml

<h2>8. Ostatnie zmiany</h2>
$changesHtml

<h2>9. Ostatnie wykonania</h2>
$executionsHtml

<h2>10. Status dokumentacji</h2>
<table>
<tr><th>Status</th><td>$(ConvertTo-DBACentralHtml $job['DocumentationStatus'])</td></tr>
<tr><th>Strona Confluence</th><td>$(ConvertTo-DBACentralHtml $job['ConfluencePageUrl'])</td></tr>
<tr><th>Ostatni przegląd</th><td>$(ConvertTo-DBACentralHtml $job['LastReviewedAt'])</td></tr>
<tr><th>Przejrzał</th><td>$(ConvertTo-DBACentralHtml $job['ReviewedBy'])</td></tr>
<tr><th>Uwagi</th><td>$(ConvertTo-DBACentralHtml $job['Notes'])</td></tr>
</table>

</body>
</html>
"@

        Set-Content `
            -Path $htmlPath `
            -Value $html `
            -Encoding UTF8

        Invoke-RepositoryNonQuery `
            -Sql @'
EXEC [audit].[usp_MarkJobDocumentationGenerated]
    @InstanceId = @InstanceId,
    @JobId = @JobId,
    @GeneratedFilePath = @GeneratedFilePath,
    @PageTitle = @PageTitle;
'@ `
            -Parameters @{
                InstanceId = $instanceId
                JobId = $jobId
                GeneratedFilePath = $htmlPath
                PageTitle = $pageTitle
            }

        $manifest.Add(
            [pscustomobject]@{
                EnvironmentCode = $environmentCode
                ServerInstance = $serverInstance
                InstanceId = $instanceId
                JobId = $jobId
                JobName = $jobName
                PageTitle = $pageTitle
                FilePath = $htmlPath
                DocumentationStatus = 'GENERATED'
                Status = 'SUCCESS'
                Error = $null
            }
        )

        $generatedCount++
    }
    catch {
        $failedCount++

        $manifest.Add(
            [pscustomobject]@{
                EnvironmentCode = $environmentCode
                ServerInstance = $serverInstance
                InstanceId = $instanceId
                JobId = $jobId
                JobName = $jobName
                PageTitle = $pageTitle
                FilePath = $htmlPath
                DocumentationStatus =
                    Get-DBACentralDataRowValue $job 'DocumentationStatus'
                Status = 'FAILED'
                Error = $_.Exception.Message
            }
        )

        Write-Warning (
            'Nie udało się wygenerować strony dla joba [{0}]: {1}' -f
            $jobName,
            $_.Exception.Message
        )
    }
}


$manifestPath =
    Join-Path $OutputPath '_Manifest stron jobów.csv'

$manifest |
    Export-Csv `
        -Path $manifestPath `
        -Delimiter ';' `
        -NoTypeInformation `
        -Encoding UTF8


Write-Host ''
Write-Host 'Eksport dokumentacji jobów zakończony.' -ForegroundColor Green
Write-Host "Wygenerowane strony: $generatedCount"
Write-Host "Błędy: $failedCount"
Write-Host "Manifest: $manifestPath"
