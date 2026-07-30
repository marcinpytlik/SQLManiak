[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$OutputPath = '.\ConfluenceExport',

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [int]$CommandTimeoutSeconds = 180,

    [switch]$SkipCsv
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


function Invoke-RepositoryQuery {
    param(
        [Parameter(Mandatory)]
        [string]$Sql
    )

    Invoke-DBACentralDataTable `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Sql $Sql `
        -Credential $RepositorySqlCredential `
        -CommandTimeoutSeconds $CommandTimeoutSeconds `
        -ApplicationName 'DBACentralRepository Confluence Export'
}

function Write-EmptyHtmlReport {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$PageTitle,

        [Parameter(Mandatory)]
        [string]$GeneratedAt,

        [Parameter(Mandatory)]
        [string]$SourceDescription
    )

    $html = @"
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="utf-8" />
<title>$PageTitle</title>
<style>
body {
    font-family: Arial, Helvetica, sans-serif;
    font-size: 13px;
    color: #172B4D;
    margin: 24px;
}
h1 {
    color: #172B4D;
}
.metadata {
    background: #F4F5F7;
    border: 1px solid #DFE1E6;
    padding: 12px;
    margin-bottom: 16px;
}
.no-data {
    border: 1px solid #DFE1E6;
    background: #FAFBFC;
    padding: 16px;
}
</style>
</head>
<body>
<h1>$PageTitle</h1>
<div class="metadata">
<strong>Źródło:</strong> $SourceDescription<br />
<strong>Data wygenerowania:</strong> $GeneratedAt<br />
<strong>Repozytorium:</strong> $RepositoryServerInstance / $RepositoryDatabase
</div>
<div class="no-data">Brak danych dla tego raportu.</div>
</body>
</html>
"@

    Set-Content `
        -Path $Path `
        -Value $html `
        -Encoding UTF8
}

function Write-ErrorHtmlReport {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$PageTitle,

        [Parameter(Mandatory)]
        [string]$GeneratedAt,

        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )

    $encodedMessage =
        [System.Net.WebUtility]::HtmlEncode($ErrorMessage)

    $html = @"
<!DOCTYPE html>
<html lang="pl">
<head>
<meta charset="utf-8" />
<title>$PageTitle</title>
<style>
body {
    font-family: Arial, Helvetica, sans-serif;
    font-size: 13px;
    color: #172B4D;
    margin: 24px;
}
.error {
    background: #FFEBE6;
    border: 1px solid #DE350B;
    padding: 16px;
}
</style>
</head>
<body>
<h1>$PageTitle</h1>
<div class="error">
<strong>Nie udało się wygenerować raportu.</strong><br /><br />
$encodedMessage<br /><br />
Data: $GeneratedAt
</div>
</body>
</html>
"@

    Set-Content `
        -Path $Path `
        -Value $html `
        -Encoding UTF8
}

