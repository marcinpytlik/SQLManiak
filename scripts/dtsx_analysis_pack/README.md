# DTSX Analysis Pack

Zestaw skryptów PowerShell do analizy pakietów SSIS `.dtsx` bez Visual Studio i SSDT.

## 1. Analiza całego pakietu

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force

.\Analyze-DtsxPackage.ps1 `
  -DtsxPath "C:\Temp\Pakiet.dtsx" `
  -OutputFolder "C:\Temp\DtsxAnalysis"
```

Wyniki:
- `*.Report.md`
- `*.Report.html`
- `*.ConnectionManagers.csv`
- `*.Executables.csv`
- `*.Variables.csv`
- `*.SqlStatements.csv`
- `*.Expressions.csv`
- `*.EventHandlers.csv`
- `*.PrecedenceConstraints.csv`
- `*.PackageProperties.csv`

## 2. Wyciągnięcie SQL-i do osobnych plików

```powershell
.\Extract-DtsxSqlStatements.ps1 `
  -DtsxPath "C:\Temp\Pakiet.dtsx" `
  -OutputFolder "C:\Temp\DtsxSql"
```

## 3. Analiza komendy job stepa SQL Agent

Najpierw skopiuj komendę z kroku joba SSIS do pliku:

```powershell
notepad C:\Temp\job_step_command.txt
```

Potem:

```powershell
Get-Content "C:\Temp\job_step_command.txt" -Raw |
  .\Analyze-SsisJobCommand.ps1 -OutputFolder "C:\Temp\DtsxAnalysis"
```

Albo bez pliku:

```powershell
.\Analyze-SsisJobCommand.ps1 `
  -CommandLine '/SQL "\Folder\Pakiet" /SERVER "SQLCLUSTER\SQL2022" /CONFIGFILE "C:\Config\pakiet.dtsConfig"' `
  -OutputFolder "C:\Temp\DtsxAnalysis"
```

## Na co patrzeć w raporcie

1. `ProtectionLevel` — czy pakiet ma dane szyfrowane.
2. `ConnectionManagers.csv` — źródła i cele danych.
3. `SqlStatements.csv` oraz folder z wyciągniętymi `.sql` — zapytania wykonywane przez pakiet.
4. `Variables.csv` — zmienne używane w runtime.
5. `Expressions.csv` — dynamiczne connection stringi, ścieżki, SQL-e.
6. Analiza job stepa — `/CONFIGFILE`, `/SET`, `/CONNECTION`, `/DECRYPT`, bo job może nadpisywać to, co jest w samym pliku `.dtsx`.
