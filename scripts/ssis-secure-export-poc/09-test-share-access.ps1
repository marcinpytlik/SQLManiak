[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SharePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UserName = 'SQLLAB\poc-ssis-export'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($SharePath -notmatch '^\\\\[^\\]+\\[^\\]+') {
    throw "SharePath must be a UNC path, e.g. \\DC01\SSISLab$. Received: $SharePath"
}

Import-Module SmbShare -ErrorAction Stop

$credential = Get-Credential -UserName $UserName -Message "Credentials for $UserName"
$testFileName = "poc-write-test-{0:yyyyMMdd-HHmmss-fff}.txt" -f (Get-Date)
$testFile = Join-Path -Path $SharePath -ChildPath $testFileName
$mappingCreated = $false

try {
    # Establish an SMB session with the dedicated export account without
    # starting a local interactive process as that account.
    New-SmbMapping `
        -RemotePath $SharePath `
        -Credential $credential `
        -Persistent $false `
        -ErrorAction Stop | Out-Null

    $mappingCreated = $true

    Write-Host "SharePath = $SharePath"
    Write-Host "TestFile  = $testFile"

    "POC SSIS share write test - $(Get-Date -Format o)" |
        Set-Content -LiteralPath $testFile -Encoding UTF8 -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $testFile)) {
        throw 'Test file was not created.'
    }

    $content = Get-Content -LiteralPath $testFile -Raw -ErrorAction Stop
    if ($content -notmatch 'POC SSIS share write test') {
        throw 'Test file was created, but its content could not be verified.'
    }

    Remove-Item -LiteralPath $testFile -Force -ErrorAction Stop

    if (Test-Path -LiteralPath $testFile) {
        throw 'Test file could not be deleted.'
    }

    Write-Host 'WRITE_TEST_OK'
    Write-Host "SMB authentication succeeded for $UserName"
    Write-Host "Create/read/delete test succeeded on $SharePath"
}
finally {
    if ($mappingCreated) {
        Remove-SmbMapping `
            -RemotePath $SharePath `
            -Force `
            -UpdateProfile:$false `
            -ErrorAction SilentlyContinue
    }
}
