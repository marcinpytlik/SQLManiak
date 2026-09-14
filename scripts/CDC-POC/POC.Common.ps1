Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-PocStep {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-PocPass {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Write-PocWarn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Get-SqlcmdAuthArgs {
    param(
        [string]$SqlUser,
        [SecureString]$SqlPassword
    )

    if ([string]::IsNullOrWhiteSpace($SqlUser)) {
        return @('-E')
    }

    if ($null -eq $SqlPassword) {
        throw 'SqlPassword is required when SqlUser is supplied.'
    }

    return @('-U', $SqlUser)
}

function Invoke-PocSqlFile {
    param(
        [Parameter(Mandatory)][string]$ServerInstance,
        [Parameter(Mandatory)][string]$Path,
        [string]$SqlUser,
        [SecureString]$SqlPassword,
        [hashtable]$Variables
    )

    Assert-Command 'sqlcmd'

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "SQL file not found: $Path"
    }

    $args = @('-S', $ServerInstance, '-b', '-r', '1')
    $args += Get-SqlcmdAuthArgs -SqlUser $SqlUser -SqlPassword $SqlPassword
    $args += @('-i', $Path)

    if ($Variables) {
        foreach ($key in $Variables.Keys) {
            $args += @('-v', "$key=$($Variables[$key])")
        }
    }

    $previousPassword = $env:SQLCMDPASSWORD
    try {
        if (-not [string]::IsNullOrWhiteSpace($SqlUser)) {
            $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword)
            try {
                $env:SQLCMDPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            }
            finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }

        & sqlcmd @args
        if ($LASTEXITCODE -ne 0) {
            throw "sqlcmd failed with exit code $LASTEXITCODE for file: $Path"
        }
    }
    finally {
        $env:SQLCMDPASSWORD = $previousPassword
    }
}

function Invoke-PocQuery {
    param(
        [Parameter(Mandatory)][string]$ServerInstance,
        [Parameter(Mandatory)][string]$Query,
        [string]$SqlUser,
        [SecureString]$SqlPassword
    )

    Assert-Command 'sqlcmd'

    $args = @('-S', $ServerInstance, '-b', '-r', '1')
    $args += Get-SqlcmdAuthArgs -SqlUser $SqlUser -SqlPassword $SqlPassword
    $args += @('-Q', $Query)

    $previousPassword = $env:SQLCMDPASSWORD
    try {
        if (-not [string]::IsNullOrWhiteSpace($SqlUser)) {
            $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword)
            try {
                $env:SQLCMDPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            }
            finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }

        & sqlcmd @args
        if ($LASTEXITCODE -ne 0) {
            throw "sqlcmd query failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        $env:SQLCMDPASSWORD = $previousPassword
    }
}

function Assert-DockerDesktop {
    Assert-Command 'docker'
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker is installed but Docker Desktop / Docker Engine is not available.'
    }
}
