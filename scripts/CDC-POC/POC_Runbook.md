# SQL Server CDC + Debezium + Kafka — POC Runbook

Ten dokument opisuje dokładną kolejność wykonania POC od pustego środowiska do testów odporności i cleanupu.

## Tryb zalecany — uruchamianie ze stacji developerskiej

Z katalogu:

```powershell
cd .\scripts\CDC-POC
```

uruchamiaj kolejno:

```powershell
.\Stage1.ps1
.\Stage2.ps1
.\Stage3.ps1 -FromBeginning
.\Stage4.ps1 -Test 1
.\Stage5.ps1
```

Cleanup:

```powershell
.\Cleanup.ps1
```

Wrappery używają `sqlcmd` do wykonywania plików SQL na zdalnym `sql64`, a Docker Desktop uruchamia Kafka i Debezium lokalnie na stacji developerskiej.

Domyślnie używane jest Windows Integrated Authentication. Dla SQL Authentication można przekazać `-SqlUser` i `-SqlPassword`.

Przykład:

```powershell
$pwd = Read-Host 'SQL password' -AsSecureString
.\Stage1.ps1 -ServerInstance 'sql64' -SqlUser 'laboperator' -SqlPassword $pwd
```

Stage 2 dodatkowo pyta o hasło loginu `debezium` i przekazuje je tymczasowo do skryptu tworzącego login oraz konfiguracji connectora. Hasło nie jest zapisywane do repo.

---

## Zasada pracy

Każdy Stage wykonujemy osobno. Po każdym etapie zatrzymujemy się i sprawdzamy kryterium PASS. Nie przechodzimy dalej, jeżeli poprzednia warstwa nie działa.

---

# Stage 1 — SQL Server CDC

Tryb operatorski:

```powershell
.\Stage1.ps1
```

Wrapper wykona:

```text
00_CreateDatabase.sql
01_CreateTables.sql
02_EnableCDC.sql
03_GenerateData.sql
04_ReadChanges.sql
05_CDC_Monitoring.sql
06_CDC_Retention.sql
```

Na końcu wykona kontrolę konfiguracji CDC, capture instances, filegroup i jobów.

### PASS Stage 1

```text
source DML -> transaction log -> capture job -> cdc.*_CT
```

---

# Stage 2 — Debezium + Kafka

Tryb operatorski:

```powershell
.\Stage2.ps1
```

Dla bieżącego SQLLab wrapper używa domyślnie:

```text
ServerInstance = sql64
SqlHost dla kontenera = 192.168.50.24
```

Można nadpisać:

```powershell
.\Stage2.ps1 -ServerInstance 'sql64' -SqlHost '192.168.50.24'
```

Wrapper:

1. tworzy/aktualizuje login `debezium`,
2. startuje Kafka i Connect,
3. rejestruje connector,
4. sprawdza status,
5. wyświetla topiki.

### PASS Stage 2

```text
connector RUNNING
task      RUNNING
```

---

# Stage 3 — End-to-end

Tryb operatorski:

```powershell
.\Stage3.ps1 -FromBeginning
```

Wrapper otwiera osobne okno consumer-a, a następnie wykonuje `Debezium/06_TestChanges.sql` na SQL Serverze.

Sprawdź eventy `c`, `u`, `d` oraz snapshot `r`, jeśli wykonany.

### PASS Stage 3

Każda zatwierdzona zmiana trafia do Kafka. Wycofana transakcja nie generuje zatwierdzonego zdarzenia biznesowego.

---

# Stage 4 — Recovery i failure tests

Lista testów:

```powershell
.\Stage4.ps1
```

Uruchomienie konkretnego testu:

```powershell
.\Stage4.ps1 -Test 1
```

Wrapper automatycznie uruchamia test PowerShell/SQL. Testy wymagające ręcznej operacji infrastrukturalnej otwierają dokument z instrukcją. Test 07 wymaga jawnego potwierdzenia `LAB-ONLY`.

Po każdym teście wpisz wynik PASS/FAIL i notatkę do `Tests/README.md`.

---

# Stage 5 — Production Readiness

Tryb operatorski:

```powershell
.\Stage5.ps1
```

Wrapper uruchamia `09_OperationalChecks.sql`, a następnie otwiera checklistę:

```text
Stages/Stage-05-Production-Readiness.md
```

Stage 5 kończy się świadomą decyzją GO/NO-GO.

---

# Diagnostyka — zawsze od źródła

Jeżeli eventu nie ma w Kafka:

```text
1. Czy zmiana jest w tabeli źródłowej?
2. Czy transaction log został zatwierdzony?
3. Czy cdc.CDC_Lab_capture działa?
4. Czy zmiana jest w cdc.*_CT?
5. Czy connector = RUNNING?
6. Czy task = RUNNING?
7. Czy topic istnieje?
8. Czy consumer czyta właściwy topic i offset?
```

Realny przypadek z POC: connector był poprawny, ale `cdc.CDC_Lab_capture` nie działał. Po uruchomieniu joba cały pipeline ruszył.

---

# Cleanup

Z katalogu głównego POC:

```powershell
.\Cleanup.ps1
```

Bez `-Force` wrapper wymaga wpisania:

```text
CLEANUP
```

Następnie:

1. zatrzymuje i usuwa labowy stack Debezium/Kafka,
2. uruchamia `99_Cleanup.sql`,
3. sprawdza, czy `CDC_Lab` nadal istnieje.
