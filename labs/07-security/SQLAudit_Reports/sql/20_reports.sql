/* sql/20_reports.sql
   Gotowe zestawienia oparte o dbo.ufn_AuditEvents
*/

DECLARE @AuditName sysname    = N'DBAudit';           -- <--- PODAJ NAZWĘ SWOJEGO AUDYTU
DECLARE @FromDate  datetime2  = DATEADD(day,-14, SYSUTCDATETIME());
DECLARE @ToDate    datetime2  = NULL; -- do teraz

-- A) „Kombajn” – GROUPING SETS
;WITH E AS (
    SELECT 
        CAST(event_time_local AS date) AS d,
        principal,
        operation,
        obj3
    FROM dbo.ufn_AuditEvents(@AuditName, @FromDate, @ToDate)
)
SELECT
    d, principal, operation, obj3,
    COUNT(*) AS calls,
    GROUPING_ID(d, principal, operation, obj3) AS g_id
FROM E
GROUP BY GROUPING SETS (
    (d, principal, operation, obj3),
    (d, principal, operation),
    (d, principal),
    (d, operation),
    (principal, operation),
    (principal),
    (operation),
    (d),
    ()
)
ORDER BY d, principal, operation, obj3;

PRINT '---';

-- B) Top obiekty per operacja
SELECT TOP (30)
    operation, obj3, COUNT(*) AS calls
FROM dbo.ufn_AuditEvents(@AuditName, @FromDate, @ToDate)
GROUP BY operation, obj3
ORDER BY operation, calls DESC;

PRINT '---';

-- C) Aktywność per użytkownik (7 dni)
SELECT 
    principal, operation, COUNT(*) AS calls
FROM dbo.ufn_AuditEvents(@AuditName, DATEADD(day,-7, SYSUTCDATETIME()), NULL)
GROUP BY principal, operation
ORDER BY principal, calls DESC;

PRINT '---';

-- D) Heatmapa godzinowa (ostatnie 14 dni, czas lokalny serwera)
SELECT 
    DATENAME(weekday, event_time_local) AS weekday_name,
    DATEPART(weekday, event_time_local) AS weekday_no,
    DATEPART(hour,    event_time_local) AS hour24,
    COUNT(*) AS calls
FROM dbo.ufn_AuditEvents(@AuditName, @FromDate, @ToDate)
GROUP BY DATENAME(weekday, event_time_local),
         DATEPART(weekday, event_time_local),
         DATEPART(hour,    event_time_local)
ORDER BY weekday_no, hour24;
