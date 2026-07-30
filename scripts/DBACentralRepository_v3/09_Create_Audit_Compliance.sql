USE DBACentralRepository;
GO

CREATE TABLE audit.ComplianceRule
(
    ComplianceRuleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComplianceRule PRIMARY KEY,
    RuleCode varchar(100) NOT NULL CONSTRAINT UQ_ComplianceRule_RuleCode UNIQUE,
    ModuleName varchar(30) NOT NULL,
    RuleName nvarchar(256) NOT NULL,
    Description nvarchar(2000) NULL,
    Severity varchar(20) NOT NULL,
    Recommendation nvarchar(2000) NULL,
    IsEnabled bit NOT NULL CONSTRAINT DF_ComplianceRule_IsEnabled DEFAULT(1)
);
GO

CREATE TABLE audit.ComplianceException
(
    ComplianceExceptionId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComplianceException PRIMARY KEY,
    RuleCode varchar(100) NOT NULL,
    InstanceId bigint NOT NULL,
    ObjectType varchar(30) NOT NULL,
    ObjectName nvarchar(512) NOT NULL,
    Reason nvarchar(max) NOT NULL,
    ApprovedBy nvarchar(256) NULL,
    TicketNumber nvarchar(128) NULL,
    ValidFrom datetime2(0) NOT NULL,
    ValidTo datetime2(0) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_ComplianceException_IsActive DEFAULT(1),
    CONSTRAINT FK_ComplianceException_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

CREATE TABLE audit.JobDocumentation
(
    JobDocumentationId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobDocumentation PRIMARY KEY,
    InstanceId bigint NOT NULL,
    JobId uniqueidentifier NOT NULL,
    JobName sysname NOT NULL,
    ConfluencePageId nvarchar(100) NULL,
    ConfluencePageUrl nvarchar(2000) NULL,
    TechnicalOwner nvarchar(256) NULL,
    BusinessOwner nvarchar(256) NULL,
    Criticality varchar(20) NULL,
    IsDocumented bit NOT NULL CONSTRAINT DF_JobDocumentation_IsDocumented DEFAULT(0),
    DocumentationStatus varchar(30) NOT NULL CONSTRAINT DF_JobDocumentation_Status DEFAULT('MISSING'),
    LastReviewedAt datetime2(0) NULL,
    ReviewedBy nvarchar(256) NULL,
    Notes nvarchar(max) NULL,
    CONSTRAINT FK_JobDocumentation_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId),
    CONSTRAINT UQ_JobDocumentation UNIQUE(InstanceId,JobId)
);
GO

CREATE TABLE audit.ComplianceRun
(
    ComplianceRunId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComplianceRun PRIMARY KEY,
    ScanRunId bigint NULL,
    StartedAt datetime2(0) NOT NULL CONSTRAINT DF_ComplianceRun_StartedAt DEFAULT(SYSDATETIME()),
    FinishedAt datetime2(0) NULL,
    Status varchar(30) NOT NULL CONSTRAINT DF_ComplianceRun_Status DEFAULT('RUNNING'),
    FindingCount int NOT NULL CONSTRAINT DF_ComplianceRun_FindingCount DEFAULT(0),
    ErrorMessage nvarchar(max) NULL,
    CONSTRAINT FK_ComplianceRun_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId)
);
GO

CREATE TABLE audit.ComplianceFinding
(
    ComplianceFindingId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ComplianceFinding PRIMARY KEY,
    ComplianceRunId bigint NOT NULL,
    ScanRunId bigint NULL,
    RuleCode varchar(100) NOT NULL,
    InstanceId bigint NOT NULL,
    ObjectType varchar(30) NOT NULL,
    ObjectKey nvarchar(512) NULL,
    ObjectName nvarchar(512) NOT NULL,
    Severity varchar(20) NOT NULL,
    CurrentValue nvarchar(max) NULL,
    ExpectedValue nvarchar(max) NULL,
    Recommendation nvarchar(max) NULL,
    FindingStatus varchar(30) NOT NULL,
    IsExcepted bit NOT NULL CONSTRAINT DF_ComplianceFinding_IsExcepted DEFAULT(0),
    ComplianceExceptionId bigint NULL,
    FirstDetectedAt datetime2(0) NOT NULL,
    LastDetectedAt datetime2(0) NOT NULL,
    ResolvedAt datetime2(0) NULL,
    Details nvarchar(max) NULL,
    CONSTRAINT FK_ComplianceFinding_Run FOREIGN KEY(ComplianceRunId) REFERENCES audit.ComplianceRun(ComplianceRunId),
    CONSTRAINT FK_ComplianceFinding_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId),
    CONSTRAINT FK_ComplianceFinding_Exception FOREIGN KEY(ComplianceExceptionId) REFERENCES audit.ComplianceException(ComplianceExceptionId)
);
GO

