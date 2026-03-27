# SqlOpsToolkit

Wspólny toolkit CLI dla DBA.

## Planowane moduły

- patch check
- cluster inspect
- security audit
- docs generate

## Architektura

- SqlOpsToolkit.Cli
- SqlOpsToolkit.Core
- SqlOpsToolkit.Infrastructure
- SqlOpsToolkit.Modules.PatchCheck

## Uruchomienie

```powershell
dotnet run --project .\src\SqlOpsToolkit.Cli -- patch check