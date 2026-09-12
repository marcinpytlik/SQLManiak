/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 1 - Application-facing procedure
*/

USE [SSIS_Delegation_Lab];
GO

CREATE OR ALTER PROCEDURE dbo.usp_RequestExport
    @CustomerId int,
    @ReportDate date,
    @RequestId uniqueidentifier = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @CustomerId <= 0
        THROW 50001, 'CustomerId must be greater than zero.', 1;

    IF @ReportDate IS NULL
        THROW 50002, 'ReportDate is required.', 1;

    IF @RequestId IS NULL
        SET @RequestId = NEWID();

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
        @RequestId,
        @CustomerId,
        @ReportDate,
        ORIGINAL_LOGIN(),
        SYSDATETIME(),
        'NEW'
    );

    SELECT
        RequestId,
        CustomerId,
        ReportDate,
        RequestedBy,
        RequestedAt,
        Status
    FROM dbo.ExportRequest
    WHERE RequestId = @RequestId;
END;
GO
