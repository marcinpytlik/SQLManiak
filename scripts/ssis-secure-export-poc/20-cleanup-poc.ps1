#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SqlComputer = 'sql64.sqllab.local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance = 'localhost',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FileServer = 'dc01.sqllab.local',

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

# Orchestrator model:
#   DEWELOPER -> SQL64 over WinRM/5985
#   DEWELOPER -> DC01  over WinRM/5985
#
# Start PowerShell on DEWELOPER with:
#   runas /netonly /user:SQLLAB\Administrator pwsh.exe
#
# The script does not remote from SQL64 to DC01, so it avoids WinRM double-hop.

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Skip {
    param([Parameter(Mandatory = $true)][string]$Text)
    Write-Host "[SKIP] $Text" -ForegroundColor DarkGray
}

function Test-WinRMTarget {
    param([Parameter(Mandatory = $true)][string]$ComputerName)

    try {
        Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-Warning "WinRM check failed for $ComputerName. $($_.Exception.Message)"
        return $false
    }
}

if ($Force) {
    $ConfirmPreference = 'None'
}

if (-not $Force -and -not $WhatIfPreference) {
    Write-Warning 'This script removes the Secure Export POC from SQL64 and DC01.'
    Write-Warning 'It removes SQL Agent objects, Credential, logins, optionally the POC database, worker files, SMB share/folder and optionally AD accounts.'
    Write-Warning 'The script is idempotent and can be run repeatedly.'
    Write-Warning 'Run with -WhatIf first if you want to review the actions.'

    $confirmation = Read-Host 'Type DELETE-POC to continue'
    if ($confirmation -ne 'DELETE-POC') {
        throw 'Cleanup cancelled.'
    }
}

$errors = [System.Collections.Generic.List[string]]::new()

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

Write-Step 'Pre-flight'
Write-Host "Orchestrator : $env:COMPUTERNAME"
Write-Host "SQL target   : $SqlComputer"
Write-Host "SQL instance : $SqlInstance"
Write-Host "File/AD      : $FileServer"

if (-not $WhatIfPreference) {
    $sqlWinRM = Test-WinRMTarget -ComputerName $SqlComputer
    $dcWinRM  = Test-WinRMTarget -ComputerName $FileServer

    if ($sqlWinRM) { Write-Ok "WinRM reachable: $SqlComputer" }
    if ($dcWinRM)  { Write-Ok "WinRM reachable: $FileServer" }
}

Write-Step 'SQL Server cleanup'
if ($PSCmdlet.ShouldProcess($SqlComputer, 'Remove POC SQL Agent jobs/schedules/proxies/Credential/logins and optionally database')) {
    try {
        Invoke-Command -ComputerName $SqlComputer -ScriptBlock {
            param($Instance, $Query)

            if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
                throw "Invoke-Sqlcmd is not available on $env:COMPUTERNAME."
            }

            Invoke-Sqlcmd `
                -ServerInstance $Instance `
                -Database master `
                -Query $Query `
                -AbortOnError
        } -ArgumentList $SqlInstance, $sqlCleanup

        Write-Ok 'SQL cleanup completed.'
    }
    catch {
        $message = "SQL cleanup failed on $SqlComputer. $($_.Exception.Message)"
        $errors.Add($message)
        Write-Warning $message
    }
}

if (-not $KeepLocalFiles) {
    Write-Step 'SQL64 worker files cleanup'

    if ($PSCmdlet.ShouldProcess($SqlComputer, "Remove $LocalPocPath")) {
        try {
            $removed = Invoke-Command -ComputerName $SqlComputer -ScriptBlock {
                param($Path)

                if (Test-Path -LiteralPath $Path) {
                    Remove-Item -LiteralPath $Path -Recurse -Force
                    return $true
                }

                return $false
            } -ArgumentList $LocalPocPath

            if ($removed) {
                Write-Ok "Removed $LocalPocPath on $SqlComputer."
            }
            else {
                Write-Skip "$LocalPocPath does not exist on $SqlComputer."
            }
        }
        catch {
            $message = "Worker files cleanup failed on $SqlComputer. $($_.Exception.Message)"
            $errors.Add($message)
            Write-Warning $message
        }
    }
}
else {
    Write-Skip 'Worker files retained by -KeepLocalFiles.'
}

