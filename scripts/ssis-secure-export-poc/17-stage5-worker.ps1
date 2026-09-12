#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SqlInstance = 'localhost',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Database = 'SSIS_Delegation_Lab',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputShare = '\\DC01\SSISLab$',

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$MaxItems = 10,

    [Parameter()]
    [ValidateRange(0, 3600)]
    [int]$RetryDelaySeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DbConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )

    $connectionString =
        "Server=$Server;Database=$DatabaseName;Integrated Security=SSPI;Application Name=POC Stage5 Export Worker;Connect Timeout=15;"

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()
    return $connection
}

function Invoke-ClaimRequest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [Guid]$WorkerToken
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = 'dbo.usp_ClaimExportRequest'
    $null = $command.Parameters.Add('@WorkerToken', [System.Data.SqlDbType]::UniqueIdentifier)
    $command.Parameters['@WorkerToken'].Value = $WorkerToken

    $reader = $command.ExecuteReader()
    try {
        if (-not $reader.Read()) {
            return $null
        }

        return [pscustomobject]@{
            RequestId    = [Guid]$reader['RequestId']
            CustomerId   = [int]$reader['CustomerId']
            ReportDate   = [datetime]$reader['ReportDate']
            RequestedBy  = [string]$reader['RequestedBy']
            RequestedAt  = [datetime]$reader['RequestedAt']
            AttemptCount = [int]$reader['AttemptCount']
            MaxAttempts  = [int]$reader['MaxAttempts']
        }
    }
    finally {
        $reader.Close()
        $command.Dispose()
    }
}

function Invoke-CompleteRequest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [Guid]$RequestId,
        [Parameter(Mandatory = $true)]
        [Guid]$WorkerToken,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = 'dbo.usp_CompleteExportRequest'

    $null = $command.Parameters.Add('@RequestId', [System.Data.SqlDbType]::UniqueIdentifier)
    $command.Parameters['@RequestId'].Value = $RequestId

    $null = $command.Parameters.Add('@WorkerToken', [System.Data.SqlDbType]::UniqueIdentifier)
    $command.Parameters['@WorkerToken'].Value = $WorkerToken

    $null = $command.Parameters.Add('@OutputFile', [System.Data.SqlDbType]::NVarChar, 500)
    $command.Parameters['@OutputFile'].Value = $OutputFile

    try {
        $null = $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Invoke-FailRequest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [Guid]$RequestId,
        [Parameter(Mandatory = $true)]
        [Guid]$WorkerToken,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [int]$RetryDelay
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = 'dbo.usp_FailExportRequest'

    $null = $command.Parameters.Add('@RequestId', [System.Data.SqlDbType]::UniqueIdentifier)
    $command.Parameters['@RequestId'].Value = $RequestId

    $null = $command.Parameters.Add('@WorkerToken', [System.Data.SqlDbType]::UniqueIdentifier)
    $command.Parameters['@WorkerToken'].Value = $WorkerToken

    $null = $command.Parameters.Add('@ErrorMessage', [System.Data.SqlDbType]::NVarChar, 4000)
    $command.Parameters['@ErrorMessage'].Value = $Message.Substring(0, [Math]::Min($Message.Length, 4000))

    $null = $command.Parameters.Add('@RetryDelaySeconds', [System.Data.SqlDbType]::Int)
    $command.Parameters['@RetryDelaySeconds'].Value = $RetryDelay

    try {
        $null = $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Output "Stage5 worker identity: $identity"
Write-Output "SQL instance          : $SqlInstance"
Write-Output "Database              : $Database"
Write-Output "Output share          : $OutputShare"

$connection = $null
$processed = 0
$failures = 0

try {
    $connection = New-DbConnection -Server $SqlInstance -DatabaseName $Database

    for ($i = 1; $i -le $MaxItems; $i++) {
        $workerToken = [Guid]::NewGuid()
        $request = Invoke-ClaimRequest -Connection $connection -WorkerToken $workerToken

        if ($null -eq $request) {
            Write-Output 'No eligible queue items.'
            break
        }

        $processed++
        Write-Output ("Claimed RequestId={0}, CustomerId={1}, Attempt={2}/{3}" -f `
            $request.RequestId, $request.CustomerId, $request.AttemptCount, $request.MaxAttempts)

        try {
            # Deterministic filename makes retries idempotent for this POC.
            $fileName = 'export-{0}-customer-{1}-{2}.txt' -f `
                $request.RequestId.ToString('D'), `
                $request.CustomerId, `
                $request.ReportDate.ToString('yyyyMMdd')

            $outputFile = Join-Path -Path $OutputShare -ChildPath $fileName

            $content = @(
                'POC Secure Export - Stage 5',
                ('RequestId={0}' -f $request.RequestId),
                ('CustomerId={0}' -f $request.CustomerId),
                ('ReportDate={0:yyyy-MM-dd}' -f $request.ReportDate),
                ('RequestedBy={0}' -f $request.RequestedBy),
                ('RequestedAt={0:O}' -f $request.RequestedAt),
                ('Attempt={0}/{1}' -f $request.AttemptCount, $request.MaxAttempts),
                ('WorkerIdentity={0}' -f $identity),
                ('MachineName={0}' -f $env:COMPUTERNAME),
                ('CompletedAt={0}' -f (Get-Date -Format 'o')),
                ('OutputFile={0}' -f $outputFile)
            )

            $content | Set-Content -LiteralPath $outputFile -Encoding UTF8 -Force

            if (-not (Test-Path -LiteralPath $outputFile)) {
                throw "Output file was not created: $outputFile"
            }

            Invoke-CompleteRequest `
                -Connection $connection `
                -RequestId $request.RequestId `
                -WorkerToken $workerToken `
                -OutputFile $outputFile

            Write-Output ("COMPLETED RequestId={0}; OutputFile={1}" -f $request.RequestId, $outputFile)
        }
        catch {
            $failures++
            $failureMessage = $_.Exception.ToString()

            try {
                Invoke-FailRequest `
                    -Connection $connection `
                    -RequestId $request.RequestId `
                    -WorkerToken $workerToken `
                    -Message $failureMessage `
                    -RetryDelay $RetryDelaySeconds
            }
            catch {
                Write-Error ("Could not update failed queue item {0}: {1}" -f $request.RequestId, $_.Exception.Message)
            }

            Write-Error ("FAILED RequestId={0}: {1}" -f $request.RequestId, $failureMessage)
        }
    }
}
finally {
    if ($null -ne $connection) {
        $connection.Dispose()
    }
}

Write-Output ("Stage5 worker finished. Processed={0}; Failures={1}" -f $processed, $failures)

if ($failures -gt 0) {
    throw "Stage5 worker encountered $failures failed request(s). Queue retry/final-failure state was updated."
}
