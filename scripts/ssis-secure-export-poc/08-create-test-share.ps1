#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FileServer = 'dc01.sqllab.local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LocalPath = 'C:\POC\SSISLab',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ShareName = 'SSISLab$',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExportAccount = 'SQLLAB\poc-ssis-export'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Orchestrator : $env:COMPUTERNAME"
Write-Host "File server  : $FileServer"
Write-Host "Local path   : $LocalPath"
Write-Host "Share        : $ShareName"
Write-Host "Account      : $ExportAccount"

if (-not $WhatIfPreference) {
    Test-WSMan -ComputerName $FileServer -ErrorAction Stop | Out-Null
}

if ($PSCmdlet.ShouldProcess($FileServer, "Create/update SMB share $ShareName for $LocalPath")) {
    $result = Invoke-Command -ComputerName $FileServer -ScriptBlock {
        param($LocalPath, $ShareName, $ExportAccount)

        $ErrorActionPreference = 'Stop'

        if (-not (Test-Path -LiteralPath $LocalPath)) {
            New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
        }

        $share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
        if (-not $share) {
            New-SmbShare -Name $ShareName -Path $LocalPath -ChangeAccess $ExportAccount | Out-Null
        }
        elseif ($share.Path -ine $LocalPath) {
            throw "Share $ShareName already exists but points to '$($share.Path)', expected '$LocalPath'."
        }

        Grant-SmbShareAccess `
            -Name $ShareName `
            -AccountName $ExportAccount `
            -AccessRight Change `
            -Force `
            -ErrorAction Stop | Out-Null

        $acl = Get-Acl -LiteralPath $LocalPath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $ExportAccount,
            'Modify',
            'ContainerInherit,ObjectInherit',
            'None',
            'Allow'
        )
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $LocalPath -AclObject $acl

        $verifiedShare = Get-SmbShare -Name $ShareName -ErrorAction Stop
        $shareAccess = Get-SmbShareAccess -Name $ShareName |
            Where-Object { $_.AccountName -ieq $ExportAccount -and $_.AccessRight -eq 'Change' -and $_.AccessControlType -eq 'Allow' }

        [pscustomobject]@{
            ComputerName     = $env:COMPUTERNAME
            ShareName        = $verifiedShare.Name
            SharePath        = $verifiedShare.Path
            UncPath          = "\\$env:COMPUTERNAME\$ShareName"
            ExportAccount    = $ExportAccount
            ShareChange      = [bool]$shareAccess
            LocalPathExists  = Test-Path -LiteralPath $LocalPath
        }
    } -ArgumentList $LocalPath, $ShareName, $ExportAccount

    Write-Host ''
    Write-Host '=== Verification ==='
    $result | Format-List
}