if (-not $KeepShare) {
    Write-Step 'DC01 SMB share cleanup'

    if ($PSCmdlet.ShouldProcess($FileServer, "Remove SMB share $ShareName and folder $SharePath")) {
        try {
            $shareResult = Invoke-Command -ComputerName $FileServer -ScriptBlock {
                param($Name, $Path)

                $shareRemoved = $false
                $folderRemoved = $false

                $share = Get-SmbShare -Name $Name -ErrorAction SilentlyContinue
                if ($share) {
                    Remove-SmbShare -Name $Name -Force
                    $shareRemoved = $true
                }

                if (Test-Path -LiteralPath $Path) {
                    Remove-Item -LiteralPath $Path -Recurse -Force
                    $folderRemoved = $true
                }

                [pscustomobject]@{
                    ShareRemoved  = $shareRemoved
                    FolderRemoved = $folderRemoved
                }
            } -ArgumentList $ShareName, $SharePath

            if ($shareResult.ShareRemoved) {
                Write-Ok "Removed SMB share \\$FileServer\$ShareName."
            }
            else {
                Write-Skip "SMB share \\$FileServer\$ShareName does not exist."
            }

            if ($shareResult.FolderRemoved) {
                Write-Ok "Removed $SharePath on $FileServer."
            }
            else {
                Write-Skip "$SharePath does not exist on $FileServer."
            }
        }
        catch {
            $message = "SMB cleanup failed on $FileServer. $($_.Exception.Message)"
            $errors.Add($message)
            Write-Warning $message
        }
    }
}
else {
    Write-Skip 'SMB share/folder retained by -KeepShare.'
}

if (-not $KeepAdAccounts) {
    Write-Step 'Active Directory cleanup'

    if ($PSCmdlet.ShouldProcess($FileServer, "Remove AD users $ApplicationAccount and $ExecutionAccount and empty OU=POC")) {
        try {
            $adResult = Invoke-Command -ComputerName $FileServer -ScriptBlock {
                param($AppAccount, $ExecAccount)

                Import-Module ActiveDirectory

                $removedUsers = [System.Collections.Generic.List[string]]::new()
                $missingUsers = [System.Collections.Generic.List[string]]::new()

                foreach ($account in @($AppAccount, $ExecAccount)) {
                    $sam = ($account -split '\\')[-1]
                    $user = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue

                    if ($user) {
                        Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false
                        $removedUsers.Add($sam)
                    }
                    else {
                        $missingUsers.Add($sam)
                    }
                }

                $domainDn = (Get-ADDomain).DistinguishedName
                $pocOu = "OU=POC,$domainDn"
                $ouRemoved = $false
                $ouMissing = $false
                $ouNotEmpty = $false

                $ou = Get-ADOrganizationalUnit -Identity $pocOu -ErrorAction SilentlyContinue
                if ($ou) {
                    $children = @(Get-ADObject -SearchBase $pocOu -SearchScope OneLevel -Filter * -ErrorAction SilentlyContinue)

                    if ($children.Count -eq 0) {
                        Set-ADOrganizationalUnit -Identity $pocOu -ProtectedFromAccidentalDeletion $false
                        Remove-ADOrganizationalUnit -Identity $pocOu -Confirm:$false
                        $ouRemoved = $true
                    }
                    else {
                        $ouNotEmpty = $true
                    }
                }
                else {
                    $ouMissing = $true
                }

                [pscustomobject]@{
                    RemovedUsers = @($removedUsers)
                    MissingUsers = @($missingUsers)
                    OuRemoved    = $ouRemoved
                    OuMissing    = $ouMissing
                    OuNotEmpty   = $ouNotEmpty
                }
            } -ArgumentList $ApplicationAccount, $ExecutionAccount

            foreach ($sam in $adResult.RemovedUsers) {
                Write-Ok "Removed AD user $sam."
            }

            foreach ($sam in $adResult.MissingUsers) {
                Write-Skip "AD user $sam does not exist."
            }

            if ($adResult.OuRemoved) {
                Write-Ok 'Removed empty OU=POC.'
            }
            elseif ($adResult.OuMissing) {
                Write-Skip 'OU=POC does not exist.'
            }
            elseif ($adResult.OuNotEmpty) {
                Write-Warning 'OU=POC is not empty and was not removed.'
            }
        }
        catch {
            $message = "Active Directory cleanup failed on $FileServer. $($_.Exception.Message)"
            $errors.Add($message)
            Write-Warning $message
        }
    }
}
else {
    Write-Skip 'AD accounts retained by -KeepAdAccounts.'
}

