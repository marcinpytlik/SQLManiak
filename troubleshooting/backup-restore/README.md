# Troubleshooting: Backup / Restore

Backup nie jest celem samym w sobie.

Celem jest:

> **możliwość odtworzenia danych do wymaganego punktu i w wymaganym czasie.**

Dlatego pytanie:

> „Czy backup job był zielony?”

jest dopiero początkiem.

---

# Diagnostic flow

```text
Backup/restore problem
        |
        v
Define required RPO / RTO
        |
        v
Check backup history in msdb
        |
        v
Validate FULL / DIFF / LOG chain
        |
        v
Validate media / access / space
        |
        v
RESTORE VERIFYONLY
        |
        v
Real restore test
        |
        v
DBCC CHECKDB + database state
        |
        v
Measure restore duration
        |
        v
Compare with RTO
        |
        v
Tune / redesign if needed
```

---

# 1. First checks

1. Jaka baza i jaki recovery model?
2. Jakie jest wymagane RPO?
3. Jakie jest wymagane RTO?
4. Kiedy wykonał się ostatni poprawny FULL?
5. Kiedy wykonał się ostatni poprawny DIFF?
6. Kiedy wykonał się ostatni poprawny LOG?
7. Czy istnieje ciągły restore chain do wymaganego punktu?
8. Czy pliki backupów są dostępne?
9. Czy konto usługi SQL ma dostęp do lokalizacji?
10. Czy na target jest wystarczająco miejsca?
11. Czy backup przechodzi `RESTORE VERIFYONLY`?
12. Czy został wykonany realny restore test?

---

# 2. Existing sources of truth

## Strategy

- [Backup Strategy](../../docs/Inside_SQL_Server2022_Databases/Backup_Strategy.md)
- [Backup Overview](../../docs/Inside_SQL_Server2022_Databases/Backup_Overview.md)

## Automated restore test

- [Restore_AutomatedTest.ps1](../../docs/RestoreTest/PowerShell/Restore_AutomatedTest.ps1)

## Backup / Restore performance

- [Lab 07 – Backup/Restore Performance](../../labs/06-internals/Lab07_Backup_Restore_Perf/)

## VLDB

- [VLDB Backup/Restore Checklist](../../docs/VLDB_Survival_Kit_SQLServer_2022/CHECKLISTS/02_Backup_Restore_VLDB.md)

## Restore capacity

- [EstimateRestoreSpace](../../scripts/t-sql/backup/restoresize.sql)

## Operational errors

- [SQL Server Errors – Extended](../../docs/SQL_Errors_Operationa/SQL_Errors_Extended.md)

---

# 3. Recovery model first

Recovery model definiuje, jakie scenariusze odzyskiwania są możliwe.

Repo opisuje trzy główne modele:

```text
SIMPLE
FULL
BULK_LOGGED
```

## SIMPLE

Nie wykonujemy log backupów.

Restore opiera się na:

```text
FULL
+
optional DIFF
```

RPO jest ograniczone częstotliwością tych backupów.

## FULL

Pozwala na:

```text
FULL
+
DIFF
+
LOG
+
point-in-time restore
```

Regularne log backupy są elementem strategii recovery.

## BULK_LOGGED

Wymaga świadomego podejścia do operacji bulk i point-in-time recovery.

Nie zakładaj strategii restore bez sprawdzenia recovery model.

---

# 4. Backup history in msdb

Podstawowym źródłem historii jest `msdb`.

Najważniejsze obiekty:

```text
msdb.dbo.backupset
msdb.dbo.backupmediafamily
msdb.dbo.restorehistory
```

Lab Backup/Restore Performance również używa:

```text
msdb.dbo.backupset
backupmediafamily
```

do analizy:

- czasu backupu,
- rozmiaru,
- kompresji,
- wydajności.

Podczas incydentu zbierz co najmniej:

```text
database_name
type
backup_start_date
backup_finish_date
first_lsn
last_lsn
database_backup_lsn
checkpoint_lsn
backup_size
compressed_backup_size
physical_device_name
```

---

# 5. Backup completed != recoverable chain

Pojedynczy poprawny backup nie gwarantuje możliwości odtworzenia do wymaganego punktu.

