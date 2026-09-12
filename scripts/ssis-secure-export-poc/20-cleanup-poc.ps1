#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance = 'SQL64',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FileServer = 'DC01',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ShareName = 'SSISLab$',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SharePath = 'C:\POC\SSISLab',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LocalPocPath = 'C:\SSIS\POC',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationAccount = 'SQLLAB\poc-ssis-app',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExecutionAccount = 'SQLLAB\poc-ssis-export',

    [Parameter()]
    [switch]$KeepAdAccounts,

    [Parameter()]
    [switch]$KeepShare,

    [Parameter()]
    [switch]$KeepLocalFiles,

    [Parameter()]
    [switch]$KeepDatabase,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Text)
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found."
    }
}

if (-not $Force -and -not $WhatIfPreference) {
    Write-Warning 'This script removes the Secure Export POC: SQL Agent jobs, schedules, proxies, Credential, POC database, local worker files, SMB share and optionally AD accounts.'
    Write-Warning 'Run with -WhatIf first if you want to review the actions.'
    $confirmation = Read-Host 'Type DELETE-POC to continue'
    if ($confirmation -ne 'DELETE-POC') {
        throw 'Cleanup cancelled.'
    }
}

Assert-Command -Name Invoke-Sqlcmd

$applicationAccountSql = $ApplicationAccount.Replace("'", "''")
$executionAccountSql = $ExecutionAccount.Replace("'", "''")
$applicationAccountIdentifier = $ApplicationAccount.Replace(']', ']]')
$executionAccountIdentifier = $ExecutionAccount.Replace(']', ']]')
$dropDb = if ($KeepDatabase) { 0 } else { 1 }

$sqlCleanup = @"
USE [msdb];
SET NOCOUNT ON;

DECLARE @Jobs table (JobName sysname);
INSERT @Jobs(JobName)
VALUES
    (N'POC_Secure_Export_Stage4'),
    (N'POC_Secure_Export_Stage5_Worker'),
    (N'POC_SSIS_Secure_Export_Stage4');

DECLARE @JobName sysname;
DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT JobName FROM @Jobs;
OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @JobName;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @JobName)
        EXEC dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
    FETCH NEXT FROM job_cursor INTO @JobName;
END;
CLOSE job_cursor;
DEALLOCATE job_cursor;

IF EXISTS (SELECT 1 FROM dbo.sysschedules WHERE name = N'POC_Secure_Export_Stage5_EveryMinute')
    EXEC dbo.sp_delete_schedule @schedule_name = N'POC_Secure_Export_Stage5_EveryMinute';

IF EXISTS (SELECT 1 FROM dbo.sysproxies WHERE name = N'POC_Export_CmdExec_Proxy')
    EXEC dbo.sp_delete_proxy @proxy_name = N'POC_Export_CmdExec_Proxy';

IF EXISTS (SELECT 1 FROM dbo.sysproxies WHERE name = N'POC_SSIS_Export_Proxy')
    EXEC dbo.sp_delete_proxy @proxy_name = N'POC_SSIS_Export_Proxy';

USE [master];

IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'POC_SSIS_Export_Credential')
    DROP CREDENTIAL [POC_SSIS_Export_Credential];

IF DB_ID(N'SSIS_Delegation_Lab') IS NOT NULL AND __DROP_DATABASE__ = 1
BEGIN
    ALTER DATABASE [SSIS_Delegation_Lab] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [SSIS_Delegation_Lab];
END;

IF SUSER_ID(N'$applicationAccountSql') IS NOT NULL
    DROP LOGIN [$applicationAccountIdentifier];

IF SUSER_ID(N'$executionAccountSql') IS NOT NULL
    DROP LOGIN [$executionAccountIdentifier];
"@

$sqlCleanup = $sqlCleanup.Replace('__DROP_DATABASE__', [string]$dropDb)

