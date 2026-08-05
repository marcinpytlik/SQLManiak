[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [uri]$BaseUri,

    [Parameter(Mandatory)]
    [string]$SpaceKey,

    [Parameter(Mandatory)]
    [long]$RootPageId,

    [string]$InputPath =
        (Join-Path $PSScriptRoot 'ConfluenceExport'),

    [System.Management.Automation.PSCredential]$Credential,

    [switch]$PromptCredential,

    [switch]$InstallConfluencePS,

    [string[]]$Labels = @(
        'dbacentralrepository',
        'sql-server',
        'dba'
    ),

    [switch]$SkipFolderPages,

    [switch]$PublishCsvAsAttachment,

    [string]$JobManifestPath,

    [string]$DatabaseManifestPath,

    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [System.Management.Automation.PSCredential]$RepositorySqlCredential,

    [int]$PageSize = 500,

    [int]$MaxRetries = 3,

    [int]$RetryDelaySeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


function Import-RequiredModules {
    $confluenceModule =
        Get-Module -ListAvailable -Name 'ConfluencePS' |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $confluenceModule) {
        if (-not $InstallConfluencePS) {
            throw @'
Nie znaleziono modułu ConfluencePS.
Zainstaluj go poleceniem:

Install-Module ConfluencePS -Scope CurrentUser

albo uruchom publikator z parametrem -InstallConfluencePS.
'@
        }

        Install-Module `
            -Name 'ConfluencePS' `
            -Scope CurrentUser `
            -Force `
            -AllowClobber `
            -ErrorAction Stop
    }

    Import-Module `
        -Name 'ConfluencePS' `
        -Force `
        -ErrorAction Stop

    if (
        -not [string]::IsNullOrWhiteSpace(
            $RepositoryServerInstance
        )
    ) {
        $commonModulePath = Join-Path `
            $PSScriptRoot `
            'modules\DBACentralRepository.Common\DBACentralRepository.Common.psd1'

        if (-not (Test-Path -LiteralPath $commonModulePath)) {
            throw "Nie znaleziono modułu projektu: $commonModulePath"
        }

        Import-Module `
            -Name $commonModulePath `
            -Force `
            -ErrorAction Stop
    }
}


function Get-ConfluenceCredential {
    if ($null -ne $Credential) {
        return $Credential
    }

    if ($PromptCredential) {
        return Get-Credential `
            -Message 'Podaj konto lub token do Confluence'
    }

    throw @'
Nie przekazano poświadczeń Confluence.
Użyj -Credential albo -PromptCredential.

Dla API tokenu wpisz nazwę użytkownika/e-mail jako UserName,
a token jako hasło w obiekcie PSCredential.
'@
}


function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$Operation
    )

    $attempt = 0

    while ($true) {
        $attempt++

        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -ge $MaxRetries) {
                throw
            }

            Write-Warning (
                '{0} nie powiodło się. Próba {1}/{2}. {3}' -f
                $Operation,
                $attempt,
                $MaxRetries,
                $_.Exception.Message
            )

            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}


function ConvertFrom-HtmlDocument {
    param(
        [Parameter(Mandatory)]
        [string]$Html
    )

    $content = $Html

    $bodyMatch = [regex]::Match(
        $content,
        '(?is)<body[^>]*>(?<body>.*)</body>'
    )

    if ($bodyMatch.Success) {
        $content = $bodyMatch.Groups['body'].Value
    }

    $content = [regex]::Replace(
        $content,
        '(?is)<script[^>]*>.*?</script>',
        ''
    )

    $content = [regex]::Replace(
        $content,
        '(?is)<style[^>]*>.*?</style>',
        ''
    )

    $content = [regex]::Replace(
        $content,
        '(?is)<!DOCTYPE[^>]*>',
        ''
    )

    # Confluence storage wymaga fragmentu XHTML, a nie kompletnego dokumentu.
    $content = $content.Trim()

    if ([string]::IsNullOrWhiteSpace($content)) {
        return '<p>Brak danych.</p>'
    }

    return $content
}


function Get-HtmlPageTitle {
    param(
        [Parameter(Mandatory)]
        [string]$Html,

        [Parameter(Mandatory)]
        [string]$FallbackTitle
    )

    $titleMatch = [regex]::Match(
        $Html,
        '(?is)<title[^>]*>(?<title>.*?)</title>'
    )

    if ($titleMatch.Success) {
        $title = [System.Net.WebUtility]::HtmlDecode(
            $titleMatch.Groups['title'].Value.Trim()
        )

        if (-not [string]::IsNullOrWhiteSpace($title)) {
            return $title
        }
    }

    $headingMatch = [regex]::Match(
        $Html,
        '(?is)<h1[^>]*>(?<title>.*?)</h1>'
    )

    if ($headingMatch.Success) {
        $title = [regex]::Replace(
            $headingMatch.Groups['title'].Value,
            '<[^>]+>',
            ''
        )

        $title = [System.Net.WebUtility]::HtmlDecode(
            $title.Trim()
        )

        if (-not [string]::IsNullOrWhiteSpace($title)) {
            return $title
        }
    }

    return $FallbackTitle
}