CREATE TABLE audit.JobChange
(
    JobChangeId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JobChange PRIMARY KEY,
    ScanRunId bigint NOT NULL,
    InstanceId bigint NOT NULL,
    DetectedAt datetime2(0) NOT NULL CONSTRAINT DF_JobChange_DetectedAt DEFAULT(SYSDATETIME()),
    JobId uniqueidentifier NULL,
    JobName sysname NOT NULL,
    ChangeType varchar(30) NOT NULL,
    ObjectType varchar(30) NOT NULL,
    ObjectName nvarchar(512) NULL,
    PropertyName nvarchar(256) NULL,
    OldValue nvarchar(max) NULL,
    NewValue nvarchar(max) NULL,
    IsAuthorized bit NULL,
    TicketNumber nvarchar(128) NULL,
    CONSTRAINT FK_JobChange_ScanRun FOREIGN KEY(ScanRunId) REFERENCES dbo.ScanRun(ScanRunId),
    CONSTRAINT FK_JobChange_Instance FOREIGN KEY(InstanceId) REFERENCES dbo.Instance(InstanceId)
);
GO

MERGE audit.ComplianceRule AS T
USING
(
    VALUES
    ('JOB_OWNER_MISSING','JOB',N'Nieistniejący właściciel joba','CRITICAL',N'Ustaw zatwierdzone konto techniczne.'),
    ('JOB_OWNER_DISABLED','JOB',N'Wyłączony właściciel joba','HIGH',N'Zmień właściciela joba.'),
    ('JOB_OWNER_NOT_STANDARD','JOB',N'Właściciel niezgodny ze standardem','MEDIUM',N'Użyj sa, DBAJobOwner lub wyjątku.'),
    ('JOB_PROXY_MISSING','JOB',N'Brak wymaganego proxy','HIGH',N'Przypisz zatwierdzone proxy.'),
    ('JOB_PROXY_DISABLED','JOB',N'Wyłączone proxy','HIGH',N'Włącz proxy lub zmień przypisanie.'),
    ('JOB_NO_SCHEDULE','JOB',N'Aktywny job bez harmonogramu','MEDIUM',N'Dodaj harmonogram lub udokumentuj ON_DEMAND.'),
    ('JOB_SCHEDULE_DISABLED','JOB',N'Wyłączony harmonogram','HIGH',N'Włącz harmonogram lub dodaj wyjątek.'),
    ('JOB_SCHEDULE_EXPIRED','JOB',N'Wygasły harmonogram','HIGH',N'Zaktualizuj okres aktywności.'),
    ('JOB_NO_NOTIFICATION','JOB',N'Brak powiadomienia po błędzie','MEDIUM',N'Przypisz operatora i powiadomienie po błędzie.'),
    ('JOB_OPERATOR_INVALID','JOB',N'Niepoprawny operator','HIGH',N'Napraw operatora i adres e-mail.'),
    ('JOB_DISABLED_WITHOUT_EXCEPTION','JOB',N'Wyłączony job bez wyjątku','MEDIUM',N'Dodaj wyjątek lub uruchom/usuń job.'),
    ('JOB_NOT_DOCUMENTED','JOB',N'Job bez dokumentacji','MEDIUM',N'Utwórz stronę Confluence i wpis dokumentacyjny.'),
    ('JOB_DOCUMENTATION_OUTDATED','JOB',N'Nieaktualna dokumentacja','LOW',N'Przejrzyj dokumentację.')
) S(RuleCode,ModuleName,RuleName,Severity,Recommendation)
ON T.RuleCode=S.RuleCode
WHEN MATCHED THEN UPDATE SET
    ModuleName=S.ModuleName,RuleName=S.RuleName,Severity=S.Severity,Recommendation=S.Recommendation
WHEN NOT MATCHED THEN
    INSERT(RuleCode,ModuleName,RuleName,Severity,Recommendation)
    VALUES(S.RuleCode,S.ModuleName,S.RuleName,S.Severity,S.Recommendation);
GO

