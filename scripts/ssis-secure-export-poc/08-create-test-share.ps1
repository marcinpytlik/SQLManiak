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

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        if (-not (Test-Path -LiteralPath $LocalPath)) {
            New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
        }

        # Do not depend on the SmbShare PowerShell module here. In some WinRM
        # sessions on Server 2022 the cmdlets are discoverable but the module
        # cannot be imported. net.exe is available on the file server and is
        # sufficient for this POC.
        $existingShare = Get-CimInstance -ClassName Win32_Share -Filter "Name='$($ShareName.Replace("'", "''"))'" -ErrorAction SilentlyContinue

        if ($existingShare) {
            if ($existingShare.Path -ine $LocalPath) {
                throw "Share $ShareName already exists but points to '$($existingShare.Path)', expected '$LocalPath'."
            }

            & net.exe share $ShareName "/GRANT:$ExportAccount,CHANGE" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "net share failed while updating permissions for $ShareName. ExitCode=$LASTEXITCODE"
            }
        }
        else {
            & net.exe share "$ShareName=$LocalPath" "/GRANT:$ExportAccount,CHANGE" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "net share failed while creating $ShareName. ExitCode=$LASTEXITCODE"
            }
        }

        # NTFS: Modify for the export account on this folder and child objects.
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

        $verifiedShare = Get-CimInstance -ClassName Win32_Share -Filter "Name='$($ShareName.Replace("'", "''"))'" -ErrorAction Stop
        if (-not $verifiedShare) {
            throw "Share $ShareName was not found after creation/update."
        }

        $aclVerify = Get-Acl -LiteralPath $LocalPath
        $ntfsModify = @($aclVerify.Access | Where-Object {
            $_.IdentityReference.Value -ieq $ExportAccount -and
            $_.AccessControlType -eq 'Allow' -and
            (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Modify) -ne 0)
        }).Count -gt 0

        [pscustomobject]@{
            ComputerName    = $env:COMPUTERNAME
            ShareName       = $verifiedShare.Name
            SharePath       = $verifiedShare.Path
            UncPath         = "\\$env:COMPUTERNAME\$ShareName"
            ExportAccount   = $ExportAccount
            LocalPathExists = Test-Path -LiteralPath $LocalPath
            NtfsModify      = $ntfsModify
            Backend         = 'net.exe + Win32_Share'
        }
    } -ArgumentList $LocalPath, $ShareName, $ExportAccount

    Write-Host ''
    Write-Host '=== Verification ==='
    $result | Format-List
}
