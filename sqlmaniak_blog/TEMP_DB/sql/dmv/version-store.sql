
-- dmv/version-store.sql
SELECT TOP 20 transaction_sequence_num, create_time, database_id, rowset_id, status, min_length, max_length, record_length_first_part_in_bytes
FROM sys.dm_tran_version_store
ORDER BY create_time DESC;
