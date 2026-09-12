#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = 'C:\SSIS\POC\WriteShareTest.dtsx',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputShare = '\\DC01\SSISLab$'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Run this script in Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.'
}

$managedDtsCandidates = @(
    'C:\Program Files\Microsoft SQL Server\160\DTS\Binn\Microsoft.SqlServer.ManagedDTS.dll',
    'C:\Program Files\Microsoft SQL Server\150\DTS\Binn\Microsoft.SqlServer.ManagedDTS.dll',
    'C:\Program Files\Microsoft SQL Server\140\DTS\Binn\Microsoft.SqlServer.ManagedDTS.dll',
    'C:\Program Files\Microsoft SQL Server\130\DTS\Binn\Microsoft.SqlServer.ManagedDTS.dll'
)

$managedDts = $managedDtsCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $managedDts) {
    throw 'Microsoft.SqlServer.ManagedDTS.dll was not found. SSIS runtime components are required on this server.'
}

Write-Host "Using SSIS runtime: $managedDts"
Add-Type -Path $managedDts

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

# Build the PowerShell payload that will be launched by Execute Process Task.
# It intentionally contains no credentials. The child process inherits the
# identity of the SQL Agent SSIS Proxy account.
$payload = @"
`$ErrorActionPreference = 'Stop'
`$share = '$OutputShare'
`$file = Join-Path -Path `$share -ChildPath ('ssis-proxy-test-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
`$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
`$content = @(
    'POC Secure SSIS Export - Stage 4',
    ('Timestamp={0}' -f (Get-Date -Format 'o')),
    ('MachineName={0}' -f `$env:COMPUTERNAME),
    ('WindowsIdentity={0}' -f `$identity),
    ('OutputFile={0}' -f `$file)
)
`$content | Set-Content -LiteralPath `$file -Encoding UTF8
if (-not (Test-Path -LiteralPath `$file)) {
    throw 'Output file was not created.'
}
"@

$encodedPayload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payload))
$powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$powershellDir = Split-Path -Path $powershellExe -Parent

$package = New-Object Microsoft.SqlServer.Dts.Runtime.Package
$package.Name = 'WriteShareTest'
$package.Description = 'POC Stage 4 - write a diagnostic file to SMB through SQL Agent SSIS Proxy.'
$package.CreatorName = 'SQLManiak POC runtime generator'
$package.ProtectionLevel = [Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]::DontSaveSensitive
$package.DelayValidation = $false
$package.SaveCheckpoints = $false

$executable = $package.Executables.Add('STOCK:ExecuteProcessTask')
$taskHost = [Microsoft.SqlServer.Dts.Runtime.TaskHost]$executable
$taskHost.Name = 'Write test file to SMB share'
$taskHost.Description = 'Runs Windows PowerShell under the SQL Agent Proxy identity and writes a diagnostic file to the SMB share.'

function Set-TaskProperty {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.SqlServer.Dts.Runtime.TaskHost]$TaskHost,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        $Value
    )

    $property = $TaskHost.Properties[$Name]
    if ($null -eq $property) {
        throw "SSIS ExecuteProcessTask property '$Name' was not found."
    }

    $property.SetValue($TaskHost, $Value)
}

Set-TaskProperty -TaskHost $taskHost -Name 'Executable' -Value $powershellExe
Set-TaskProperty -TaskHost $taskHost -Name 'Arguments' -Value "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedPayload"
Set-TaskProperty -TaskHost $taskHost -Name 'WorkingDirectory' -Value $powershellDir
Set-TaskProperty -TaskHost $taskHost -Name 'FailTaskIfReturnCodeIsNotSuccessValue' -Value $true
Set-TaskProperty -TaskHost $taskHost -Name 'SuccessValue' -Value 0
Set-TaskProperty -TaskHost $taskHost -Name 'TimeOut' -Value 60
Set-TaskProperty -TaskHost $taskHost -Name 'TerminateAfterTimeout' -Value $true

$application = New-Object Microsoft.SqlServer.Dts.Runtime.Application
$application.SaveToXml($OutputPath, $package, $null)

# Immediately reload the generated file with the same installed SSIS runtime.
# This catches malformed/incompatible package XML before SQL Agent is involved.
$loadedPackage = $application.LoadPackage($OutputPath, $null)
if ($null -eq $loadedPackage) {
    throw "The generated package could not be reloaded: $OutputPath"
}

if ($loadedPackage.Executables.Count -ne 1) {
    throw "Unexpected executable count in generated package: $($loadedPackage.Executables.Count)"
}

Write-Host 'PACKAGE_GENERATION_OK'
Write-Host "Package      : $OutputPath"
Write-Host "Output share : $OutputShare"
Write-Host "Package name : $($loadedPackage.Name)"
Write-Host "Tasks        : $($loadedPackage.Executables.Count)"
Write-Host 'The package was generated and reloaded successfully by the installed SSIS runtime.'
