# Lista kontrolna: Strategia odtwarzania (SQL Server)

## Kontekst  
Praktyczny przewodnik po odtwarzaniu baz danych w typowych scenariuszach:  
- tylko pełna kopia  
- pełna + różnicowa  
- pełna + różnicowa + łańcuch logów  
- odtwarzanie do punktu w czasie (STOPAT/STOPATMARK)  
- tail-log i przerwane łańcuchy  
- przypadki specjalne (MOVE, REPLACE, STANDBY, odtwarzanie plików/filegroup/page)  

---

## Wstępne sprawdzenia (przed każdym RESTORE)
- [ ] Potwierdź docelowe RPO/RTO dla incydentu  
- [ ] Zidentyfikuj najnowsze poprawne kopie zapasowe (msdb + system plików)  
- [ ] Zweryfikuj ciągłość łańcucha kopii (pełna → różnicowa → logi, wg LSN)  
- [ ] Sprawdź wolne miejsce na instancji docelowej (dane + logi) i poprawność ścieżek  
- [ ] Upewnij się, że w bazie docelowej nie ma aktywnych sesji (zabij połączenia lub użyj `WITH REPLACE` na offline DB)  
- [ ] Zdecyduj o stanie końcowym: `WITH RECOVERY` / `NORECOVERY` / `STANDBY`  

---

## Szybki przegląd łańcucha kopii  

```sql
-- Podgląd kopii zapasowych w msdb
SELECT TOP (200)
   bs.database_name, 
   bs.backup_start_date, 
   bs.backup_finish_date,
   bs.type, -- D=Pełna, I=Różnicowa, L=Log
   bmf.physical_device_name, 
   bs.first_lsn, 
   bs.last_lsn, 
   bs.checkpoint_lsn, 
   bs.database_backup_lsn
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf 
   ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'TwojaBaza'
ORDER BY backup_start_date DESC;
