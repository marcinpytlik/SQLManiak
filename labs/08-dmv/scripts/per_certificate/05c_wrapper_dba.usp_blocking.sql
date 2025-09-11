USE AdventureWorks2022;
GO
/* === PROC: aktywne blokowania z tekstem SQL blokowanego i blokera === */
CREATE OR ALTER PROC dba.usp_blocking
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.session_id,
        r.blocking_session_id,
        r.status,
        r.command,
        r.wait_type,
        r.wait_time              AS wait_time_ms,
        r.cpu_time               AS cpu_time_ms,
        r.reads,
        r.writes,
        DB_NAME(r.database_id)   AS dbname,

        -- dane sesji BLOKOWANEJ
        s.login_name,
        s.host_name,
        s.program_name,
        txt.text                 AS sql_text,

        -- dane sesji BLOKUJĄCEJ (opcjonalnie przydatne)
        sb.login_name            AS blocking_login_name,
        sb.host_name             AS blocking_host_name,
        sb.program_name          AS blocking_program_name,

        -- tekst SQL blokera: najpierw "aktualny", a jeśli brak – "ostatni"
        COALESCE(txtb_cur.text, txtb_last.text) AS blocking_sql_text

    FROM sys.dm_exec_requests AS r
    JOIN sys.dm_exec_sessions AS s
      ON s.session_id = r.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS txt

    -- sesja blokująca (do metadanych)
    LEFT JOIN sys.dm_exec_sessions AS sb
      ON sb.session_id = r.blocking_session_id

    -- 1) jeśli bloker ma AKTUALNY request, bierzemy jego sql_handle
    OUTER APPLY (
        SELECT br.sql_handle
        FROM sys.dm_exec_requests AS br
        WHERE br.session_id = r.blocking_session_id
    ) AS breq
    OUTER APPLY sys.dm_exec_sql_text(breq.sql_handle) AS txtb_cur

    -- 2) fallback: ostatni batch z connection (most_recent_sql_handle)
    LEFT  JOIN sys.dm_exec_connections AS bc
      ON bc.session_id = r.blocking_session_id
    OUTER APPLY sys.dm_exec_sql_text(bc.most_recent_sql_handle) AS txtb_last

    WHERE r.blocking_session_id <> 0;
END;
GO
/* 2) Podpis procedury certyfikatem (po każdej zmianie — podpisać ponownie) */
IF EXISTS (
  SELECT 1
  FROM sys.crypt_properties
  WHERE class_desc = 'OBJECT_OR_COLUMN'
    AND major_id   = OBJECT_ID(N'dba.usp_blocking')
)
BEGIN
  DROP SIGNATURE FROM OBJECT::dba.usp_blocking BY CERTIFICATE dmv_cert;
END;
ADD  SIGNATURE TO   OBJECT::dba.usp_blocking BY CERTIFICATE dmv_cert;
GO

/* 3) Uprawnienie dla czytelników (rola „cert”) */
GRANT EXECUTE ON dba.usp_blocking TO [role_dmv_cert_readers];
GO
