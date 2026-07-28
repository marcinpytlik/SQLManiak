[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepositoryServerInstance,
    [string]$RepositoryDatabase='DBACentralRepository',
    [string]$OutputPath='.\ConfluenceExport',
    [System.Management.Automation.PSCredential]$RepositorySqlCredential
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function New-Cn {
    $b=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $b.DataSource=$RepositoryServerInstance
    $b.InitialCatalog=$RepositoryDatabase
    $b.ApplicationName='DBACentralRepository v3 Export'
    $b.ConnectTimeout=15
    $b.Encrypt=$false
    $b.TrustServerCertificate=$true
    if($null -eq $RepositorySqlCredential){$b.IntegratedSecurity=$true}
    else{
        $b.UserID=$RepositorySqlCredential.UserName
        $b.Password=$RepositorySqlCredential.GetNetworkCredential().Password
    }
    [System.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
}

function Query([string]$Sql){
    $cn=New-Cn
    try{
        $cn.Open()
        $cmd=$cn.CreateCommand()
        $cmd.CommandText=$Sql
        $cmd.CommandTimeout=180
        $da=[System.Data.SqlClient.SqlDataAdapter]::new($cmd)
        $dt=[System.Data.DataTable]::new()
        [void]$da.Fill($dt)
        $dt
    }finally{$cn.Dispose()}
}

function Rows([System.Data.DataTable]$dt){
    foreach($r in $dt.Rows){
        $o=[ordered]@{}
        foreach($c in $dt.Columns){$o[$c.ColumnName]=$r[$c.ColumnName]}
        [pscustomobject]$o
    }
}

New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null

$items=@(
@{N='01_Instances';T='Instancje';Q='SELECT * FROM report.vCurrentInstances ORDER BY EnvironmentCode,ServerInstance;'},
@{N='02_Jobs';T='Joby';Q='SELECT ServerInstance,EnvironmentCode,JobName,OwnerName,IsEnabled,DateModified,OperatorName FROM report.vCurrentJobs ORDER BY ServerInstance,JobName;'},
@{N='03_Databases';T='Bazy';Q='SELECT ServerInstance,EnvironmentCode,DatabaseName,StateDesc,RecoveryModelDesc,CompatibilityLevel,TotalSizeMB,IsEncrypted FROM report.vCurrentDatabases ORDER BY ServerInstance,DatabaseName;'},
@{N='04_Backup_Compliance';T='Zgodność backupów';Q='EXEC report.usp_BackupCompliance;'},
@{N='05_Capacity_Risk';T='Ryzyko pojemności';Q='EXEC report.usp_CapacityRisk;'},
@{N='06_HA_Health';T='Stan HA';Q='EXEC report.usp_HaHealth;'},
@{N='07_Configuration';T='Konfiguracja';Q='SELECT ServerInstance,EnvironmentCode,ConfigurationName,ConfigValue,RunValue FROM report.vCurrentServerConfiguration ORDER BY ServerInstance,ConfigurationName;'},
@{N='08_Principals';T='Loginy';Q='SELECT ServerInstance,EnvironmentCode,PrincipalName,PrincipalTypeDesc,IsDisabled,DefaultDatabaseName FROM report.vCurrentServerPrincipals ORDER BY ServerInstance,PrincipalName;'},
@{N='09_Job_Compliance';T='Audyt jobów';Q='SELECT * FROM report.vLatestJobComplianceFindings ORDER BY ServerInstance,ObjectName;'},
@{N='10_Undocumented_Jobs';T='Nieudokumentowane joby';Q='SELECT * FROM report.vUndocumentedJobs WHERE AuditStatus<>''OK'' ORDER BY ServerInstance,JobName;'},
@{N='11_Job_Changes';T='Zmiany jobów';Q='EXEC report.usp_JobChanges @Days=30;'},
@{N='12_Scan_Errors';T='Błędy skanowania';Q='SELECT TOP(1000) S.ScanStartedAt,I.ServerInstance,E.ModuleName,E.ObjectName,E.StageName,E.ErrorMessage,E.ErrorAt FROM dbo.ScanError E JOIN dbo.ScanRun S ON S.ScanRunId=E.ScanRunId LEFT JOIN dbo.Instance I ON I.InstanceId=E.InstanceId ORDER BY E.ErrorAt DESC;'}
)

$style='<style>body{font-family:Arial;font-size:13px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #dfe1e6;padding:6px}th{background:#f4f5f7}</style>'

foreach($i in $items){
    $dt=Query $i.Q
    $rows=@(Rows $dt)
    $rows|Export-Csv (Join-Path $OutputPath ($i.N+'.csv')) -Delimiter ';' -NoTypeInformation -Encoding UTF8
    $rows|ConvertTo-Html -Title $i.T -Head $style -PreContent "<h1>$($i.T)</h1>"|
        Set-Content (Join-Path $OutputPath ($i.N+'.html')) -Encoding UTF8
}

Write-Host "Eksport zakończony: $OutputPath" -ForegroundColor Green