Dla typowego FULL recovery sprawdzamy ciąg:

```text
FULL
  |
  +--> optional DIFF
  |
  +--> LOG 1
  +--> LOG 2
  +--> LOG 3
  ...
```

Musisz mieć wszystkie wymagane elementy chaina.

## FULL

FULL jest bazą odtworzenia.

## DIFF

DIFF bazuje na odpowiednim FULL.

Nie wystarczy znaleźć „najświeższy diff”; musi pasować do właściwej bazy różnicowej.

## LOG

Log backupy muszą tworzyć ciąg umożliwiający dojście do wymaganego punktu.

Jeżeli w środku brakuje elementu, restore chain może być niekompletny.

---

# 6. COPY_ONLY

Repo opisuje `COPY_ONLY` jako backup, który nie powinien zakłócać normalnej strategii backupowej.

Szczególnie ważne dla FULL:

> COPY_ONLY FULL nie zmienia differential base.

Przy analizie chaina sprawdzaj, czy dany backup był `COPY_ONLY`.

---

# 7. RESTORE VERIFYONLY

Repo bardzo wyraźnie rozdziela:

```text
RESTORE VERIFYONLY
```

od:

```text
real restore test
```

W [Backup Overview](../../docs/Inside_SQL_Server2022_Databases/Backup_Overview.md) jest wręcz zasada:

> `RESTORE VERIFYONLY` ≠ test restore.

VERIFYONLY jest przydatnym etapem kontroli backupu, ale nie potwierdza całego procesu odtworzenia aplikacyjnego.

---

# 8. Real restore test

Repo ma gotowy:

- [Restore_AutomatedTest.ps1](../../docs/RestoreTest/PowerShell/Restore_AutomatedTest.ps1)

Skrypt realizuje:

```text
RESTORE FULL
    |
    v
RESTORE DIFF
    |
    v
RESTORE LOG chain
    |
    +--> optional STOPAT
    |
    v
RECOVERY
    |
    v
DBCC CHECKDB
    |
    v
database state
    |
    v
restore duration report
```

To jest dużo ważniejszy test niż sprawdzenie statusu joba.

---

# 9. Point-in-time restore

W scenariuszu FULL recovery potrzebujemy odpowiedzieć:

> Do jakiego dokładnie momentu musimy wrócić?

Automatyczny restore test w repo wspiera:

```text
STOPAT
```

czyli punktowe odtworzenie z chaina log backupów.

Evidence powinno zawierać:

```text
required restore timestamp
available FULL
available DIFF
available LOG range
actual recovered timestamp
```

---

# 10. NORECOVERY / RECOVERY

Przy sekwencyjnym restore:

```text
FULL -> NORECOVERY
DIFF -> NORECOVERY
LOG  -> NORECOVERY
...
last LOG -> RECOVERY
```

Błędne użycie `RECOVERY` zbyt wcześnie może zakończyć możliwość dokładania kolejnych backupów do restore chaina.

Dlatego kolejność operacji musi być częścią runbooka.

---

# 11. CHECKSUM

Repo Backup Overview opisuje `CHECKSUM` jako dodatkową ochronę podczas tworzenia backupu.

Jeżeli strategia tego wymaga, sprawdzaj:

- czy backup został wykonany z checksum,
- czy źródłowe bazy mają PAGE_VERIFY = CHECKSUM,
- czy podczas backupu nie wystąpiły błędy I/O.

Backup nie powinien być traktowany jako sposób na ukrycie corruption.

---

# 12. DBCC CHECKDB after restore

Automatyczny test restore z repo wykonuje:

```sql
DBCC CHECKDB([DbName]) WITH NO_INFOMSGS;
```

po odtworzeniu.

To jest bardzo dobry model walidacji.

Minimalna walidacja po restore:

```text
database ONLINE
DBCC CHECKDB clean
expected recovery point
expected files
expected application objects/data
```

---

# 13. RPO vs RTO

## RPO

Odpowiada na pytanie:

> Ile danych możemy stracić?

Przykład z repo:

```text
LOG every 15 min
→ target RPO około 15 min
```

## RTO

Odpowiada na pytanie:

> Jak długo może trwać przywrócenie usługi?

RTO trzeba **zmierzyć**.