Write-Step 'SQL Server cleanup'
if ($PSCmdlet.ShouldProcess($SqlInstance, 'Remove POC SQL Agent jobs/schedules/proxies/Credential/logins and optionally database')) {
    Invoke-Sqlcmd -ServerInstance $SqlInstance -Database master -Query $sqlCleanup -AbortOnError
    Write-Host 'SQL cleanup completed.' -ForegroundColor Green
}

if (-not $KeepLocalFiles) {
    Write-Step 'Local worker files cleanup'
    if ($PSCmdlet.ShouldProcess($SqlInstance, "Remove $LocalPocPath")) {
        $localCleanup = {
            param($Path)
            if (Test-Path -LiteralPath $Path) {
                Remove-Item -LiteralPath $Path -Recurse -Force
            }
        }

        if ($env:COMPUTERNAME -ieq $SqlInstance.Split('\\')[0].Split('.')[0]) {
            & $localCleanup $LocalPocPath
        }
        else {
            Invoke-Command -ComputerName $SqlInstance -ScriptBlock $localCleanup -ArgumentList $LocalPocPath
        }

        Write-Host "Removed $LocalPocPath." -ForegroundColor Green
    }
}

if (-not $KeepShare) {
    Write-Step 'SMB share cleanup'
    if ($PSCmdlet.ShouldProcess($FileServer, "Remove SMB share $ShareName and folder $SharePath")) {
        Invoke-Command -ComputerName $FileServer -ScriptBlock {
            param($ShareName, $SharePath)

            $share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
            if ($share) {
                Remove-SmbShare -Name $ShareName -Force
            }

            if (Test-Path -LiteralPath $SharePath) {
                Remove-Item -LiteralPath $SharePath -Recurse -Force
            }
        } -ArgumentList $ShareName, $SharePath

        Write-Host "Removed \\$FileServer\$ShareName and $SharePath." -ForegroundColor Green
    }
}

if (-not $KeepAdAccounts) {
    Write-Step 'Active Directory cleanup'
    if ($PSCmdlet.ShouldProcess($FileServer, "Remove AD users $ApplicationAccount and $ExecutionAccount and empty OU=POC")) {
        Invoke-Command -ComputerName $FileServer -ScriptBlock {
            param($ApplicationAccount, $ExecutionAccount)

            Import-Module ActiveDirectory

            foreach ($account in @($ApplicationAccount, $ExecutionAccount)) {
                $sam = ($account -split '\\')[-1]
                $user = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
                if ($user) {
                    Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false
                }
            }

            $domainDn = (Get-ADDomain).DistinguishedName
            $pocOu = "OU=POC,$domainDn"
            $ou = Get-ADOrganizationalUnit -Identity $pocOu -ErrorAction SilentlyContinue
            if ($ou) {
                $children = Get-ADObject -SearchBase $pocOu -SearchScope OneLevel -Filter * -ErrorAction SilentlyContinue
                if (-not $children) {
                    Set-ADOrganizationalUnit -Identity $pocOu -ProtectedFromAccidentalDeletion $false
                    Remove-ADOrganizationalUnit -Identity $pocOu -Confirm:$false
                }
                else {
                    Write-Warning 'OU=POC is not empty and was not removed.'
                }
            }
        } -ArgumentList $ApplicationAccount, $ExecutionAccount

        Write-Host 'POC AD accounts cleanup completed.' -ForegroundColor Green
    }
}

Write-Step 'Cleanup finished'
Write-Host 'Secure Export POC cleanup completed.' -ForegroundColor Green
Write-Host 'Recommended verification:'
Write-Host '  - SQL Agent: no POC_Secure_Export_* jobs'
Write-Host '  - msdb: no POC_* Proxy objects'
Write-Host '  - master.sys.credentials: no POC_SSIS_Export_Credential'
if (-not $KeepDatabase) { Write-Host '  - database SSIS_Delegation_Lab does not exist' }
if (-not $KeepShare) { Write-Host "  - \\$FileServer\$ShareName does not exist" }
if (-not $KeepAdAccounts) { Write-Host '  - poc-ssis-app and poc-ssis-export do not exist in AD' }
