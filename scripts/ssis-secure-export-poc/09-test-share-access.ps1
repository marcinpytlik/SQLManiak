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

$credential = Get-Credential -UserName $UserName -Message "Credentials for $UserName"

$driveName = 'POCSSIS'
$testFileName = "poc-write-test-{0:yyyyMMdd-HHmmss-fff}.txt" -f (Get-Date)
$driveCreated = $false

try {
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $driveName -Force -ErrorAction Stop
    }

    New-PSDrive `
        -Name $driveName `
        -PSProvider FileSystem `
        -Root $SharePath `
        -Credential $credential `
        -Scope Script `
        -ErrorAction Stop | Out-Null

    $driveCreated = $true
    $testFile = "${driveName}:\$testFileName"

    "POC SSIS share write test - $(Get-Date -Format o)" |
        Set-Content -Path $testFile -Encoding UTF8 -ErrorAction Stop

    if (-not (Test-Path -Path $testFile)) {
        throw 'Test file was not created.'
    }

    $content = Get-Content -Path $testFile -Raw -ErrorAction Stop
    if ($content -notmatch 'POC SSIS share write test') {
        throw 'Test file was created, but its content could not be verified.'
    }

    Remove-Item -Path $testFile -Force -ErrorAction Stop

    if (Test-Path -Path $testFile) {
        throw 'Test file could not be deleted.'
    }

    Write-Host 'WRITE_TEST_OK'
    Write-Host "SMB authentication succeeded for $UserName"
    Write-Host "Create/read/delete test succeeded on $SharePath"
}
finally {
    if ($driveCreated -and (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
        Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
    }
}