$script:ChildrenCache = @{}

function Get-ChildPagesCached {
    param(
        [Parameter(Mandatory)]
        [long]$ParentPageId
    )

    $cacheKey = [string]$ParentPageId

    if ($script:ChildrenCache.ContainsKey($cacheKey)) {
        return @($script:ChildrenCache[$cacheKey])
    }

    $pages = @(
        Invoke-WithRetry `
            -Operation "Pobranie dzieci strony $ParentPageId" `
            -ScriptBlock {
                Get-ConfluenceChildPage `
                    -PageID $ParentPageId `
                    -PageSize $PageSize
            }
    )

    $script:ChildrenCache[$cacheKey] = @($pages)

    return @($pages)
}


function Add-PageToCache {
    param(
        [Parameter(Mandatory)]
        [long]$ParentPageId,

        [Parameter(Mandatory)]
        $Page
    )

    $cacheKey = [string]$ParentPageId

    if (-not $script:ChildrenCache.ContainsKey($cacheKey)) {
        $script:ChildrenCache[$cacheKey] = @()
    }

    $script:ChildrenCache[$cacheKey] =
        @($script:ChildrenCache[$cacheKey]) + @($Page)
}


function Find-ChildPage {
    param(
        [Parameter(Mandatory)]
        [long]$ParentPageId,

        [Parameter(Mandatory)]
        [string]$Title
    )

    $matches = @(
        Get-ChildPagesCached -ParentPageId $ParentPageId |
        Where-Object {
            $_.Title -eq $Title
        }
    )

    if ($matches.Count -gt 1) {
        throw (
            'Pod stroną {0} istnieje więcej niż jedna strona o tytule [{1}]. ' +
            'Usuń duplikaty przed publikacją.' -f
            $ParentPageId,
            $Title
        )
    }

    return $matches | Select-Object -First 1
}


function Get-PageId {
    param(
        [Parameter(Mandatory)]
        $Page
    )

    foreach ($name in @('ID', 'Id', 'PageID', 'PageId')) {
        if ($Page.PSObject.Properties.Name -contains $name) {
            return [long]$Page.$name
        }
    }

    throw 'Obiekt strony Confluence nie zawiera identyfikatora.'
}


function Get-PageUrl {
    param(
        [Parameter(Mandatory)]
        $Page
    )

    foreach ($name in @(
        'Url',
        'URL',
        'WebUrl',
        'WebURL',
        'Link'
    )) {
        if (
            $Page.PSObject.Properties.Name -contains $name -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$Page.$name
            )
        ) {
            $value = [string]$Page.$name

            if ([uri]::IsWellFormedUriString(
                $value,
                [System.UriKind]::Absolute
            )) {
                return $value
            }

            return (
                '{0}/{1}' -f
                $BaseUri.AbsoluteUri.TrimEnd('/'),
                $value.TrimStart('/')
            )
        }
    }

    $pageId = Get-PageId -Page $Page

    return (
        '{0}/pages/viewpage.action?pageId={1}' -f
        $BaseUri.AbsoluteUri.TrimEnd('/'),
        $pageId
    )
}


