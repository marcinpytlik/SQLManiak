/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 2 - Security tests for the application account

    Run this script in a session connected as the real application account,
    e.g. SQLLAB\konto after replacing the placeholder in script 05.
*/

USE [SSIS_Delegation_Lab];
GO

SELECT
    ORIGINAL_LOGIN() AS OriginalLogin,
    SUSER_SNAME()     AS CurrentLogin,
    USER_NAME()       AS DatabaseUser;
GO

/* TEST 1 - should succeed */
DECLARE @RequestId uniqueidentifier;

EXEC dbo.usp_RequestExport
     @CustomerId = 2001,
     @ReportDate = CONVERT(date, GETDATE()),
     @RequestId = @RequestId OUTPUT;

SELECT @RequestId AS CreatedRequestId;
GO

/* TEST 2 - should fail with permission denied */
BEGIN TRY
    SELECT TOP (1) *
    FROM dbo.ExportRequest;

    THROW 51001, 'SECURITY TEST FAILED: SELECT on dbo.ExportRequest unexpectedly succeeded.', 1;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER()  AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO

/* TEST 3 - should fail with permission denied */
BEGIN TRY
    INSERT dbo.ExportRequest
    (
        RequestId,
        CustomerId,
        ReportDate,
        RequestedBy,
        RequestedAt,
        Status
    )
    VALUES
    (
        NEWID(),
        9999,
        CONVERT(date, GETDATE()),
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        'NEW'
    );

    THROW 51002, 'SECURITY TEST FAILED: INSERT on dbo.ExportRequest unexpectedly succeeded.', 1;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER()  AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO

/* TEST 4 - show effective object permissions */
SELECT
    HAS_PERMS_BY_NAME(N'dbo.usp_RequestExport', N'OBJECT', N'EXECUTE') AS CanExecuteRequestProcedure,
    HAS_PERMS_BY_NAME(N'dbo.ExportRequest', N'OBJECT', N'SELECT')      AS CanSelectQueue,
    HAS_PERMS_BY_NAME(N'dbo.ExportRequest', N'OBJECT', N'INSERT')      AS CanInsertQueue,
    HAS_PERMS_BY_NAME(N'dbo.ExportRequest', N'OBJECT', N'UPDATE')      AS CanUpdateQueue,
    HAS_PERMS_BY_NAME(N'dbo.ExportRequest', N'OBJECT', N'DELETE')      AS CanDeleteQueue;
GO

/* Expected final result:

CanExecuteRequestProcedure = 1
CanSelectQueue             = 0
CanInsertQueue             = 0
CanUpdateQueue             = 0
CanDeleteQueue             = 0
*/
