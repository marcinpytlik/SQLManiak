[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SharePath,

    [string]$UserName = 'SQLLAB\poc-ssis-export'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$credential = Get-Credential -UserName $UserName -Message "Credentials for $UserName"
$testFile = Join-Path $SharePath ("poc-write-test-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))

$script = @"
`$ErrorActionPreference = 'Stop'
`$path = '$testFile'
"POC SSIS share write test - $(Get-Date -Format o)" | Set-Content -Path `$path -Encoding UTF8
if (-not (Test-Path `$path)) { throw 'Test file was not created.' }
Remove-Item `$path -Force
Write-Host 'WRITE_TEST_OK'
"@

$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
$process = Start-Process -FilePath 'powershell.exe' `
    -ArgumentList '-NoProfile','-EncodedCommand',$encoded `
    -Credential $credential `
    -Wait `
    -PassThru

if ($process.ExitCode -ne 0) {
    throw "Share write test failed. ExitCode=$($process.ExitCode)"
}

Write-Host "Share write test succeeded for $UserName on $SharePath"