function Export-ConfluencePage {
    param(
        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$PageTitle,

        [Parameter(Mandatory)]
        [string]$Sql,

        [string]$Description = ''
    )

    $folderName =
        ConvertTo-DBACentralSafePathName -Name $Section

    $fileName =
        ConvertTo-DBACentralSafePathName -Name $PageTitle

    $sectionPath =
        Join-Path $OutputPath $folderName

    New-Item `
        -ItemType Directory `
        -Path $sectionPath `
        -Force |
        Out-Null

    $htmlPath =
        Join-Path $sectionPath ($fileName + '.html')

    $csvPath =
        Join-Path $sectionPath ($fileName + '.csv')

    $generatedAt =
        [System.DateTime]::Now.ToString(
            'yyyy-MM-dd HH:mm:ss'
        )

    Write-Host (
        'Eksportowanie: {0} -> {1}' -f
        $Section,
        $PageTitle
    ) -ForegroundColor Cyan

    try {
        $table =
            Invoke-RepositoryQuery -Sql $Sql

        if ($null -eq $table) {
            throw 'Zapytanie zwróciło NULL.'
        }

        if ($table -isnot [System.Data.DataTable]) {
            throw (
                'Zapytanie nie zwróciło DataTable. Otrzymany typ: {0}' -f
                $table.GetType().FullName
            )
        }

        $rows = @(
            ConvertFrom-DBACentralDataTable `
                -DataTable $table
        )

        if (-not $SkipCsv) {
            if ($rows.Count -gt 0) {
                $rows |
                    Export-Csv `
                        -Path $csvPath `
                        -Delimiter ';' `
                        -NoTypeInformation `
                        -Encoding UTF8
            }
            else {
                Set-Content `
                    -Path $csvPath `
                    -Value '' `
                    -Encoding UTF8
            }
        }

        if ($rows.Count -eq 0) {
            Write-EmptyHtmlReport `
                -Path $htmlPath `
                -PageTitle $PageTitle `
                -GeneratedAt $generatedAt `
                -SourceDescription $Description

            return [pscustomobject]@{
                Section   = $Section
                PageTitle = $PageTitle
                HtmlPath  = $htmlPath
                CsvPath   = if ($SkipCsv) { $null } else { $csvPath }
                RowCount  = 0
                Status    = 'EMPTY'
                Error     = $null
            }
        }

        $style = @"
<style>
body {
    font-family: Arial, Helvetica, sans-serif;
    font-size: 13px;
    color: #172B4D;
    margin: 24px;
}
h1 {
    color: #172B4D;
    margin-bottom: 8px;
}
.metadata {
    background: #F4F5F7;
    border: 1px solid #DFE1E6;
    padding: 12px;
    margin-bottom: 16px;
}
table {
    border-collapse: collapse;
    width: 100%;
}
th {
    background: #F4F5F7;
    font-weight: bold;
    position: sticky;
    top: 0;
}
th, td {
    border: 1px solid #DFE1E6;
    padding: 6px;
    text-align: left;
    vertical-align: top;
}
tr:nth-child(even) {
    background: #FAFBFC;
}
</style>
"@

        $encodedDescription =
            [System.Net.WebUtility]::HtmlEncode($Description)

        $preContent = @"
<h1>$PageTitle</h1>
<div class="metadata">
<strong>Źródło:</strong> DBACentralRepository<br />
<strong>Opis:</strong> $encodedDescription<br />
<strong>Data wygenerowania:</strong> $generatedAt<br />
<strong>Repozytorium:</strong> $RepositoryServerInstance / $RepositoryDatabase<br />
<strong>Liczba wierszy:</strong> $($rows.Count)
</div>
"@

        $rows |
            ConvertTo-Html `
                -Title $PageTitle `
                -Head $style `
                -PreContent $preContent |
            Set-Content `
                -Path $htmlPath `
                -Encoding UTF8

        return [pscustomobject]@{
            Section   = $Section
            PageTitle = $PageTitle
            HtmlPath  = $htmlPath
            CsvPath   = if ($SkipCsv) { $null } else { $csvPath }
            RowCount  = $rows.Count
            Status    = 'SUCCESS'
            Error     = $null
        }
    }
    catch {
        $message = $_.Exception.Message

        Write-Warning (
            'Błąd raportu [{0}]: {1}' -f
            $PageTitle,
            $message
        )

        Write-ErrorHtmlReport `
            -Path $htmlPath `
            -PageTitle $PageTitle `
            -GeneratedAt $generatedAt `
            -ErrorMessage $message

        return [pscustomobject]@{
            Section   = $Section
            PageTitle = $PageTitle
            HtmlPath  = $htmlPath
            CsvPath   = if ($SkipCsv) { $null } else { $csvPath }
            RowCount  = 0
            Status    = 'FAILED'
            Error     = $message
        }
    }
}