CREATE OR ALTER VIEW audit.vCurrentJobSteps
AS
WITH X AS
(
    SELECT S.*,
           ROW_NUMBER() OVER(PARTITION BY InstanceId,JobId,StepId ORDER BY CapturedAt DESC,JobStepSnapshotId DESC) rn
    FROM job.JobStepSnapshot S
)
SELECT * FROM X WHERE rn=1;
GO

CREATE OR ALTER VIEW audit.vCurrentJobSchedules
AS
WITH X AS
(
    SELECT S.*,
           ROW_NUMBER() OVER(PARTITION BY InstanceId,JobId,ScheduleId ORDER BY CapturedAt DESC,JobScheduleSnapshotId DESC) rn
    FROM job.JobScheduleSnapshot S
)
SELECT * FROM X WHERE rn=1;
GO

CREATE OR ALTER VIEW audit.vCurrentOperators
AS
WITH X AS
(
    SELECT O.*,
           ROW_NUMBER() OVER(PARTITION BY InstanceId,OperatorId ORDER BY CapturedAt DESC,OperatorSnapshotId DESC) rn
    FROM job.OperatorSnapshot O
)
SELECT * FROM X WHERE rn=1;
GO

CREATE OR ALTER VIEW audit.vCurrentProxies
AS
WITH X AS
(
    SELECT P.*,
           ROW_NUMBER() OVER(PARTITION BY InstanceId,ProxyId ORDER BY CapturedAt DESC,ProxySnapshotId DESC) rn
    FROM security.ProxySnapshot P
)
SELECT * FROM X WHERE rn=1;
GO

CREATE OR ALTER VIEW audit.vCurrentRoleMembership
AS
WITH X AS
(
    SELECT R.*,
           ROW_NUMBER() OVER(PARTITION BY InstanceId,RoleName,MemberName ORDER BY CapturedAt DESC,ServerRoleMembershipSnapshotId DESC) rn
    FROM security.ServerRoleMembershipSnapshot R
)
SELECT * FROM X WHERE rn=1;
GO

CREATE OR ALTER PROCEDURE audit.usp_AddFinding
    @ComplianceRunId bigint,
    @ScanRunId bigint,
    @RuleCode varchar(100),
    @InstanceId bigint,
    @ObjectType varchar(30),
    @ObjectKey nvarchar(512),
    @ObjectName nvarchar(512),
    @CurrentValue nvarchar(max)=NULL,
    @ExpectedValue nvarchar(max)=NULL
AS
BEGIN
    DECLARE @Severity varchar(20),@Recommendation nvarchar(max),@ExceptionId bigint,@Status varchar(30)='OPEN';

    SELECT @Severity=Severity,@Recommendation=Recommendation
    FROM audit.ComplianceRule
    WHERE RuleCode=@RuleCode AND IsEnabled=1;

    IF @Severity IS NULL RETURN;

    SELECT TOP(1) @ExceptionId=ComplianceExceptionId
    FROM audit.ComplianceException
    WHERE RuleCode=@RuleCode
      AND InstanceId=@InstanceId
      AND ObjectType=@ObjectType
      AND ObjectName=@ObjectName
      AND IsActive=1
      AND ValidFrom<=SYSDATETIME()
      AND (ValidTo IS NULL OR ValidTo>=SYSDATETIME())
    ORDER BY ValidTo DESC;

    IF @ExceptionId IS NOT NULL SET @Status='EXCEPTION';

    INSERT audit.ComplianceFinding
    (
        ComplianceRunId,ScanRunId,RuleCode,InstanceId,ObjectType,ObjectKey,ObjectName,
        Severity,CurrentValue,ExpectedValue,Recommendation,FindingStatus,IsExcepted,
        ComplianceExceptionId,FirstDetectedAt,LastDetectedAt
    )
    VALUES
    (
        @ComplianceRunId,@ScanRunId,@RuleCode,@InstanceId,@ObjectType,@ObjectKey,@ObjectName,
        @Severity,@CurrentValue,@ExpectedValue,@Recommendation,@Status,
        CASE WHEN @ExceptionId IS NULL THEN 0 ELSE 1 END,
        @ExceptionId,SYSDATETIME(),SYSDATETIME()
    );
END;
GO

