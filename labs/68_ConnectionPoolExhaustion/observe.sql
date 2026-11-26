SELECT SYSUTCDATETIME() AS observed_utc, s.session_id, s.status,
       s.open_transaction_count, r.status AS request_status,
       r.wait_type, r.blocking_session_id, c.connect_time,
       s.last_request_end_time, s.program_name
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
LEFT JOIN sys.dm_exec_connections AS c ON c.session_id = s.session_id
WHERE s.program_name IN (N'SQLManiak.Lab68', N'SQLManiak.Lab68.Observer');

SELECT st.session_id, at.transaction_id, at.transaction_begin_time,
       at.transaction_state
FROM sys.dm_tran_session_transactions AS st
JOIN sys.dm_tran_active_transactions AS at ON at.transaction_id = st.transaction_id
JOIN sys.dm_exec_sessions AS s ON s.session_id = st.session_id
WHERE s.program_name IN (N'SQLManiak.Lab68', N'SQLManiak.Lab68.Observer');
