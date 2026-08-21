# DBACentralRepository - Windows Scheduled Tasks

Pliki:

- `Invoke-DBACentralRepositoryCollector.ps1` - wspólny wrapper wykonawczy i logowanie.
- `Install-DBACentralRepositoryScheduledTasks.ps1` - instalacja/aktualizacja 4 zadań Windows Task Scheduler.

## Docelowe harmonogramy

| Collector | Harmonogram |
|---|---|
| Database Performance | co 5 minut |
| Table Usage | co 15 minut |
| Inventory | codziennie 01:00 |
| Database Schema | codziennie 02:00 |

## Instalacja

Skopiuj oba skrypty do:

`C:\Users\blad\Documents\GitHub\SQLManiak\scripts\DBACentralRepository_v3`

Uruchom PowerShell **jako administrator**:

```powershell
cd C:\Users\blad\Documents\GitHub\SQLManiak\scripts\DBACentralRepository_v3

.\Install-DBACentralRepositoryScheduledTasks.ps1 `
    -RepositoryServerInstance 'localhost' `
    -RepositoryDatabase 'DBACentralRepository' `
    -TableUsageTargetId 1
```

Installer poprosi o hasło konta Windows. Hasło jest używane wyłącznie przy rejestracji zadań przez Task Scheduler i nie jest zapisywane w skrypcie ani w repo.

## Wariant tylko do testu

Jeśli zadania mają działać wyłącznie, gdy użytkownik jest zalogowany:

```powershell
.\Install-DBACentralRepositoryScheduledTasks.ps1 `
    -RepositoryServerInstance 'localhost' `
    -RepositoryDatabase 'DBACentralRepository' `
    -TableUsageTargetId 1 `
    -UseCurrentInteractiveUser
```

## Weryfikacja

```powershell
Get-ScheduledTask -TaskPath '\DBACentralRepository\' |
    Select-Object TaskName, State
```

Stan i ostatnie wykonanie:

```powershell
Get-ScheduledTask -TaskPath '\DBACentralRepository\' |
ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo

    [pscustomobject]@{
        TaskName       = $_.TaskName
        State          = $_.State
        LastRunTime    = $info.LastRunTime
        LastTaskResult = $info.LastTaskResult
        NextRunTime    = $info.NextRunTime
    }
} | Format-Table -AutoSize
```

## Test ręczny

```powershell
Start-ScheduledTask `
    -TaskPath '\DBACentralRepository\' `
    -TaskName 'DBACR - Performance Collector'
```

Po chwili:

```powershell
Get-ScheduledTaskInfo `
    -TaskPath '\DBACentralRepository\' `
    -TaskName 'DBACR - Performance Collector'
```

Logi:

`C:\DBACentralRepository\Logs`

## Health po stronie SQL

```sql
SELECT
    CollectorCode,
    LastSuccessAt,
    MinutesSinceSuccess,
    HealthStatus
FROM report.vCollectorHealth
ORDER BY CollectorCode;
```

Po poprawnym działaniu schedulerów docelowo:

- `PERFORMANCE` -> `OK`
- `TABLE_USAGE` -> `OK`
- `INVENTORY` -> `OK`
- `DATABASE_SCHEMA` -> `OK`

## Odinstalowanie zadań

```powershell
.\Install-DBACentralRepositoryScheduledTasks.ps1 -Uninstall
```

## Ważne

`Collect-DatabaseSchema.ps1` został w wrapperze wywołany z parametrami:

`-RepositoryServerInstance` oraz `-RepositoryDatabase`.

Przed rejestracją produkcyjnego zadania warto potwierdzić jego aktualną sygnaturę:

```powershell
Get-Help .\Collect-DatabaseSchema.ps1 -Full
```

Jeśli skrypt ma dodatkowe obowiązkowe parametry, należy uzupełnić sekcję `DatabaseSchema` w wrapperze.
