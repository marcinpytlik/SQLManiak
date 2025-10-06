/* Lab 05 — VLFs i autogrowth */
USE LogLab;

/* Policz VLF: */
SELECT COUNT(*) AS VLFs FROM sys.dm_db_log_info(DB_ID());

/* Rekomendacje:
   - Pre-size LOG do sensownej wartości (np. 8–16 GB w labie)
   - Autogrowth w MB (np. 512 MB – 1024 MB), nie w procentach
*/
ALTER DATABASE LogLab MODIFY FILE (NAME = LogLab_log, SIZE = 8192MB, FILEGROWTH = 512MB);

/* Weryfikacja: */
SELECT name, size*8/1024 AS size_MB, growth AS growth_units, is_percent_growth
FROM sys.database_files
WHERE type_desc = 'LOG';