Automatyczny restore test zapisuje duration, a Lab 07 koncentruje się na pomiarze throughput i czasów backup/restore.

---

# 14. Backup performance

Repo posiada:

- [Lab 07 – Backup/Restore Performance](../../labs/06-internals/Lab07_Backup_Restore_Perf/)

Lab testuje wpływ:

```text
striped backups
compression
MAXTRANSFERSIZE
BUFFERCOUNT
BLOCKSIZE
```

na:

- czas,
- throughput,
- rozmiar.

Nie optymalizuj parametrów backupu na ślepo.

Testuj je w konkretnym środowisku storage i workloadzie.

---

# 15. Restore performance

Restore często jest bardziej biznesowo istotny niż sam czas backupu.

Mierz:

```text
FULL restore duration
DIFF restore duration
LOG restore duration
recovery duration
CHECKDB duration
total RTO
```

Jeżeli:

```text
backup = 30 min
restore = 3 h
RTO = 1 h
```

strategia nie spełnia wymagania mimo „szybkiego backupu”.

---

# 16. VLDB

Repo ma osobną checklistę:

- [VLDB Backup/Restore Checklist](../../docs/VLDB_Survival_Kit_SQLServer_2022/CHECKLISTS/02_Backup_Restore_VLDB.md)

Zawiera m.in.:

- filegroup backups,
- częstsze backupy części aktywnej,
- striping,
- kompresję,
- szyfrowanie,
- piecemeal restore,
- okresowe testy restore.

Dla dużych baz nie zakładaj automatycznie, że:

```text
one FULL backup
+
one restore strategy
```

jest optymalnym rozwiązaniem.

---

# 17. Capacity before restore

Repo ma:

- [EstimateRestoreSpace](../../scripts/t-sql/backup/restoresize.sql)

Skrypt korzysta z:

```text
RESTORE FILELISTONLY
```

i szacuje:

- wymagany rozmiar plików,
- dostępne miejsce,
- margines bezpieczeństwa,
- możliwość wykonania restore.

To jest ważne szczególnie przy:

- restore na inny serwer,
- DR,
- migracji,
- dużych bazach,
- innych layoutach dyskowych.

---

# 18. FILELISTONLY and MOVE

Przed restore na nową instancję sprawdź:

```text
LogicalName
PhysicalName
Type
Size
FileGroupName
```

i przygotuj poprawne:

```sql
WITH MOVE ...
```

Nie zakładaj, że ścieżki source istnieją na target.

---

# 19. Error 3013

Repo klasyfikuje:

```text
3013 – BACKUP/RESTORE error
```

jako błąd ogólny.

Najważniejsza zasada:

> Nie diagnozuj 3013 jako root cause.

Sprawdź błędy poprzedzające go.

Często istotny jest wcześniejszy numer, np.:

```text
3201
3313
```

---

# 20. Error 3201

Repo opisuje:

```text
3201 – Cannot open backup device
```

Typowe obszary:

- ścieżka nie istnieje,
- udział sieciowy niedostępny,
- konto usługi SQL nie ma uprawnień,
- storage nie jest dostępny.

Sprawdź zarówno:

```text
NTFS ACL
```

jak i:

```text
share permissions
```

dla lokalizacji sieciowej.

---

# 21. Error 3313

Repo opisuje:

```text
3313 – error during redo/undo
```

Sprawdź:

- restore chain,
- integralność backupów,
- kolejność FULL/DIFF/LOG,
- wcześniejsze błędy,
- media,
- stan recovery.

Nie skupiaj się wyłącznie na samym 3313.

---

# 22. Error 9002

```text
9002 – transaction log full
```

może być związany również ze strategią backupów w modelu FULL.

Repo sugeruje diagnostykę:

```sql
SELECT
    name,
    log_reuse_wait_desc
FROM sys.databases;
```

Jeżeli baza jest w FULL i oczekuje na log backup, problemem może być brak poprawnego cyklu backupów logu.

Ale zawsze sprawdź `log_reuse_wait_desc`; nie zakładaj przyczyny.

---

# 23. Slow backup / restore

Jeżeli backup lub restore jest zbyt wolny, zbierz:

```text
start time
finish time
duration
backup size
compressed size
throughput MB/s
number of stripes
compression
target storage
source storage
CPU
I/O latency
concurrent workload
```

Powiązane moduły:

- [I/O](../io/)
- [CPU](../cpu/)
- [Wait Statistics](../wait-statistics/)

---

# 24. Striped backups

Lab w repo testuje striped backup.

Striping może poprawić throughput, ale wynik zależy od:

- storage,
- liczby urządzeń,
- przepustowości ścieżki,
- CPU przy kompresji,
- konfiguracji backup engine.

Nie zakładaj, że więcej plików zawsze oznacza proporcjonalnie szybszy backup.

---

# 25. Compression

Kompresja może:

- zmniejszyć rozmiar,
- zmniejszyć I/O,
- zwiększyć wykorzystanie CPU.

Dlatego przy problemie backup performance koreluj:

```text
backup throughput
storage throughput
CPU
compression ratio
```

---

# 26. Encryption

Repo Backup Strategy rekomenduje szyfrowanie backupów produkcyjnych.

Przy restore zaszyfrowanego backupu potrzebujesz odpowiednich kluczy/certyfikatów.

Strategia DR musi obejmować nie tylko:

```text
.bak
```

ale również wymagany materiał kryptograficzny.

Backup, którego nie można odszyfrować w DR, nie spełnia celu recovery.

---

# 27. System databases

Repo Backup Strategy uwzględnia:

```text
master
msdb
model
```

Nie buduj recovery planu tylko dla baz użytkownika.

W recovery całej instancji mogą być potrzebne:

- loginy,
- SQL Agent jobs,
- operators,
- linked servers/configuration,
- historia i automatyzacja.

---

# 28. Evidence to collect

Minimalny zestaw do incydentu:

```text
Database:
Recovery model:

Required RPO:
Required RTO:

Last FULL:
Last DIFF:
Last LOG:

FULL first/last LSN:
DIFF base LSN:
LOG chain range:

Backup file locations:
File accessibility:
Backup checksum:
VERIFYONLY result:

Restore target:
Available disk space:
FILELISTONLY:
MOVE mapping:

Restore start:
Restore finish:
Restore duration:
Recovered to timestamp:

DBCC CHECKDB:
Database state:

Error numbers:
ERRORLOG / SQL Agent history:
Storage / I/O evidence:
```

---

# 29. Validation

Poprawny test recovery powinien potwierdzić:

```text
backup files exist
+
restore chain is complete
+
files are readable
+
restore succeeds
+
database is ONLINE
+
DBCC CHECKDB succeeds
+
required restore point is reached
+
restore duration <= RTO
```

To jest rzeczywista definicja sukcesu.

---

# 30. Czego nie robić

## Nie traktuj zielonego joba jako dowodu recoverability

Job potwierdza wykonanie zadania, nie pełny proces DR.

## Nie traktuj VERIFYONLY jako pełnego testu restore

Repo jawnie rozróżnia te dwie rzeczy.

## Nie patrz tylko na najnowszy backup

Sprawdź cały wymagany chain.

## Nie testuj restore dopiero podczas awarii

RTO musi być znane wcześniej.

## Nie optymalizuj tylko czasu backupu

Restore time może być ważniejszy.

## Nie zakładaj, że source paths istnieją na DR

Sprawdź FILELISTONLY i MOVE.

## Nie zapominaj o certyfikatach dla encrypted backups

Bez nich restore może być niemożliwy.

## Nie resetuj strategii FULL/DIFF/LOG przypadkowymi backupami

Rozumiej wpływ COPY_ONLY i differential base.

---

# 31. Related troubleshooting

- [I/O](../io/)
- [CPU](../cpu/)
- [Wait Statistics](../wait-statistics/)
- [Query Performance](../query-performance/)

---

# TL;DR

```text
"Backup succeeded"
      |
      v
Not enough.

Check:
FULL / DIFF / LOG chain
      |
      v
VERIFYONLY
      |
      v
real restore
      |
      v
DBCC CHECKDB
      |
      v
correct recovery point
      |
      v
measure total restore time
      |
      v
RTO met?
      |
   +--+--+
   |     |
  YES   NO
   |     |
   |   redesign/tune
   |
recoverability confirmed
```
