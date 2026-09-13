#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DomainController = 'dc01.sqllab.local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DomainDnsName = 'sqllab.local',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OuName = 'POC',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SamAccountName = 'poc-ssis-app',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName = 'POC SSIS Application Account',

    [Parameter()]
    [switch]$PasswordNeverExpires
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Orchestrator : $env:COMPUTERNAME"
Write-Host "AD target    : $DomainController"
Write-Host "Domain       : $DomainDnsName"
Write-Host "Account      : $SamAccountName"

if (-not $WhatIfPreference) {
    Test-WSMan -ComputerName $DomainController -ErrorAction Stop | Out-Null
}

$state = Invoke-Command -ComputerName $DomainController -ScriptBlock {
    param($DomainDnsName, $OuName, $SamAccountName)

    Import-Module ActiveDirectory -ErrorAction Stop

    $domain = Get-ADDomain -Identity $DomainDnsName
    $domainDn = $domain.DistinguishedName
    $ouDn = "OU=$OuName,$domainDn"
    $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue

    [pscustomobject]@{
        DomainDn    = $domainDn
        NetBIOSName = $domain.NetBIOSName
        OuDn        = $ouDn
        UserExists  = [bool]$user
    }
} -ArgumentList $DomainDnsName, $OuName, $SamAccountName

$securePassword = $null
if (-not $state.UserExists -and -not $WhatIfPreference) {
    $securePassword = Read-Host "Enter password for $($state.NetBIOSName)\$SamAccountName" -AsSecureString
}

if ($PSCmdlet.ShouldProcess("$DomainController / $($state.NetBIOSName)\$SamAccountName", 'Create or harden POC application account')) {
    $result = Invoke-Command -ComputerName $DomainController -ScriptBlock {
        param(
            $DomainDnsName,
            $OuName,
            $SamAccountName,
            $DisplayName,
            $SecurePassword,
            $PasswordNeverExpires
        )

        Import-Module ActiveDirectory -ErrorAction Stop

        $domain = Get-ADDomain -Identity $DomainDnsName
        $domainDn = $domain.DistinguishedName
        $netbiosName = $domain.NetBIOSName
        $ouDn = "OU=$OuName,$domainDn"
        $upn = "$SamAccountName@$DomainDnsName"

        $ou = Get-ADOrganizationalUnit -LDAPFilter "(ou=$OuName)" -SearchBase $domainDn -SearchScope OneLevel -ErrorAction SilentlyContinue
        if (-not $ou) {
            $ou = New-ADOrganizationalUnit `
                -Name $OuName `
                -Path $domainDn `
                -ProtectedFromAccidentalDeletion $true `
                -PassThru
        }

        $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties DistinguishedName -ErrorAction SilentlyContinue
        $created = $false

        if (-not $user) {
            if ($null -eq $SecurePassword) {
                throw "Password was not supplied for new account $netbiosName\$SamAccountName."
            }

            New-ADUser `
                -Name $DisplayName `
                -DisplayName $DisplayName `
                -SamAccountName $SamAccountName `
                -UserPrincipalName $upn `
                -Path $ouDn `
                -AccountPassword $SecurePassword `
                -Enabled $true `
                -ChangePasswordAtLogon $false `
                -PasswordNeverExpires ([bool]$PasswordNeverExpires)

            $created = $true
        }

        Set-ADAccountControl `
            -Identity $SamAccountName `
            -AccountNotDelegated $true `
            -TrustedForDelegation $false `
            -TrustedToAuthForDelegation $false

        $user = Get-ADUser -Identity $SamAccountName -Properties `
            Enabled,
            PasswordNeverExpires,
            AccountNotDelegated,
            TrustedForDelegation,
            TrustedToAuthForDelegation,
            DistinguishedName

        [pscustomobject]@{
            Created                    = $created
            NetBIOSName                = $netbiosName
            SamAccountName             = $user.SamAccountName
            DistinguishedName          = $user.DistinguishedName
            Enabled                    = $user.Enabled
            PasswordNeverExpires       = $user.PasswordNeverExpires
            AccountNotDelegated        = $user.AccountNotDelegated
            TrustedForDelegation       = $user.TrustedForDelegation
            TrustedToAuthForDelegation = $user.TrustedToAuthForDelegation
        }
    } -ArgumentList $DomainDnsName, $OuName, $SamAccountName, $DisplayName, $securePassword, $PasswordNeverExpires.IsPresent

    Write-Host ''
    Write-Host '=== Verification ==='
    $result | Format-List
    Write-Host ''
    Write-Host 'Expected security state:'
    Write-Host '  AccountNotDelegated          = True'
    Write-Host '  TrustedForDelegation         = False'
    Write-Host '  TrustedToAuthForDelegation   = False'
    Write-Host ''
    Write-Host "Expected SQL login: [$($result.NetBIOSName)\$SamAccountName]"
}