function Set-PageLabels {
    param(
        [Parameter(Mandatory)]
        [long]$PageId
    )

    foreach ($label in $Labels) {
        if ([string]::IsNullOrWhiteSpace($label)) {
            continue
        }

        try {
            Add-ConfluenceLabel `
                -PageID $PageId `
                -Label $label `
                -ErrorAction Stop |
                Out-Null
        }
        catch {
            # Etykieta mogła już istnieć. Nie zatrzymujemy publikacji strony.
            Write-Verbose (
                'Nie dodano etykiety [{0}] do strony {1}: {2}' -f
                $label,
                $PageId,
                $_.Exception.Message
            )
        }
    }
}


function Set-ConfluencePageUpsert {
    param(
        [Parameter(Mandatory)]
        [long]$ParentPageId,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Body,

        [Parameter(Mandatory)]
        [string]$SourceDescription
    )

    $existingPage = Find-ChildPage `
        -ParentPageId $ParentPageId `
        -Title $Title

    if ($null -eq $existingPage) {
        if (-not $PSCmdlet.ShouldProcess(
            "$SpaceKey/$Title",
            "Utworzenie strony z $SourceDescription"
        )) {
            return [pscustomobject]@{
                ID = 0
                Title = $Title
                Url = ''
                Action = 'WHATIF_CREATE'
            }
        }

        $createdPage = Invoke-WithRetry `
            -Operation "Utworzenie strony [$Title]" `
            -ScriptBlock {
                New-ConfluencePage `
                    -SpaceKey $SpaceKey `
                    -Title $Title `
                    -Body $Body `
                    -ParentID $ParentPageId
            }

        $pageId = Get-PageId -Page $createdPage
        Set-PageLabels -PageId $pageId
        Add-PageToCache `
            -ParentPageId $ParentPageId `
            -Page $createdPage

        return [pscustomobject]@{
            ID = $pageId
            Title = $Title
            Url = Get-PageUrl -Page $createdPage
            Action = 'CREATED'
            RawPage = $createdPage
        }
    }

    $existingId = Get-PageId -Page $existingPage

    if (-not $PSCmdlet.ShouldProcess(
        "$SpaceKey/$Title",
        "Aktualizacja strony $existingId z $SourceDescription"
    )) {
        return [pscustomobject]@{
            ID = $existingId
            Title = $Title
            Url = Get-PageUrl -Page $existingPage
            Action = 'WHATIF_UPDATE'
            RawPage = $existingPage
        }
    }

    $updatedPage = Invoke-WithRetry `
        -Operation "Aktualizacja strony [$Title]" `
        -ScriptBlock {
            Set-ConfluencePage `
                -PageID $existingId `
                -Title $Title `
                -Body $Body `
                -ParentID $ParentPageId
        }

    Set-PageLabels -PageId $existingId

    return [pscustomobject]@{
        ID = $existingId
        Title = $Title
        Url = Get-PageUrl -Page $updatedPage
        Action = 'UPDATED'
        RawPage = $updatedPage
    }
}


function Get-OrCreateFolderPage {
    param(
        [Parameter(Mandatory)]
        [long]$ParentPageId,

        [Parameter(Mandatory)]
        [string]$FolderName,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if ($SkipFolderPages) {
        return $ParentPageId
    }

    $body = @"
<h1>$([System.Net.WebUtility]::HtmlEncode($FolderName))</h1>
<p>Automatycznie zarządzana sekcja DBACentralRepository.</p>
<p><strong>Źródło:</strong> $([System.Net.WebUtility]::HtmlEncode($RelativePath))</p>
"@

    $result = Set-ConfluencePageUpsert `
        -ParentPageId $ParentPageId `
        -Title $FolderName `
        -Body $body `
        -SourceDescription "katalogu [$RelativePath]"

    if ($result.ID -eq 0) {
        # W trybie WhatIf nie znamy ID nowej strony, więc nie możemy
        # symulować tworzenia jej dzieci. Zwracamy rodzica.
        return $ParentPageId
    }

    return [long]$result.ID
}


function Register-JobDocumentationPage {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [long]$PageId,

        [Parameter(Mandatory)]
        [string]$PageUrl,

        [Parameter(Mandatory)]
        [string]$PageTitle
    )

    if ($null -eq $script:JobManifestMap) {
        return
    }

    $normalizedPath =
        [System.IO.Path]::GetFullPath($FilePath).ToUpperInvariant()

    if (-not $script:JobManifestMap.ContainsKey($normalizedPath)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($RepositoryServerInstance)) {
        Write-Warning (
            'Strona joba została opublikowana, ale nie podano ' +
            '-RepositoryServerInstance. Rejestr dokumentacji nie został zaktualizowany.'
        )
        return
    }

    $manifestRow = $script:JobManifestMap[$normalizedPath]

    [void](Invoke-DBACentralNonQuery `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Credential $RepositorySqlCredential `
        -Sql @'
EXEC [audit].[usp_RegisterJobConfluencePage]
    @InstanceId = @InstanceId,
    @JobId = @JobId,
    @ConfluencePageId = @ConfluencePageId,
    @ConfluencePageUrl = @ConfluencePageUrl,
    @PageTitle = @PageTitle;
'@ `
        -Parameters @{
            InstanceId = [long]$manifestRow.InstanceId
            JobId = [guid]$manifestRow.JobId
            ConfluencePageId = [string]$PageId
            ConfluencePageUrl = $PageUrl
            PageTitle = $PageTitle
        } `
        -ApplicationName 'DBACentralRepository Confluence Publisher')
}



function Register-DatabaseDocumentationPage {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [long]$PageId,

        [Parameter(Mandatory)]
        [string]$PageUrl,

        [Parameter(Mandatory)]
        [string]$PageTitle
    )

    if ($null -eq $script:DatabaseManifestMap) {
        return
    }

    $key = [System.IO.Path]::GetFullPath(
        $FilePath
    ).ToUpperInvariant()

    if (-not $script:DatabaseManifestMap.ContainsKey($key)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($RepositoryServerInstance)) {
        Write-Warning (
            'Strona bazy została opublikowana, ale nie podano ' +
            '-RepositoryServerInstance.'
        )
        return
    }

    $manifestRow = $script:DatabaseManifestMap[$key]

    [void](Invoke-DBACentralNonQuery `
        -ServerInstance $RepositoryServerInstance `
        -DatabaseName $RepositoryDatabase `
        -Credential $RepositorySqlCredential `
        -Sql @'
EXEC [db].[usp_RegisterDatabaseConfluencePage]
    @InstanceId=@InstanceId,
    @DatabaseName=@DatabaseName,
    @ConfluencePageId=@ConfluencePageId,
    @ConfluencePageUrl=@ConfluencePageUrl,
    @PageTitle=@PageTitle;
'@ `
        -Parameters @{
            InstanceId = [long]$manifestRow.InstanceId
            DatabaseName = [string]$manifestRow.DatabaseName
            ConfluencePageId = [string]$PageId
            ConfluencePageUrl = $PageUrl
            PageTitle = $PageTitle
        } `
        -ApplicationName 'DBACentralRepository Confluence Publisher')
}


function Publish-HtmlFile {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [long]$ParentPageId
    )

    $html = Get-Content `
        -LiteralPath $File.FullName `
        -Raw `
        -Encoding UTF8

    $title = Get-HtmlPageTitle `
        -Html $html `
        -FallbackTitle $File.BaseName

    $body = ConvertFrom-HtmlDocument -Html $html

    $result = Set-ConfluencePageUpsert `
        -ParentPageId $ParentPageId `
        -Title $title `
        -Body $body `
        -SourceDescription "pliku [$($File.FullName)]"

    if (
        $result.ID -gt 0 -and
        $result.Action -notlike 'WHATIF*'
    ) {
        Register-JobDocumentationPage `
            -FilePath $File.FullName `
            -PageId $result.ID `
            -PageUrl $result.Url `
            -PageTitle $title

        Register-DatabaseDocumentationPage `
            -FilePath $File.FullName `
            -PageId $result.ID `
            -PageUrl $result.Url `
            -PageTitle $title
    }

    if ($PublishCsvAsAttachment) {
        $csvPath = [System.IO.Path]::ChangeExtension(
            $File.FullName,
            '.csv'
        )

        if (
            $result.ID -gt 0 -and
            (Test-Path -LiteralPath $csvPath)
        ) {
            if ($PSCmdlet.ShouldProcess(
                $csvPath,
                "Dołączenie pliku CSV do strony $($result.ID)"
            )) {
                Invoke-WithRetry `
                    -Operation "Dodanie załącznika [$csvPath]" `
                    -ScriptBlock {
                        Add-ConfluenceAttachment `
                            -PageID $result.ID `
                            -FilePath $csvPath
                    } |
                    Out-Null
            }
        }
    }

    return $result
}


function Publish-Directory {
    param(
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]$Directory,

        [Parameter(Mandatory)]
        [long]$ParentPageId,

        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $relativePath = $Directory.FullName.Substring(
        $RootPath.Length
    ).TrimStart(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )

    $currentParentId = $ParentPageId

    if ($Directory.FullName -ne $RootPath) {
        $currentParentId = Get-OrCreateFolderPage `
            -ParentPageId $ParentPageId `
            -FolderName $Directory.Name `
            -RelativePath $relativePath
    }

    foreach (
        $file in Get-ChildItem `
            -LiteralPath $Directory.FullName `
            -File `
            -Filter '*.html' |
            Sort-Object Name
    ) {
        try {
            $result = Publish-HtmlFile `
                -File $file `
                -ParentPageId $currentParentId

            $script:PublicationLog.Add(
                [pscustomobject]@{
                    Source = $file.FullName
                    Title = $result.Title
                    PageId = $result.ID
                    Url = $result.Url
                    Action = $result.Action
                    Status = 'SUCCESS'
                    Error = $null
                }
            )

            Write-Host (
                '[{0}] {1}' -f
                $result.Action,
                $result.Title
            ) -ForegroundColor Green
        }
        catch {
            $script:PublicationLog.Add(
                [pscustomobject]@{
                    Source = $file.FullName
                    Title = $file.BaseName
                    PageId = $null
                    Url = $null
                    Action = 'ERROR'
                    Status = 'FAILED'
                    Error = $_.Exception.Message
                }
            )

            Write-Warning (
                'Błąd publikacji pliku [{0}]: {1}' -f
                $file.FullName,
                $_.Exception.Message
            )
        }
    }

    foreach (
        $childDirectory in Get-ChildItem `
            -LiteralPath $Directory.FullName `
            -Directory |
            Sort-Object Name
    ) {
        Publish-Directory `
            -Directory $childDirectory `
            -ParentPageId $currentParentId `
            -RootPath $RootPath
    }
}


Import-RequiredModules

$confluenceCredential = Get-ConfluenceCredential

Set-ConfluenceInfo `
    -BaseURI $BaseUri `
    -Credential $confluenceCredential `
    -PageSize $PageSize

$resolvedInputPath = (
    Resolve-Path -LiteralPath $InputPath
).Path

$rootDirectory =
    Get-Item -LiteralPath $resolvedInputPath

if (-not $rootDirectory.PSIsContainer) {
    throw "InputPath nie jest katalogiem: $resolvedInputPath"
}

$script:JobManifestMap = $null

if (-not [string]::IsNullOrWhiteSpace($JobManifestPath)) {
    $resolvedManifestPath = (
        Resolve-Path -LiteralPath $JobManifestPath
    ).Path

    $script:JobManifestMap = @{}

    foreach (
        $manifestRow in Import-Csv `
            -LiteralPath $resolvedManifestPath `
            -Delimiter ';'
    ) {
        if (
            $manifestRow.Status -ne 'SUCCESS' -or
            [string]::IsNullOrWhiteSpace($manifestRow.FilePath)
        ) {
            continue
        }

        $key = [System.IO.Path]::GetFullPath(
            $manifestRow.FilePath
        ).ToUpperInvariant()

        $script:JobManifestMap[$key] = $manifestRow
    }

    Write-Host (
        'Załadowano wpisy manifestu jobów: {0}' -f
        $script:JobManifestMap.Count
    ) -ForegroundColor DarkGray
}


$script:DatabaseManifestMap = $null

if (-not [string]::IsNullOrWhiteSpace($DatabaseManifestPath)) {
    $resolvedDatabaseManifestPath = (
        Resolve-Path -LiteralPath $DatabaseManifestPath
    ).Path

    $script:DatabaseManifestMap = @{}

    foreach (
        $manifestRow in Import-Csv `
            -LiteralPath $resolvedDatabaseManifestPath `
            -Delimiter ';'
    ) {
        if (
            $manifestRow.Status -ne 'SUCCESS' -or
            [string]::IsNullOrWhiteSpace($manifestRow.FilePath)
        ) {
            continue
        }

        $key = [System.IO.Path]::GetFullPath(
            $manifestRow.FilePath
        ).ToUpperInvariant()

        $script:DatabaseManifestMap[$key] = $manifestRow
    }

    Write-Host (
        'Załadowano wpisy manifestu baz: {0}' -f
        $script:DatabaseManifestMap.Count
    ) -ForegroundColor DarkGray
}

$script:PublicationLog =
    New-Object System.Collections.Generic.List[object]

Write-Host ''
Write-Host 'Publikacja DBACentralRepository do Confluence' -ForegroundColor Cyan
Write-Host "BaseUri: $BaseUri"
Write-Host "SpaceKey: $SpaceKey"
Write-Host "RootPageId: $RootPageId"
Write-Host "InputPath: $resolvedInputPath"
Write-Host ''

Publish-Directory `
    -Directory $rootDirectory `
    -ParentPageId $RootPageId `
    -RootPath $resolvedInputPath

$logPath = Join-Path `
    $resolvedInputPath `
    '_ConfluencePublicationLog.csv'

$script:PublicationLog |
    Export-Csv `
        -LiteralPath $logPath `
        -Delimiter ';' `
        -NoTypeInformation `
        -Encoding UTF8

$successCount = @(
    $script:PublicationLog |
    Where-Object Status -eq 'SUCCESS'
).Count

$failedCount = @(
    $script:PublicationLog |
    Where-Object Status -eq 'FAILED'
).Count

Write-Host ''
Write-Host 'Publikacja zakończona.' -ForegroundColor Green
Write-Host "Sukces: $successCount"
Write-Host "Błędy: $failedCount"
Write-Host "Log: $logPath"

if ($failedCount -gt 0) {
    exit 2
}
