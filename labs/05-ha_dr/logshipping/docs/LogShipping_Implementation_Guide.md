> **"Durability doesn't stop at the data file – it continues across geography."**  
> — SQLManiak

## 🎯 Cel
Wdrożenie **Disaster Recovery** dla środowiska produkcyjnego SQL Server 2022 z wykorzystaniem mechanizmu **Log Shipping** pomiędzy dwiema niezależnymi instancjami, działającymi **poza klastrem FCI**.

---

## 🧩 Architektura rozwiązania

| Element | Nazwa / przykład |
|----------|------------------|
| **Primary** | `SQLPROD01\INST1` |
| **Secondary (DR)** | `SQLDR01\INST1` |
| **Tryb** | Warm Standby (STANDBY / NORECOVERY) |
| **Harmonogram** | Backup/Copy/Restore co 5 minut |
| **Udział sieciowy** | `\\sqlbackup\logs` (konto SQL Agent z RW) |
| **Replikowane bazy** | Kluczowe bazy produkcyjne (ERP, Billing, Config) |

---

## ⚙️ Checklista wdrożenia

1. **Wykonaj pełną kopię bazy** z Primary:
   ```sql
   BACKUP DATABASE [YourDB] TO DISK='\\sqlbackup\logs\YourDB_full.bak' WITH INIT, COMPRESSION;
   ```
2. **Odtwórz na Secondary**:
   ```sql
   RESTORE DATABASE [YourDB]
   FROM DISK='\\sqlbackup\logs\YourDB_full.bak'
   WITH NORECOVERY;
   ```
3. **Skonfiguruj Log Shipping** (GUI lub T-SQL) z parametrami:
   - ścieżki: `Backup`, `Copy`, `Restore`
   - `restore delay = 0–60 s`
   - `restore threshold = 45–60 min`
   - alerty w SQL Agent (ID 14420, 14421)
4. **Zweryfikuj joby**:
   - `LSBackup_<DB>`
   - `LSCopy_<DB>`
   - `LSRestore_<DB>`
5. **Testuj opóźnienie i integralność danych** po kilku cyklach.

---

## 🔍 Weryfikacja konfiguracji

### Primary
```sql
SELECT primary_database, backup_directory, backup_share, backup_retention_period
FROM msdb.dbo.log_shipping_primary_databases;

SELECT primary_database, last_backup_date, last_backup_file
FROM msdb.dbo.log_shipping_monitor_primary;
```

### Secondary
```sql
SELECT secondary_database, restore_mode, disconnect_users, restore_delay, restore_threshold
FROM msdb.dbo.log_shipping_secondary_databases;

SELECT secondary_database, last_restored_file, last_restored_date
FROM msdb.dbo.log_shipping_monitor_secondary;
```

---

## 📊 Monitorowanie metryk

| Licznik / DMV | Opis | Znaczenie diagnostyczne |
|----------------|------|--------------------------|
| `Log Flushes/sec` | Ilość zapisów bufora logu na sekundę | Koreluje z częstotliwością `COMMIT`. |
| `Log Bytes Flushed/sec` | Ilość bajtów zapisanych do logu | Ocena obciążenia I/O logu. |
| `Log Flush Wait Time (ms)` | Średni czas oczekiwania na flush logu | Wąskie gardła dysku logowego. |
| `Checkpoint Pages/sec` | Ilość stron zapisywanych przez Checkpoint | Aktywność zapisu danych. |
| `sys.dm_io_virtual_file_stats` | Statystyki I/O dla pliku logu | Analiza dyskowa i opóźnienia. |

---

## 🧠 Dydaktyczny kontekst

> Log Shipping to klasyczna implementacja zasady **D – Durability** w architekturze SQL Server.  
> Tam, gdzie kończy się hardware, trwałość przejmuje **geografia**.  
> Każdy `COMMIT` to obietnica, że dane nie tylko przetrwają awarię serwera,  
> ale i będą gotowe do odtworzenia w innym ośrodku.

---

## 🧾 Baseline – dokumentacja wdrożenia

```markdown
# Log Shipping Baseline – SQL Server 2022

**Primary:** SQLPROD01\INST1  
**Secondary:** SQLDR01\INST1  
**Schedule:** Backup/Copy/Restore = */5 min  
**Share:** \\sqlbackup\logs  

## Jobs
- LSBackup_<db> – OK  
- LSCopy_<db> – OK  
- LSRestore_<db> – OK  

## Thresholds
- restore_threshold = 60 min  
- backup_retention = 72 h  

## Last status (timestamps UTC)
- last_backup:    <timestamp>  
- last_copied:    <timestamp>  
- last_restored:  <timestamp>  
```

---

## 🧩 PowerShell – szybka dokumentacja konfiguracji

Zapisz jako `scripts/Get-LogShippingBaseline.ps1`:

```powershell
param(
  [string]$Primary = "SQLPROD01\INST1",
  [string]$Secondary = "SQLDR01\INST1",
  [string]$Db = "YourDB"
)

$tsqlPrimary = @"
SELECT 'primary' AS side, primary_database AS db, last_backup_date, last_backup_file
FROM msdb.dbo.log_shipping_monitor_primary WHERE primary_database = '$Db';
"@

$tsqlSecondary = @"
SELECT 'secondary' AS side, secondary_database AS db, last_copied_date, last_restored_date,
       last_copied_file, last_restored_file
FROM msdb.dbo.log_shipping_monitor_secondary WHERE secondary_database = '$Db';
"@

Invoke-Sqlcmd -S $Primary -Q $tsqlPrimary
Invoke-Sqlcmd -S $Secondary -Q $tsqlSecondary
```

---

## 🚨 Runbook: test failover DR

1. Zatrzymaj zmiany na Primary.  
2. Wykonaj **tail-log backup**:
   ```sql
   BACKUP LOG [YourDB] TO DISK='\\sqlbackup\logs\YourDB_tail.trn' WITH NO_TRUNCATE;
   ```
3. Poczekaj na replikację lub odtwórz ręcznie na DR.  
4. Przywróć bazę na Secondary:
   ```sql
   RESTORE DATABASE [YourDB] WITH RECOVERY;
   ```
5. Przełącz ruch aplikacji (DNS, connection string, AG listener).  
6. Po powrocie do normalnej pracy – re-seed LS w stronę z powrotem.

