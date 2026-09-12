/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 1 - Functional tests
*/

USE [SSIS_Delegation_Lab];
GO

DECLARE @RequestId uniqueidentifier;

EXEC dbo.usp_RequestExport
    @CustomerId = 1001,
    @ReportDate = '2026-09-12',
    @RequestId = @RequestId OUTPUT;

SELECT @RequestId AS CreatedRequestId;
GO

SELECT
    RequestId,
    CustomerId,
    ReportDate,
    RequestedBy,
    RequestedAt,
    Status,
    StartedAt,
    FinishedAt,
    OutputFile,
    ErrorMessage
FROM dbo.ExportRequest
ORDER BY RequestedAt DESC;
GO

-- Negative test: should fail with error 50001.
BEGIN TRY
    DECLARE @InvalidRequestId uniqueidentifier;

    EXEC dbo.usp_RequestExport
        @CustomerId = 0,
        @ReportDate = '2026-09-12',
        @RequestId = @InvalidRequestId OUTPUT;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO
