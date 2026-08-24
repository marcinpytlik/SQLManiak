USE DBACentralRepository;
GO

IF EXISTS
(
    SELECT 1
    FROM config.CollectorPolicy
    WHERE CollectorCode = 'BACKUP'
)
BEGIN
    UPDATE config.CollectorPolicy
    SET
        CollectorName = N'Backup History',
        ExpectedIntervalMinutes = 15,
        WarningAfterMinutes = 30,
        CriticalAfterMinutes = 60,
        IsEnabled = 1,
        Description = N'Collects backup history from msdb and feeds backup reporting and Grafana.'
    WHERE CollectorCode = 'BACKUP';
END
ELSE
BEGIN
    INSERT config.CollectorPolicy
    (
        CollectorCode,
        CollectorName,
        ExpectedIntervalMinutes,
        WarningAfterMinutes,
        CriticalAfterMinutes,
        IsEnabled,
        Description
    )
    VALUES
    (
        'BACKUP',
        N'Backup History',
        15,
        30,
        60,
        1,
        N'Collects backup history from msdb and feeds backup reporting and Grafana.'
    );
END;
GO

SELECT *
FROM config.CollectorPolicy
WHERE CollectorCode = 'BACKUP';