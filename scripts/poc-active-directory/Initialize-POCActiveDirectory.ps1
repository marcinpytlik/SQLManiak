[CmdletBinding(SupportsShouldProcess = $true)]
param(
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

Import-Module ActiveDirectory -ErrorAction Stop

$domain = Get-ADDomain -Identity $DomainDnsName
$domainDn = $domain.DistinguishedName
$netbiosName = $domain.NetBIOSName
$ouDn = "OU=$OuName,$domainDn"
$upn = "$SamAccountName@$DomainDnsName"

Write-Host "Domain DNS : $DomainDnsName"
Write-Host "Domain DN  : $domainDn"
Write-Host "NetBIOS    : $netbiosName"
Write-Host "POC OU     : $ouDn"
Write-Host "Account    : $netbiosName\$SamAccountName"

$ou = Get-ADOrganizationalUnit -LDAPFilter "(ou=$OuName)" -SearchBase $domainDn -SearchScope OneLevel -ErrorAction SilentlyContinue

if (-not $ou) {
    if ($PSCmdlet.ShouldProcess($ouDn, 'Create POC organizational unit')) {
        $ouParams = @{
            Name                            = $OuName
            Path                            = $domainDn
            ProtectedFromAccidentalDeletion = $true
            PassThru                        = $true
        }

        $ou = New-ADOrganizationalUnit @ouParams
        Write-Host "Created OU: $($ou.DistinguishedName)"
    }
}
else {
    Write-Host "OU already exists: $($ou.DistinguishedName)"
}

$user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties AccountNotDelegated,TrustedForDelegation,TrustedToAuthForDelegation,PasswordNeverExpires -ErrorAction SilentlyContinue

if (-not $user) {
    $securePassword = Read-Host "Enter password for $netbiosName\$SamAccountName" -AsSecureString

    if ($PSCmdlet.ShouldProcess("$netbiosName\$SamAccountName", 'Create POC application account')) {
        $userParams = @{
            Name                  = $DisplayName
            DisplayName           = $DisplayName
            SamAccountName        = $SamAccountName
            UserPrincipalName     = $upn
            Path                  = $ouDn
            AccountPassword       = $securePassword
            Enabled               = $true
            ChangePasswordAtLogon = $false
            PasswordNeverExpires  = $PasswordNeverExpires.IsPresent
        }

        New-ADUser @userParams
        Write-Host "Created account: $netbiosName\$SamAccountName"
    }
}
else {
    Write-Host "Account already exists: $netbiosName\$SamAccountName"

    if ($user.DistinguishedName -notlike "*,$ouDn") {
        Write-Warning "Account exists outside $ouDn. It will not be moved automatically."
    }
}

# Security hardening for the POC account.
# AccountNotDelegated = "Account is sensitive and cannot be delegated".
# TrustedForDelegation / TrustedToAuthForDelegation explicitly remain disabled.
if ($PSCmdlet.ShouldProcess("$netbiosName\$SamAccountName", 'Disable delegation and mark account as sensitive')) {
    $accountControlParams = @{
        Identity                   = $SamAccountName
        AccountNotDelegated        = $true
        TrustedForDelegation       = $false
        TrustedToAuthForDelegation = $false
    }

    Set-ADAccountControl @accountControlParams
}

$user = Get-ADUser -Identity $SamAccountName -Properties Enabled,PasswordNeverExpires,AccountNotDelegated,TrustedForDelegation,TrustedToAuthForDelegation,MemberOf,DistinguishedName

Write-Host ''
Write-Host '=== Verification ==='
$user | Select-Object `
    SamAccountName,
    UserPrincipalName,
    DistinguishedName,
    Enabled,
    PasswordNeverExpires,
    AccountNotDelegated,
    TrustedForDelegation,
    TrustedToAuthForDelegation

Write-Host ''
Write-Host 'Expected security state:'
Write-Host '  AccountNotDelegated          = True'
Write-Host '  TrustedForDelegation         = False'
Write-Host '  TrustedToAuthForDelegation   = False'
Write-Host ''
Write-Host 'SQL Server login name:'
Write-Host "  [$netbiosName\$SamAccountName]"
