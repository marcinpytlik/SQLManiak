param(
    [ValidateRange(1,9)]
    [int]$Test,
    [string]$ServerInstance = 'sql64',
    [string]$SqlUser,
    [SecureString]$SqlPassword
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$tests = Join-Path $root 'Tests'
. (Join-Path $root 'POC.Common.ps1')

$map = @{
    1 = '01_RestartConnect.ps1'
    2 = '02_RestartKafka.ps1'
    3 = '03_RestartSqlServer.md'
    4 = '04_Backlog.sql'
    5 = '05_Rollback.sql'
    6 = '06_SchemaEvolution.sql'
    7 = '07_RetentionGap.sql'
    8 = '08_OrderingAndDuplicates.sql'
    9 = '09_OperationalChecks.sql'
}

if (-not $PSBoundParameters.ContainsKey('Test')) {
    Write-Host 'Stage 4 tests:'
    1..9 | ForEach-Object { Write-Host ("{0}. {1}" -f $_, $map[$_]) }
    Write-Host ''
    Write-Host 'Run for example: .\Stage4.ps1 -Test 1'
    exit 0
}

$file = $map[$Test]
$path = Join-Path $tests $file
Write-PocStep "Stage 4 - Test $Test - $file"

switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
    '.ps1' {
        Assert-DockerDesktop
        & $path
    }
    '.sql' {
        if ($Test -eq 7) {
            Write-PocWarn 'Test 07 is LAB-ONLY and can intentionally remove CDC history / create an LSN gap.'
            $answer = Read-Host 'Type LAB-ONLY to continue'
            if ($answer -ne 'LAB-ONLY') {
                Write-Host 'Cancelled.'
                exit 0
            }
        }
        Invoke-PocSqlFile -ServerInstance $ServerInstance -Path $path -SqlUser $SqlUser -SqlPassword $SqlPassword
    }
    '.md' {
        Write-PocWarn 'This test contains manual infrastructure steps and cannot be safely automated.'
        Write-Host "Open and follow: $path"
        Start-Process $path
    }
    default {
        throw "Unsupported test file: $path"
    }
}

Write-PocPass "Test $Test execution finished. Record PASS/FAIL and notes in Tests/README.md."
