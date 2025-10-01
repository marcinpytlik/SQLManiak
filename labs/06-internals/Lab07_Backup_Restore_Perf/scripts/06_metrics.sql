-- scripts/06_metrics.sql
-- Metryki z msdb + szacunek throughputu

SELECT TOP (50)
    database_name, type AS bkp_type, backup_start_date, backup_finish_date,
    DATEDIFF(SECOND, backup_start_date, backup_finish_date) AS duration_s,
    CAST(compressed_backup_size/1048576.0 AS DECIMAL(18,1)) AS size_MB
FROM msdb.dbo.backupset
WHERE database_name = 'BkpLab'
ORDER BY backup_start_date DESC;

-- Estymacja MB/s (uwaga: dla stripe'ów sumuj rozmiary po media_set_id)
SELECT b.media_set_id,
       SUM(b.compressed_backup_size)/1048576.0 AS total_size_MB,
       DATEDIFF(SECOND, MIN(b.backup_start_date), MAX(b.backup_finish_date)) AS total_time_s,
       (SUM(b.compressed_backup_size)/1048576.0) / NULLIF(DATEDIFF(SECOND, MIN(b.backup_start_date), MAX(b.backup_finish_date)),0) AS MB_per_s
FROM msdb.dbo.backupset b
WHERE b.database_name = 'BkpLab'
GROUP BY b.media_set_id
ORDER BY b.media_set_id DESC;