CREATE OR ALTER PROCEDURE audit.usp_RunJobComplianceAudit
    @ScanRunId bigint=NULL,
    @ComplianceRunId bigint=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @ScanRunId IS NULL
        SELECT TOP(1) @ScanRunId=ScanRunId
        FROM dbo.ScanRun
        WHERE Status IN('SUCCESS','COMPLETED_WITH_ERRORS')
        ORDER BY ScanRunId DESC;

    INSERT audit.ComplianceRun(ScanRunId) VALUES(@ScanRunId);
    SET @ComplianceRunId=SCOPE_IDENTITY();

    BEGIN TRY
        DECLARE @InstanceId bigint,@JobId uniqueidentifier,@JobName sysname,@OwnerName sysname,
                @IsEnabled bit,@Notify int,@Operator sysname;

        DECLARE C CURSOR LOCAL FAST_FORWARD FOR
        SELECT InstanceId,JobId,JobName,OwnerName,IsEnabled,NotifyLevelEmail,OperatorName
        FROM report.vCurrentJobs;

        OPEN C;
        FETCH NEXT FROM C INTO @InstanceId,@JobId,@JobName,@OwnerName,@IsEnabled,@Notify,@Operator;

        WHILE @@FETCH_STATUS=0
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM report.vCurrentServerPrincipals
                WHERE InstanceId=@InstanceId AND PrincipalName=@OwnerName
            )
                EXEC audit.usp_AddFinding @ComplianceRunId,@ScanRunId,'JOB_OWNER_MISSING',
                    @InstanceId,'JOB',CONVERT(nvarchar(36),@JobId),@JobName,@OwnerName,N'Istniejący login techniczny';

            IF @OwnerName NOT IN(N'sa',N'DBAJobOwner')
               AND NOT EXISTS
               (
                   SELECT 1 FROM audit.vCurrentRoleMembership
                   WHERE InstanceId=@InstanceId AND RoleName=N'sysadmin' AND MemberName=@OwnerName
               )
                EXEC audit.usp_AddFinding @ComplianceRunId,@ScanRunId,'JOB_OWNER_NOT_STANDARD',
                    @InstanceId,'JOB',CONVERT(nvarchar(36),@JobId),@JobName,@OwnerName,N'sa, DBAJobOwner lub wyjątek';

            IF @IsEnabled=0
                EXEC audit.usp_AddFinding @ComplianceRunId,@ScanRunId,'JOB_DISABLED_WITHOUT_EXCEPTION',
                    @InstanceId,'JOB',CONVERT(nvarchar(36),@JobId),@JobName,N'Wyłączony',N'Aktywny lub zatwierdzony wyjątek';

            IF @IsEnabled=1 AND ISNULL(@Notify,0) NOT IN(2,3)
                EXEC audit.usp_AddFinding @ComplianceRunId,@ScanRunId,'JOB_NO_NOTIFICATION',
                    @InstanceId,'JOB',CONVERT(nvarchar(36),@JobId),@JobName,
                    CONVERT(nvarchar(20),@Notify),N'Powiadomienie po błędzie';

            IF @IsEnabled=1 AND NOT EXISTS
            (
                SELECT 1 FROM audit.vCurrentJobSchedules
                WHERE InstanceId=@InstanceId AND JobId=@JobId
            )
                EXEC audit.usp_AddFinding @ComplianceRunId,@ScanRunId,'JOB_NO_SCHEDULE',
                    @InstanceId,'JOB',CONVERT(nvarchar(36),@JobId),@JobName,N'Brak',N'Harmonogram lub ON_DEMAND';

            IF NOT EXISTS
            (
                SELECT 1 FROM audit.JobDocumentation
                WHERE InstanceId=@InstanceId AND JobId=@JobId
                  AND IsDocumented=1
                  AND NULLIF(ConfluencePageUrl,N'') IS NOT NULL
            )
                EXEC audit.usp_AddFinding @ComplianceRunId,@ScanRunId,'JOB_NOT_DOCUMENTED',
                    @InstanceId,'JOB',CONVERT(nvarchar(36),@JobId),@JobName,N'Brak',N'Kompletna dokumentacja';

            FETCH NEXT FROM C INTO @InstanceId,@JobId,@JobName,@OwnerName,@IsEnabled,@Notify,@Operator;
        END;

        CLOSE C;
        DEALLOCATE C;

        UPDATE audit.ComplianceRun
        SET FinishedAt=SYSDATETIME(),
            Status='SUCCESS',
            FindingCount=(SELECT COUNT(*) FROM audit.ComplianceFinding WHERE ComplianceRunId=@ComplianceRunId)
        WHERE ComplianceRunId=@ComplianceRunId;
    END TRY
    BEGIN CATCH
        UPDATE audit.ComplianceRun
        SET FinishedAt=SYSDATETIME(),Status='FAILED',ErrorMessage=ERROR_MESSAGE()
        WHERE ComplianceRunId=@ComplianceRunId;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER VIEW report.vLatestJobComplianceFindings
