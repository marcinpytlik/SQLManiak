# SQL Server CDC + Debezium + Kafka — POC Runbook

Ten dokument opisuje dokładną kolejność wykonania POC od pustego środowiska do testów odporności i cleanupu.

## Zasada pracy

Każdy Stage wykonujemy osobno. Po każdym etapie zatrzymujemy się i sprawdzamy kryterium PASS. Nie przechodzimy dalej, jeżeli poprzednia warstwa nie działa.

---

# Stage 1 — SQL Server CDC

## 1.1. Utworzenie bazy

Uruchom w SSMS:

```text
00_CreateDatabase.sql
```

Sprawdź:

- baza `CDC_Lab` istnieje,
- recovery model = FULL,
- istnieje filegroup `CDC_CT`,
- istnieje osobny plik NDF dla `CDC_CT`.

## 1.2. Tabele źródłowe

Uruchom:

```text
01_CreateTables.sql
```

Powinny powstać:

```text
dbo.Customer
dbo.CustomerOrder
```

## 1.3. Włączenie CDC

Uruchom:

```text
02_EnableCDC.sql
```

Sprawdź:

```sql
USE CDC_Lab;
GO
EXEC sys.sp_cdc_help_change_data_capture;
EXEC sys.sp_cdc_help_jobs;
GO
```

Najważniejsze: job `cdc.CDC_Lab_capture` musi działać.

## 1.4. Generowanie zmian

Uruchom:

```text
03_GenerateData.sql
```

## 1.5. Odczyt CDC

Uruchom:

```text
04_ReadChanges.sql
```

Potwierdź obecność danych w `cdc.*_CT`.

## 1.6. Monitoring

Uruchom:

```text
05_CDC_Monitoring.sql
```

Sprawdź sesje skanowania, błędy, joby i latencję.

## 1.7. Retention

Uruchom:

```text
06_CDC_Retention.sql
```

Nie skracaj agresywnie retention poza testami laboratoryjnymi.

### PASS Stage 1

```text
source DML -> transaction log -> capture job -> cdc.*_CT
```

---

# Stage 2 — Debezium + Kafka

Przejdź do:

```powershell
cd .\scripts\CDC-POC\Debezium
```

## 2.1. Login SQL

Uruchom w SSMS:

```text
00_CreateDebeziumLogin.sql
```

## 2.2. Start infrastruktury

```powershell
.\01_Start.ps1
```

Kontrola:

```powershell
docker ps
```

Powinny działać:

```text
sqllab-kafka
sqllab-debezium-connect
```

## 2.3. Rejestracja connectora

```powershell
.\02_RegisterConnector.ps1
```

## 2.4. Status

```powershell
.\03_Status.ps1
```

Oczekujemy:

```text
connector RUNNING
task      RUNNING
```

## 2.5. Topiki

```powershell
.\04_ListTopics.ps1
```

### PASS Stage 2

Debezium potrafi połączyć się z SQL Server i Kafka.

---

# Stage 3 — End-to-end

## 3.1. Consumer

W pierwszym oknie PowerShell:

```powershell
.\05_Consume.ps1 -FromBeginning
```

## 3.2. Zmiany testowe

W SSMS:

```text
06_TestChanges.sql
```

Sprawdź eventy `c`, `u`, `d` oraz snapshot `r`, jeśli wykonany.

### PASS Stage 3

Każda zatwierdzona zmiana trafia do Kafka. Wycofana transakcja nie generuje zatwierdzonego zdarzenia biznesowego.

---

# Stage 4 — Recovery i failure tests

Przejdź do:

```text
Tests/README.md
```

Wykonuj testy w kolejności 01–09. Po każdym teście wpisz wynik PASS/FAIL i notatkę.

Szczególnie ważne:

- restart Connect,
- restart Kafka,
- restart SQL,
- backlog recovery,
- rollback,
- schema evolution,
- utrata LSN,
- ordering i duplicate delivery.

Test retention/LSN gap wykonuj na końcu — jest destrukcyjny względem historii CDC.

---

# Stage 5 — Production Readiness

Przejdź do:

```text
Stages/Stage-05-Production-Readiness.md
```

Wypełnij checklistę oraz decyzję GO/NO-GO.

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

## Krok 1 — zatrzymaj consumer

`Ctrl+C` w oknie konsumenta.

## Krok 2 — usuń connector i kontenery

```powershell
cd .\scripts\CDC-POC\Debezium
.\99_StopAndCleanup.ps1
```

## Krok 3 — usuń warstwę SQL

W SSMS:

```text
99_Cleanup.sql
```

## Krok 4 — kontrola

```powershell
docker ps -a
```

oraz:

```sql
SELECT DB_ID(N'CDC_Lab') AS CDC_Lab_DatabaseId;
```

Po pełnym cleanupie baza powinna nie istnieć, a kontenery POC powinny być usunięte.
