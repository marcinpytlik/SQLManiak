# Troubleshooting: Blocking

## Symptoms

Typowe sygnały:

- zapytania długo czekają,
- aplikacja raportuje timeouty,
- rośnie liczba sesji oczekujących na locki,
- jedna sesja blokuje wiele kolejnych,
- pojawiają się długie transakcje,
- wzrastają wait types z rodziny `LCK_M_*`.

## First checks

1. Sprawdź aktywne requesty i blockerów.
2. Zidentyfikuj head blocker.
3. Sprawdź czas trwania transakcji.
4. Zapisz `wait_type`, `wait_resource`, `blocking_session_id`.
5. Sprawdź plan i tekst zapytania.
6. Oceń, czy problem wynika z długiej transakcji, złej kolejności dostępu, braku indeksu, eskalacji locków lub modelu izolacji.

## Existing sources of truth

### DBA Daily Pack

- [07_Blocking_And_LongRunning.sql](../../tools/DBADaillyPack/sql/07_Blocking_And_LongRunning.sql)
- [05_Waits_Baseline_And_Delta.sql](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)
- [04_Health_Signals.sql](../../tools/DBADaillyPack/sql/04_Health_Signals.sql)

### Request PerfPack

- [03_Blocking_Snapshot.sql](../../scripts/t-sql/Reques_PerfPack/03_Blocking_Snapshot.sql)
- [04_XE_LongRunning_and_Blocking.sql](../../scripts/t-sql/Reques_PerfPack/04_XE_LongRunning_and_Blocking.sql)
- [PerfPack README](../../scripts/t-sql/Reques_PerfPack/README.md)

### Lab / reproduction

- [SqlLockSimulator](../../tools/SqlLockSimulator/)
- [SqlStressLab blocking profile](../../tools/SqlStressLab/src/SqlStressLab.Cli/profiles/demo-blocking.json)

## Evidence to collect

Minimum do ticketu lub incydentu:

- session_id,
- blocking_session_id,
- wait_type,
- wait_resource,
- czas trwania requestu,
- czas trwania transakcji,
- transaction isolation level,
- tekst zapytania,
- execution plan,
- liczba blokowanych sesji,
- kontekst aplikacyjny/host/login.

## Diagnosis

Nie kończ diagnozy na stwierdzeniu „jest blocking”.

Blocking jest **objawem mechanizmu współbieżności**. Root cause może być np.:

- długo otwarta transakcja,
- nieoptymalny plan,
- brak odpowiedniego indeksu,
- aktualizacja zbyt dużej liczby wierszy,
- niepotrzebnie wysoki poziom izolacji,
- błędna kolejność operacji w aplikacji,
- contention na pojedynczym zasobie.

## Validation

Po zmianie sprawdź:

- czy zniknął head blocker,
- czy skrócił się czas requestów,
- czy spadły wait times `LCK_M_*`,
- czy nie pojawiły się nowe skutki uboczne,
- czy aplikacja przestała raportować timeouty.

## Related

- Deadlocks — osobny obszar do dodania.
- Query Performance
- Wait Statistics
- Transaction Isolation
- RCSI / Snapshot Isolation
