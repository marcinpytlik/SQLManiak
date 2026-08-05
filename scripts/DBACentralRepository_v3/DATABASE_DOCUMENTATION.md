# Dokumentacja baz i wykrywanie zmian struktury

## Wdrożenie

Uruchom pliki `15`, `16` i `17`, a następnie `98_Verify_Installation.sql`.

## Pierwszy skan

```powershell
.\Collect-DatabaseSchema.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository'
```

Pierwszy skan tworzy baseline. Zmiany są widoczne od drugiego poprawnego skanu.

## Wykrywane zmiany

- dodanie lub usunięcie tabeli,
- dodanie lub usunięcie widoku,
- zmiana definicji widoku,
- dodanie lub usunięcie kolumny,
- zmiana typu, długości, precyzji, skali lub nullability kolumny.

## Generowanie stron baz

```powershell
.\Export-DatabaseDocumentationPages.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository'
```

## Publikacja do Confluence

```powershell
.\Publish-ConfluencePages.ps1 `
    -BaseUri 'https://confluence.example.pl' `
    -SpaceKey 'DBA' `
    -RootPageId 123456 `
    -InputPath '.\ConfluenceExport\03. Dokumentacja baz' `
    -DatabaseManifestPath '.\ConfluenceExport\03. Dokumentacja baz\_Manifest stron baz.csv' `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository' `
    -PromptCredential
```

## Uprawnienia źródłowe

Konto kolektora musi widzieć metadane baz. Zalecane minimum to dostęp do baz
oraz `VIEW DEFINITION`. Bez tego snapshot może być niepełny.
