# PROMPTER — SQL Server CDC + Debezium + Kafka POC

## Otwarcie

Dzisiaj pokażę kompletny POC przepływu zmian z SQL Server do Kafka przy użyciu Change Data Capture i Debezium.

Nie zaczynam od Kafka. Najpierw buduję i weryfikuję każdą warstwę osobno.

Architektura jest prosta:

```text
SQL Server
-> transaction log
-> CDC
-> change tables
-> Debezium
-> Kafka
-> consumer
```

---

# Stage 1 — SQL Server CDC

W SSMS uruchamiam kolejno:

```text
00_CreateDatabase.sql
01_CreateTables.sql
02_EnableCDC.sql
03_GenerateData.sql
04_ReadChanges.sql
05_CDC_Monitoring.sql
06_CDC_Retention.sql
```

Zwracam uwagę na dedykowany filegroup `CDC_CT` oraz na job `cdc.CDC_Lab_capture`.

To ważne, bo podczas POC znaleźliśmy realny problem: cały Debezium był uruchomiony, ale nowych eventów nie było. Przyczyną nie był Kafka ani connector — nie działał capture job CDC.

---

# Stage 2 — Debezium i Kafka

Przechodzę do:

```powershell
cd .\scripts\CDC-POC\Debezium
```

W SSMS uruchamiam:

```text
00_CreateDebeziumLogin.sql
```

Następnie PowerShell:

```powershell
.\01_Start.ps1
.\02_RegisterConnector.ps1
.\03_Status.ps1
.\04_ListTopics.ps1
```

Na tym etapie oczekuję:

```text
connector RUNNING
task RUNNING
```

---

# Stage 3 — End-to-end

W jednym oknie PowerShell uruchamiam:

```powershell
.\05_Consume.ps1 -FromBeginning
```

W SSMS:

```text
06_TestChanges.sql
```

Pokazuję INSERT, UPDATE i DELETE oraz odpowiadające im eventy Debezium.

---

# Stage 4 — odporność

POC nie kończy się na happy path.

W katalogu `Tests` mam testy:

```text
restart Connect
restart Kafka
restart SQL Server
backlog
rollback
schema evolution
retention / LSN gap
ordering / duplicates
operational checks
```

Najważniejszy wniosek: restart Debezium jest bezpieczny tylko wtedy, gdy potrzebne zmiany nadal mieszczą się w retencji CDC.

Jeżeli cleanup usunie potrzebny LSN, potrzebny jest kontrolowany re-init, a nie ręczne przesuwanie offsetu.

---

# Stage 5 — Production Readiness

Na końcu sprawdzam:

```text
monitoring
security
TLS / secrets
HA / failover
capacity
retention
schema governance
runbook
GO / NO-GO
```

Dopiero wtedy POC może przejść do pilotażu na jednej lub dwóch rzeczywistych tabelach.

---

# Cleanup

Najpierw zatrzymuję konsumenta.

W PowerShell:

```powershell
cd .\scripts\CDC-POC\Debezium
.\99_StopAndCleanup.ps1
```

W SSMS:

```text
99_Cleanup.sql
```

---

# Zakończenie

Najważniejsze w tym POC nie jest samo to, że event pojawił się w Kafka.

Najważniejsze jest to, że potrafię odpowiedzieć:

- skąd zmiana pochodzi,
- gdzie może się zatrzymać,
- jak wykryć problem,
- jak wznowić przetwarzanie,
- kiedy potrzebny jest re-init,
- jak obsłużyć zmianę schematu,
- oraz kiedy rozwiązanie jest gotowe do pilotażu.
