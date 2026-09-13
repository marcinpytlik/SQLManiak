#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance = 'sql64.sqllab.local,1433',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CredentialName = 'POC_SSIS_Export_Credential',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Identity = 'SQLLAB\poc-ssis-export'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Orchestrator : $env:COMPUTERNAME"
Write-Host "SQL target   : $SqlInstance"
Write-Host "Credential   : $CredentialName"
Write-Host "Identity     : $Identity"

$cred = Get-Credential -UserName $Identity -Message "Password for SQL Agent Credential identity $Identity"
$plainPassword = $cred.GetNetworkCredential().Password

function Quote-SqlLiteral([string]$Value) {
    return $Value.Replace("'", "''")
}

$credentialNameLiteral = Quote-SqlLiteral $CredentialName
$identityLiteral = Quote-SqlLiteral $Identity
$passwordLiteral = Quote-SqlLiteral $plainPassword

$sql = @"
USE [master];
IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'$credentialNameLiteral')
BEGIN
    ALTER CREDENTIAL [$($CredentialName.Replace(']', ']]'))]
        WITH IDENTITY = N'$identityLiteral',
             SECRET = N'$passwordLiteral';
END
ELSE
BEGIN
    CREATE CREDENTIAL [$($CredentialName.Replace(']', ']]'))]
        WITH IDENTITY = N'$identityLiteral',
             SECRET = N'$passwordLiteral';
END;

SELECT name, credential_identity, create_date, modify_date
FROM sys.credentials
WHERE name = N'$credentialNameLiteral';
"@

$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server=$SqlInstance;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Application Name=POC-SSIS-Credential-Bootstrap;Connect Timeout=15"

try {
    $conn.Open()
    Write-Host "Connected as network identity to $SqlInstance." -ForegroundColor Green

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $reader = $cmd.ExecuteReader()

    while ($reader.Read()) {
        Write-Host ''
        Write-Host '=== Verification ==='
        Write-Host "Credential: $($reader['name'])"
        Write-Host "Identity  : $($reader['credential_identity'])"
    }

    $reader.Close()
}
finally {
    if ($conn.State -ne [System.Data.ConnectionState]::Closed) {
        $conn.Close()
    }

    $plainPassword = $null
    $passwordLiteral = $null
    $sql = $null
}

Write-Host 'Credential created/updated successfully. No password was written to the repository.'
