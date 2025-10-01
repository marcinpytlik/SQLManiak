-- scripts/04_best_practices.sql
-- Rekomendacje rozmiaru VLF (przykładowe, dopasuj do środowiska):
-- - log do 8 GB: aim ~ 64–200 VLF
-- - log 8–64 GB: aim ~ 128–400 VLF
-- - log > 64 GB: aim ~ 200–800 VLF
-- Przyrosty ustaw w MB/GB (NIE procenty).
-- W SQL 2014+ algorytm tworzenia VLF jest ulepszony, ale złe growth wciąż potrafi zrobić „tysiące VLF”.

-- Szybki raport zdrowia logu:
SELECT
    DB_NAME(database_id) AS db,
    COUNT(*) AS vlf_count,
    SUM(CASE WHEN vlf_active = 1 THEN 1 ELSE 0 END) AS active_vlfs
FROM sys.dm_db_log_info(NULL)
GROUP BY database_id
ORDER BY vlf_count DESC;
