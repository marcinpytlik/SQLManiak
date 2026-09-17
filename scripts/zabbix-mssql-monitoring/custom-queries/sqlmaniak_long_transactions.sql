SET NOCOUNT ON;

SELECT
    COUNT(DISTINCT st.session_id) AS active_user_transactions_count,
    COALESCE(MAX(DATEDIFF(SECOND, at.transaction_begin_time, SYSDATETIME())), 0) AS max_duration_sec
FROM sys.dm_tran_active_transactions AS at
JOIN sys.dm_tran_session_transactions AS st
  ON st.transaction_id = at.transaction_id
JOIN sys.dm_exec_sessions AS s
  ON s.session_id = st.session_id
WHERE s.is_user_process = 1
  AND at.transaction_begin_time IS NOT NULL;