AS
WITH X AS
(
    SELECT F.*,
           ROW_NUMBER() OVER
           (
               PARTITION BY InstanceId,RuleCode,ObjectType,ObjectName
               ORDER BY LastDetectedAt DESC,ComplianceFindingId DESC
           ) rn
    FROM audit.ComplianceFinding F
)
SELECT
    I.ServerInstance,E.EnvironmentCode,X.RuleCode,R.RuleName,X.ObjectType,X.ObjectName,
    X.Severity,X.CurrentValue,X.ExpectedValue,X.Recommendation,X.FindingStatus,
    X.IsExcepted,X.FirstDetectedAt,X.LastDetectedAt
FROM X
JOIN dbo.Instance I ON I.InstanceId=X.InstanceId
LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
JOIN audit.ComplianceRule R ON R.RuleCode=X.RuleCode
WHERE X.rn=1;
GO

CREATE OR ALTER VIEW report.vUndocumentedJobs
AS
SELECT
    J.ServerInstance,J.EnvironmentCode,J.JobId,J.JobName,J.OwnerName,
    D.ConfluencePageUrl,D.TechnicalOwner,D.BusinessOwner,D.Criticality,
    D.DocumentationStatus,D.LastReviewedAt,
    CASE
      WHEN D.JobDocumentationId IS NULL THEN 'MISSING'
      WHEN D.IsDocumented=0 OR NULLIF(D.ConfluencePageUrl,N'') IS NULL THEN 'INCOMPLETE'
      WHEN D.LastReviewedAt IS NULL THEN 'NOT_REVIEWED'
      WHEN D.LastReviewedAt<DATEADD(month,-12,SYSDATETIME()) THEN 'OUTDATED'
      ELSE 'OK'
    END AuditStatus
FROM report.vCurrentJobs J
LEFT JOIN audit.JobDocumentation D
  ON D.InstanceId=J.InstanceId
 AND D.JobId=J.JobId;
GO

CREATE OR ALTER PROCEDURE report.usp_JobComplianceSummary
AS
BEGIN
    SELECT Severity,FindingStatus,COUNT(*) FindingCount
    FROM report.vLatestJobComplianceFindings
    GROUP BY Severity,FindingStatus;

    SELECT *
    FROM report.vLatestJobComplianceFindings
    ORDER BY
        CASE Severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,
        ServerInstance,ObjectName;
END;
GO

CREATE OR ALTER PROCEDURE report.usp_JobChanges
    @Days int=30
AS
BEGIN
    SELECT
        I.ServerInstance,E.EnvironmentCode,C.DetectedAt,C.JobName,C.ChangeType,
        C.ObjectType,C.ObjectName,C.PropertyName,C.OldValue,C.NewValue,
        C.IsAuthorized,C.TicketNumber
    FROM audit.JobChange C
    JOIN dbo.Instance I ON I.InstanceId=C.InstanceId
    LEFT JOIN dbo.Environment E ON E.EnvironmentId=I.EnvironmentId
    WHERE C.DetectedAt>=DATEADD(day,-@Days,SYSDATETIME())
    ORDER BY C.DetectedAt DESC;
END;
GO

EXEC dbo.usp_SetDescription N'audit',N'ComplianceRule','TABLE',
    N'Słownik reguł audytu zgodności jobów.';
EXEC dbo.usp_SetDescription N'audit',N'ComplianceException','TABLE',
    N'Zatwierdzone wyjątki od reguł zgodności.';
EXEC dbo.usp_SetDescription N'audit',N'JobDocumentation','TABLE',
    N'Rejestr dokumentacji jobów i stron Confluence.';
EXEC dbo.usp_SetDescription N'audit',N'ComplianceRun','TABLE',
    N'Historia uruchomień audytu zgodności.';
EXEC dbo.usp_SetDescription N'audit',N'ComplianceFinding','TABLE',
    N'Wyniki audytu zgodności jobów.';
EXEC dbo.usp_SetDescription N'audit',N'JobChange','TABLE',
    N'Historia wykrytych zmian jobów, kroków i harmonogramów.';
EXEC dbo.usp_SetDescription N'report',N'vLatestJobComplianceFindings','VIEW',
    N'Najnowsze findingi zgodności jobów.';
EXEC dbo.usp_SetDescription N'report',N'vUndocumentedJobs','VIEW',
    N'Joby bez dokumentacji lub z nieaktualną dokumentacją.';
GO
