# Lab 07 — Backup/Restore Performance (DCM/BCM, striped, tuning)

Cel:
- Zmierzyć wpływ **striped backups**, **kompresji**, **MAXTRANSFERSIZE/BUFFERCOUNT/BLOCKSIZE** na czas i throughput.
- Zobaczyć jak **DCM/BCM** wpływa na **differential** i **log**.
- Zebrać metryki z `msdb` i DMV oraz porównać wyniki.

> Uwaga: EDYTUJ ŚCIEŻKI DO PLIKÓW BACKUP w skryptach! Test na środowisku labowym.

## Plan
1. **Setup**: baza `BkpLab` (duża tabela ~GB), konfiguracja FULL recovery.
2. **Full backup**: single vs striped (np. 4 pliki) + kompresja ON/OFF.
3. **Differential backup**: zmień ~10–20% danych, zobacz wpływ DCM.
4. **Log backup**: wygeneruj log, zmierz czasy i MB/s.
5. **Restore test**: odtwórz do nowej bazy, zmierz times (opcjonalnie VERIFYONLY + CHECKSUM).

## Metryki
- `msdb.dbo.backupset` / `backupmediafamily` — czasy, rozmiary, kompresja.
- `sys.dm_io_virtual_file_stats` — IO bazy podczas backupu.
- `sys.dm_db_file_space_usage` (dla logu).