New-Item `
    -ItemType Directory `
    -Path $OutputPath `
    -Force |
    Out-Null


$reports = @(

    # =========================================================================
    # 01. Dashboard środowiska
    # =========================================================================
    @{
        Section = '01. Dashboard środowiska'
        PageTitle = 'Instancje objęte monitoringiem'
        Description = 'Instancje SQL Server objęte centralnym skanowaniem.'
        Sql = @'
SELECT *
FROM [report].[vCurrentInstances]
ORDER BY
    [EnvironmentCode],
    [ServerInstance];
'@
    },
    @{
        Section = '01. Dashboard środowiska'
        PageTitle = 'Podsumowanie kategorii jobów'
        Description = 'Liczba jobów według instancji, środowiska i kategorii.'
        Sql = @'
SELECT *
FROM [report].[vJobCategorySummary]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [CategoryName];
'@
    },
    @{
        Section = '01. Dashboard środowiska'
        PageTitle = 'Joby wymagające uwagi'
        Description = 'Joby wyłączone, bez harmonogramu, powiadomień lub dokumentacji.'
        Sql = @'
SELECT *
FROM [report].[vJobsRequiringAttention]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [AttentionReason],
    [JobName];
'@
    },
    @{
        Section = '01. Dashboard środowiska'
        PageTitle = 'Dashboard zgodności'
        Description = 'Podsumowanie ostatniego audytu zgodności jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceDashboard];
'@
    },
    @{
        Section = '01. Dashboard środowiska'
        PageTitle = 'Dashboard zmian'
        Description = 'Podsumowanie zmian jobów w ostatnich okresach.'
        Sql = @'
SELECT *
FROM [report].[vJobChangeDashboard];
'@
    },

    # =========================================================================
    # 02. Rejestr jobów
    # =========================================================================
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Wszystkie joby'
        Description = 'Centralny rejestr wszystkich jobów SQL Server Agent.'
        Sql = @'
SELECT *
FROM [report].[vJobInventory]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby aktywne'
        Description = 'Wszystkie aktywne joby SQL Server Agent.'
        Sql = @'
SELECT *
FROM [report].[vActiveJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby wyłączone'
        Description = 'Wszystkie wyłączone joby SQL Server Agent.'
        Sql = @'
SELECT *
FROM [report].[vDisabledJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby bez harmonogramu'
        Description = 'Joby bez przypisanego harmonogramu.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithoutSchedule]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby z wyłączonym harmonogramem'
        Description = 'Joby posiadające harmonogramy, ale bez aktywnego harmonogramu.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithDisabledSchedule]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby bez powiadomień'
        Description = 'Aktywne joby bez poprawnego powiadomienia po błędzie.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithoutNotification]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby backupowe'
        Description = 'Joby realizujące backupy FULL, DIFF, LOG lub COPY_ONLY.'
        Sql = @'
SELECT *
FROM [report].[vBackupJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [BackupType],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby CHECKDB'
        Description = 'Joby wykonujące DBCC CHECKDB lub DatabaseIntegrityCheck.'
        Sql = @'
SELECT *
FROM [report].[vCheckDbJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby utrzymania indeksów'
        Description = 'Joby wykonujące reorganizację lub przebudowę indeksów.'
        Sql = @'
SELECT *
FROM [report].[vIndexMaintenanceJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby aktualizacji statystyk'
        Description = 'Joby odpowiedzialne za aktualizację statystyk.'
        Sql = @'
SELECT *
FROM [report].[vStatisticsJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby maintenance'
        Description = 'Joby utrzymaniowe SQL Server.'
        Sql = @'
SELECT *
FROM [report].[vMaintenanceJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby czyszczenia i retencji'
        Description = 'Joby odpowiedzialne za cleanup, purge i retencję.'
        Sql = @'
SELECT *
FROM [report].[vCleanupJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby replikacji'
        Description = 'Joby związane z replikacją SQL Server.'
        Sql = @'
SELECT *
FROM [report].[vReplicationJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby HA i DR'
        Description = 'Joby wspierające Availability Groups, Log Shipping i procedury DR.'
        Sql = @'
SELECT *
FROM [report].[vHaDrJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby ETL i integracyjne'
        Description = 'Joby ETL, importu, eksportu i integracji.'
        Sql = @'
SELECT *
FROM [report].[vEtlIntegrationJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby raportowe'
        Description = 'Joby związane z raportowaniem, SSRS i Power BI.'
        Sql = @'
SELECT *
FROM [report].[vReportingJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby monitorujące i alertujące'
        Description = 'Joby monitorujące stan środowiska i wysyłające alerty.'
        Sql = @'
SELECT *
FROM [report].[vMonitoringJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby bezpieczeństwa i audytu'
        Description = 'Joby związane z bezpieczeństwem i audytem.'
        Sql = @'
SELECT *
FROM [report].[vSecurityAuditJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby Database Mail'
        Description = 'Joby używające Database Mail lub wysyłające wiadomości.'
        Sql = @'
SELECT *
FROM [report].[vDatabaseMailJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby T-SQL'
        Description = 'Kroki jobów wykorzystujące subsystem T-SQL.'
        Sql = @'
SELECT *
FROM [report].[vTsqlJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby PowerShell'
        Description = 'Kroki jobów wykorzystujące subsystem PowerShell.'
        Sql = @'
SELECT *
FROM [report].[vPowerShellJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby CmdExec'
        Description = 'Kroki jobów wykorzystujące subsystem CmdExec.'
        Sql = @'
SELECT *
FROM [report].[vCmdExecJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby SSIS'
        Description = 'Kroki jobów wykorzystujące subsystem SSIS.'
        Sql = @'
SELECT *
FROM [report].[vSsisJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby bez proxy'
        Description = 'Kroki PowerShell, CmdExec i SSIS bez przypisanego proxy.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithoutProxy]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby z retry'
        Description = 'Kroki jobów posiadające skonfigurowane ponowienia.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithRetry]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby bez retry'
        Description = 'Kroki jobów bez skonfigurowanych ponowień.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithoutRetry]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby z plikiem wyjściowym'
        Description = 'Kroki jobów zapisujące wynik do pliku.'
        Sql = @'
SELECT *
FROM [report].[vJobsWithOutputFile]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName],
    [StepId];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby niesklasyfikowane'
        Description = 'Joby bez rozpoznanej kategorii funkcjonalnej.'
        Sql = @'
SELECT *
FROM [report].[vUnclassifiedJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },


    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby SSRS'
        Description = 'Joby techniczne SQL Server Reporting Services wraz z nazwą raportu i subskrypcji.'
        Sql = @'
SELECT *
FROM [report].[vSsrsJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [FriendlyJobName];
'@
    },
    @{
        Section = '02. Rejestr jobów'
        PageTitle = 'Joby GUID bez mapowania'
        Description = 'Joby o nazwie GUID, dla których nie znaleziono mapowania SSRS.'
        Sql = @'
SELECT *
FROM [report].[vUnresolvedGuidJobs]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },

    # =========================================================================
    # 08. Monitoring i raportowanie
    # =========================================================================
    @{
        Section = '08. Monitoring i raportowanie'
        PageTitle = 'Historia uruchomień audytu'
        Description = 'Historia uruchomień audytu zgodności jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceRunHistory]
ORDER BY
    [ComplianceRunId] DESC;
'@
    },
    @{
        Section = '08. Monitoring i raportowanie'
        PageTitle = 'Nieudane uruchomienia audytu'
        Description = 'Uruchomienia audytu zakończone błędem.'
        Sql = @'
SELECT *
FROM [report].[vFailedJobComplianceRuns]
ORDER BY
    [ComplianceRunId] DESC;
'@
    },
    @{
        Section = '08. Monitoring i raportowanie'
        PageTitle = 'Błędy skanowania'
        Description = 'Błędy kolektora DBACentralRepository.'
        Sql = @'
SELECT TOP (5000)
    SR.[ScanRunId],
    SR.[ScanStartedAt],
    I.[ServerInstance],
    SE.[ModuleName],
    SE.[ObjectName],
    SE.[StageName],
    SE.[ErrorNumber],
    SE.[ErrorMessage],
    SE.[ErrorAt]
FROM [dbo].[ScanError] AS SE
INNER JOIN [dbo].[ScanRun] AS SR
    ON SR.[ScanRunId] = SE.[ScanRunId]
LEFT JOIN [dbo].[Instance] AS I
    ON I.[InstanceId] = SE.[InstanceId]
ORDER BY
    SE.[ErrorAt] DESC;
'@
    },


    @{
        Section = '08. Monitoring i raportowanie'
        PageTitle = 'Raport dzienny'
        Description = 'Automatyczna codzienna kontrola jobów SQL Server Agent.'
        Sql = @'
EXEC [report].[usp_DailyJobControl];
'@
    },
    @{
        Section = '08. Monitoring i raportowanie'
        PageTitle = 'Raport tygodniowy'
        Description = 'Cotygodniowy przegląd działania i konfiguracji jobów SQL Server Agent.'
        Sql = @'
EXEC [report].[usp_WeeklyJobControl];
'@
    },
    @{
        Section = '08. Monitoring i raportowanie'
        PageTitle = 'Raport miesięczny'
        Description = 'Miesięczny audyt konfiguracji jobów SQL Server Agent.'
        Sql = @'
EXEC [report].[usp_MonthlyJobConfigurationAudit];
'@
    },

    # =========================================================================
    # 09. Audyt i zgodność
    # =========================================================================
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Wyniki audytu zgodności'
        Description = 'Wszystkie findingi z ostatniego poprawnego audytu.'
        Sql = @'
SELECT *
FROM [report].[vCurrentJobComplianceFindings]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName],
    [RuleCode];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Otwarte findingi'
        Description = 'Findingi wymagające analizy lub działania.'
        Sql = @'
SELECT *
FROM [report].[vOpenJobComplianceFindings]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName],
    [RuleCode];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Findingi krytyczne'
        Description = 'Otwarte findingi o ważności CRITICAL lub HIGH.'
        Sql = @'
SELECT *
FROM [report].[vCriticalJobComplianceFindings]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName],
    [RuleCode];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Audyt właścicieli jobów'
        Description = 'Brakujący, wyłączeni lub niestandardowi właściciele jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobOwnerComplianceAudit]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Audyt kont proxy'
        Description = 'Problemy z proxy i credentials jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobProxyComplianceAudit]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Audyt harmonogramów'
        Description = 'Brakujące, wyłączone lub wygasłe harmonogramy.'
        Sql = @'
SELECT *
FROM [report].[vJobScheduleComplianceAudit]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Audyt powiadomień'
        Description = 'Brakujące powiadomienia i niepoprawni operatorzy.'
        Sql = @'
SELECT *
FROM [report].[vJobNotificationComplianceAudit]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Audyt jobów wyłączonych'
        Description = 'Wyłączone joby bez zatwierdzonego wyjątku.'
        Sql = @'
SELECT *
FROM [report].[vDisabledJobComplianceAudit]
ORDER BY
    [SeverityOrder],
    [ServerInstance],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Audyt nieudokumentowanych jobów'
        Description = 'Joby bez kompletnej dokumentacji.'
        Sql = @'
SELECT *
FROM [report].[vJobsMissingDocumentation]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Rejestr dokumentacji jobów'
        Description = 'Status dokumentacji wszystkich jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobDocumentationRegistry]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [AuditStatus],
    [JobName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Dokumentacja bez przeglądu'
        Description = 'Dokumentacja, która nie została jeszcze formalnie przejrzana.'
        Sql = @'
SELECT *
FROM [report].[vJobDocumentationNotReviewed]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Dokumentacja nieaktualna'
        Description = 'Dokumentacja wymagająca ponownego przeglądu.'
        Sql = @'
SELECT *
FROM [report].[vOutdatedJobDocumentation]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [LastReviewedAt],
    [JobName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Aktywne wyjątki'
        Description = 'Aktywne wyjątki od standardów zgodności.'
        Sql = @'
SELECT *
FROM [report].[vActiveJobComplianceExceptions]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [RuleCode],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Wygasłe wyjątki'
        Description = 'Wyjątki od standardów, których termin ważności upłynął.'
        Sql = @'
SELECT *
FROM [report].[vExpiredJobComplianceExceptions]
ORDER BY
    [ValidTo],
    [ServerInstance],
    [RuleCode];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Wyjątki wygasające w ciągu 30 dni'
        Description = 'Aktywne wyjątki wymagające wkrótce ponownej decyzji.'
        Sql = @'
SELECT *
FROM [report].[vExpiringJobComplianceExceptions]
ORDER BY
    [DaysToExpire],
    [ServerInstance],
    [RuleCode];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Wyjątki bez numeru zgłoszenia'
        Description = 'Wyjątki zgodności bez przypisanego numeru zgłoszenia.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceExceptionsWithoutTicket]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [RuleCode],
    [ObjectName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Reguły audytu'
        Description = 'Słownik reguł audytu wraz z rekomendacjami.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceRules]
ORDER BY
    [SeverityOrder],
    [RuleCode];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Podsumowanie według reguły'
        Description = 'Liczba findingów według RuleCode.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceByRule]
ORDER BY
    CASE [Severity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
        ELSE 5
    END,
    [FindingCount] DESC;
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Podsumowanie według ważności'
        Description = 'Findingi według poziomu ważności.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceBySeverity]
ORDER BY
    [SeverityOrder];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Podsumowanie według instancji'
        Description = 'Findingi według instancji SQL Server.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceByInstance]
ORDER BY
    [CriticalOpenCount] DESC,
    [HighOpenCount] DESC,
    [OpenCount] DESC,
    [ServerInstance];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Joby z największą liczbą niezgodności'
        Description = 'Joby posiadające najwięcej otwartych findingów.'
        Sql = @'
SELECT *
FROM [report].[vMostNonCompliantJobs]
ORDER BY
    [HighestSeverityOrder],
    [OpenCount] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '09. Audyt i zgodność'
        PageTitle = 'Kolejka działań naprawczych'
        Description = 'Otwarte findingi wraz z rekomendowanym czasem rozwiązania.'
        Sql = @'
SELECT *
FROM [report].[vJobComplianceActionQueue]
ORDER BY
    CASE [Severity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
        ELSE 5
    END,
    [ServerInstance],
    [ObjectName];
'@
    },

    # =========================================================================
    # 10. Zmiany i cykl życia
    # =========================================================================
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Rejestr zmian'
        Description = 'Pełny rejestr zmian jobów SQL Server Agent.'
        Sql = @'
SELECT *
FROM [report].[vJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [JobChangeId] DESC;
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Nowe joby'
        Description = 'Joby dodane pomiędzy kolejnymi skanami.'
        Sql = @'
SELECT *
FROM [report].[vNewJobs]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Usunięte joby'
        Description = 'Joby usunięte pomiędzy kolejnymi skanami.'
        Sql = @'
SELECT *
FROM [report].[vRemovedJobs]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmodyfikowane joby'
        Description = 'Joby zmodyfikowane pomiędzy kolejnymi skanami.'
        Sql = @'
SELECT *
FROM [report].[vModifiedJobs]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany właścicieli'
        Description = 'Zmiany właścicieli jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobOwnerChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany statusu jobów'
        Description = 'Zmiany aktywności jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobStatusChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Joby włączone'
        Description = 'Joby włączone pomiędzy kolejnymi skanami.'
        Sql = @'
SELECT *
FROM [report].[vEnabledJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Joby wyłączone'
        Description = 'Joby wyłączone pomiędzy kolejnymi skanami.'
        Sql = @'
SELECT *
FROM [report].[vDisabledJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany kroków'
        Description = 'Zmiany konfiguracji kroków jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobStepChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName],
    [ObjectName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany komend'
        Description = 'Zmiany komend wykonywanych przez kroki jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobCommandChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName],
    [ObjectName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany harmonogramów'
        Description = 'Zmiany harmonogramów jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobScheduleChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName],
    [ObjectName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany operatorów'
        Description = 'Zmiany operatorów przypisanych do jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobOperatorChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany powiadomień'
        Description = 'Zmiany konfiguracji powiadomień jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobNotificationChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany proxy'
        Description = 'Zmiany proxy przypisanych do kroków jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobProxyChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany kategorii'
        Description = 'Zmiany kategorii jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobCategoryChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany opisów'
        Description = 'Zmiany opisów jobów.'
        Sql = @'
SELECT *
FROM [report].[vJobDescriptionChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany autoryzowane'
        Description = 'Zmiany oznaczone jako autoryzowane.'
        Sql = @'
SELECT *
FROM [report].[vAuthorizedJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany nieautoryzowane'
        Description = 'Zmiany oznaczone jako nieautoryzowane.'
        Sql = @'
SELECT *
FROM [report].[vUnauthorizedJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany niezweryfikowane'
        Description = 'Zmiany, których status autoryzacji nie został jeszcze ustalony.'
        Sql = @'
SELECT *
FROM [report].[vUnreviewedJobChanges]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany bez numeru zgłoszenia'
        Description = 'Zmiany bez przypisanego numeru ticketu.'
        Sql = @'
SELECT *
FROM [report].[vJobChangesWithoutTicket]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany z ostatnich 24 godzin'
        Description = 'Zmiany wykryte w ciągu ostatnich 24 godzin.'
        Sql = @'
SELECT *
FROM [report].[vJobChangesLast24Hours]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany z ostatnich 7 dni'
        Description = 'Zmiany wykryte w ciągu ostatnich 7 dni.'
        Sql = @'
SELECT *
FROM [report].[vJobChangesLast7Days]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany z ostatnich 30 dni'
        Description = 'Zmiany wykryte w ciągu ostatnich 30 dni.'
        Sql = @'
SELECT *
FROM [report].[vJobChangesLast30Days]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Zmiany krytyczne'
        Description = 'Zmiany o potencjalnie największym wpływie operacyjnym.'
        Sql = @'
SELECT *
FROM [report].[vCriticalJobChanges]
ORDER BY
    CASE [ChangeSeverity]
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
        ELSE 5
    END,
    [DetectedAt] DESC;
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Ostatnia zmiana każdego joba'
        Description = 'Najnowsza wykryta zmiana dla każdego joba.'
        Sql = @'
SELECT *
FROM [report].[vLatestJobChange]
ORDER BY
    [DetectedAt] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Joby często zmieniane'
        Description = 'Joby posiadające wiele zmian w ciągu ostatnich 30 dni.'
        Sql = @'
SELECT *
FROM [report].[vFrequentlyChangedJobs]
ORDER BY
    [ChangeCount] DESC,
    [ServerInstance],
    [JobName];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Podsumowanie zmian'
        Description = 'Podsumowanie zmian według instancji, typu i statusu autoryzacji.'
        Sql = @'
SELECT *
FROM [report].[vJobChangeSummary]
ORDER BY
    [EnvironmentCode],
    [ServerInstance],
    [ChangeCount] DESC;
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Dzienne podsumowanie zmian'
        Description = 'Liczba zmian w ujęciu dziennym.'
        Sql = @'
SELECT *
FROM [report].[vJobChangeDailySummary]
ORDER BY
    [ChangeDate] DESC,
    [EnvironmentCode],
    [ServerInstance],
    [ChangeArea];
'@
    },
    @{
        Section = '10. Zmiany i cykl życia'
        PageTitle = 'Podsumowanie zmian według instancji'
        Description = 'Zbiorcza liczba zmian według instancji SQL Server.'
        Sql = @'
SELECT *
FROM [report].[vJobChangeByInstance]
ORDER BY
    [UnauthorizedCount] DESC,
    [NotReviewedCount] DESC,
    [TotalChangeCount] DESC,
    [ServerInstance];
'@
    }
)


$results = New-Object System.Collections.Generic.List[object]

foreach ($report in $reports) {
    $result =
        Export-ConfluencePage `
            -Section $report.Section `
            -PageTitle $report.PageTitle `
            -Sql $report.Sql `
            -Description $report.Description

    $results.Add($result)
}


$summaryPath =
    Join-Path $OutputPath '_Podsumowanie eksportu.csv'

$results |
    Export-Csv `
        -Path $summaryPath `
        -Delimiter ';' `
        -NoTypeInformation `
        -Encoding UTF8


$failedCount =
    @(
        $results |
            Where-Object {
                $_.Status -eq 'FAILED'
            }
    ).Count

$successCount =
    @(
        $results |
            Where-Object {
                $_.Status -eq 'SUCCESS'
            }
    ).Count

$emptyCount =
    @(
        $results |
            Where-Object {
                $_.Status -eq 'EMPTY'
            }
    ).Count


Write-Host ''
Write-Host 'Eksport zakończony.' -ForegroundColor Green
Write-Host "Folder: $OutputPath"
Write-Host "Raporty poprawne: $successCount"
Write-Host "Raporty bez danych: $emptyCount"
Write-Host "Raporty z błędem: $failedCount"
Write-Host "Podsumowanie: $summaryPath"

if ($failedCount -gt 0) {
    Write-Warning (
        'Część raportów zakończyła się błędem. ' +
        'Sprawdź plik _Podsumowanie eksportu.csv.'
    )
}
