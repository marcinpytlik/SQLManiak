/*
    POC: Secure SSIS Export without unconstrained delegation
    Stage 1 - Queue schema
*/

USE [SSIS_Delegation_Lab];
GO

IF OBJECT_ID(N'dbo.ExportRequest', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ExportRequest
    (
        RequestId       uniqueidentifier NOT NULL
            CONSTRAINT PK_ExportRequest PRIMARY KEY,
        CustomerId      int NOT NULL,
        ReportDate      date NOT NULL,
        RequestedBy     sysname NOT NULL,
        RequestedAt     datetime2(0) NOT NULL
            CONSTRAINT DF_ExportRequest_RequestedAt DEFAULT (SYSDATETIME()),
        Status          varchar(20) NOT NULL
            CONSTRAINT DF_ExportRequest_Status DEFAULT ('NEW'),
        StartedAt       datetime2(0) NULL,
        FinishedAt      datetime2(0) NULL,
        OutputFile      nvarchar(500) NULL,
        ErrorMessage    nvarchar(4000) NULL,
        CONSTRAINT CK_ExportRequest_Status
            CHECK (Status IN ('NEW','PROCESSING','DONE','FAILED'))
    );

    CREATE INDEX IX_ExportRequest_Status_RequestedAt
        ON dbo.ExportRequest(Status, RequestedAt)
        INCLUDE (RequestId, CustomerId, ReportDate, RequestedBy);
END;
GO

SELECT TOP (100)
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