Write-Step 'Verification'

if (-not $WhatIfPreference) {
    try {
        $sqlVerify = Invoke-Command -ComputerName $SqlComputer -ScriptBlock {
            param($Instance)

            if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
                throw "Invoke-Sqlcmd is not available on $env:COMPUTERNAME."
            }

            $verifyQuery = @"
SET NOCOUNT ON;
SELECT
    (SELECT COUNT(*) FROM msdb.dbo.sysjobs WHERE name LIKE N'POC[_]%') AS PocJobs,
    (SELECT COUNT(*) FROM msdb.dbo.sysproxies WHERE name LIKE N'POC[_]%') AS PocProxies,
    (SELECT COUNT(*) FROM sys.credentials WHERE name = N'POC_SSIS_Export_Credential') AS PocCredentials,
    CASE WHEN DB_ID(N'SSIS_Delegation_Lab') IS NULL THEN 0 ELSE 1 END AS PocDatabase;
"@

            Invoke-Sqlcmd -ServerInstance $Instance -Database master -Query $verifyQuery -AbortOnError |
                Select-Object PocJobs, PocProxies, PocCredentials, PocDatabase
        } -ArgumentList $SqlInstance

        Write-Host "SQL jobs        : $($sqlVerify.PocJobs)"
        Write-Host "SQL proxies     : $($sqlVerify.PocProxies)"
        Write-Host "SQL credentials : $($sqlVerify.PocCredentials)"
        Write-Host "POC database    : $($sqlVerify.PocDatabase)"
    }
    catch {
        Write-Warning "SQL verification failed. $($_.Exception.Message)"
    }

    if (-not $KeepLocalFiles) {
        try {
            $workerExists = Invoke-Command -ComputerName $SqlComputer -ScriptBlock {
                param($Path)
                Test-Path -LiteralPath $Path
            } -ArgumentList $LocalPocPath

            Write-Host "Worker path exists : $workerExists"
        }
        catch {
            Write-Warning "Worker path verification failed. $($_.Exception.Message)"
        }
    }

    if (-not $KeepShare -or -not $KeepAdAccounts) {
        try {
            $dcVerify = Invoke-Command -ComputerName $FileServer -ScriptBlock {
                param($Name, $Path, $AppAccount, $ExecAccount)

                Import-Module ActiveDirectory

                $appSam = ($AppAccount -split '\\')[-1]
                $execSam = ($ExecAccount -split '\\')[-1]

                [pscustomobject]@{
                    ShareExists   = [bool](Get-SmbShare -Name $Name -ErrorAction SilentlyContinue)
                    FolderExists  = Test-Path -LiteralPath $Path
                    AppUserExists = [bool](Get-ADUser -Filter "SamAccountName -eq '$appSam'" -ErrorAction SilentlyContinue)
                    ExecUserExists = [bool](Get-ADUser -Filter "SamAccountName -eq '$execSam'" -ErrorAction SilentlyContinue)
                }
            } -ArgumentList $ShareName, $SharePath, $ApplicationAccount, $ExecutionAccount

            if (-not $KeepShare) {
                Write-Host "SMB share exists   : $($dcVerify.ShareExists)"
                Write-Host "SMB folder exists  : $($dcVerify.FolderExists)"
            }

            if (-not $KeepAdAccounts) {
                Write-Host "App AD user exists : $($dcVerify.AppUserExists)"
                Write-Host "Exec AD user exists: $($dcVerify.ExecUserExists)"
            }
        }
        catch {
            Write-Warning "DC01 verification failed. $($_.Exception.Message)"
        }
    }
}
else {
    Write-Skip 'Verification is not executed during -WhatIf.'
}

Write-Step 'Cleanup finished'

if ($errors.Count -eq 0) {
    Write-Host 'Secure Export POC cleanup completed without reported errors.' -ForegroundColor Green
}
else {
    Write-Warning "Cleanup completed with $($errors.Count) error(s):"
    foreach ($item in $errors) {
        Write-Warning " - $item"
    }
    throw 'POC cleanup was only partially successful. Review the warnings above and run the script again after fixing the failed target.'
}
