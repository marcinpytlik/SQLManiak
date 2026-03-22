# SqlStressLab

SqlStressLab to lekkie narzędzie CLI w C# do generowania równoległego obciążenia SQL Server.

## Funkcje
- wielu workerów
- wiele iteracji
- mixed authentication
- ustawienia sesji SET z pliku .sql
- Text / StoredProcedure
- NonQuery / Scalar / Reader
- raport JSON / CSV

## Uruchomienie
```powershell
$env:SQLSTRESSLAB_PASSWORD="BardzoMocneHaslo!123"
dotnet run --project .\src\SqlStressLab.Cli\SqlStressLab.Cli.csproj -- .\src\SqlStressLab.Cli\profiles\demo-select.json