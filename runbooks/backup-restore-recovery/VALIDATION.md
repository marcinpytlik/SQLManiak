# Backup / Restore / Recovery — VALIDATION

## 1. Stan bazy

```sql
SELECT
    name,
    state_desc,
    recovery_model_desc
FROM sys.databases
WHERE name = N'<TargetDb>';
```

Oczekiwany stan po zakończeniu recovery:

```text
ONLINE
```

## 2. Integralność

Repozytoryjny automated restore test wykonuje:

```sql
DBCC CHECKDB([TargetDb]) WITH NO_INFOMSGS;
```

Zachowaj wynik jako evidence.

## 3. Recovery point

Potwierdź, że baza została odtworzona do wymaganego punktu:

```text
Required restore point:
Actual restore point:
```

W przypadku point-in-time recovery potwierdź oczekiwane dane biznesowe lub techniczne z tego okresu.

## 4. RPO

Porównaj osiągnięty punkt odtworzenia z wymaganym RPO.

## 5. RTO

Zapisz:

```text
Restore start:
Restore end:
Total duration:
Required RTO:
RTO met: YES / NO
```

## 6. Dodatkowa walidacja

Sprawdź zgodnie ze scenariuszem:

- oczekiwane pliki bazy,
- oczekiwane obiekty,
- możliwość połączenia,
- podstawowe zapytania aplikacyjne.

## 7. Evidence

Zachowaj:

- użyty FULL / DIFF / LOG chain,
- output `VERIFYONLY`,
- `FILELISTONLY`,
- mapowanie `MOVE`,
- output restore,
- wynik `DBCC CHECKDB`,
- finalny stan bazy,
- czas odtworzenia.
