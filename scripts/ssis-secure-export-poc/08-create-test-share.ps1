[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$LocalPath = 'C:\POC\SSISLab',
    [string]$ShareName = 'SSISLab$',
    [string]$ExportAccount = 'SQLLAB\poc-ssis-export'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script in an elevated PowerShell session on the file server.'
}

if (-not (Test-Path $LocalPath)) {
    if ($PSCmdlet.ShouldProcess($LocalPath, 'Create export folder')) {
        New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
    }
}

$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if (-not $share) {
    if ($PSCmdlet.ShouldProcess($ShareName, "Create SMB share for $LocalPath")) {
        New-SmbShare -Name $ShareName -Path $LocalPath -ChangeAccess $ExportAccount | Out-Null
    }
}
else {
    Write-Host "Share already exists: \\$env:COMPUTERNAME\$ShareName"
    Grant-SmbShareAccess -Name $ShareName -AccountName $ExportAccount -AccessRight Change -Force -ErrorAction SilentlyContinue | Out-Null
}

# NTFS: Modify for the export account on this folder and child objects.
$acl = Get-Acl -Path $LocalPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $ExportAccount,
    'Modify',
    'ContainerInherit,ObjectInherit',
    'None',
    'Allow'
)
$acl.SetAccessRule($rule)
Set-Acl -Path $LocalPath -AclObject $acl

Write-Host ''
Write-Host 'Share configured:'
Write-Host "  UNC : \\$env:COMPUTERNAME\$ShareName"
Write-Host "  Path: $LocalPath"
Write-Host "  Account: $ExportAccount"
Write-Host '  Share permission: Change'
Write-Host '  NTFS permission : Modify'
