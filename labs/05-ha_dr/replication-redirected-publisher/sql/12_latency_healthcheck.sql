/*
  Healthcheck replikacji: logowanie latency via tracer tokens.
  Tworzy tabelę logującą, procedurę wykonującą tracer token i zapisującą metryki.
  Uruchom na serwerze **dystrybutora**, gdzie działa `sp_posttracertoken` i `sp_helptracertokenhistory`
  (po przeniesieniu dystrybucji – będzie to Server C; wcześniej A).
*/

-- =============== PARAMETRY ===============
DECLARE @Publication sysname   = N'PubName';
DECLARE @Publisher sysname     = N'ServerC';    -- aktualny publisher
DECLARE @PublisherDb sysname   = N'TwojaBaza';
DECLARE @Subscriber sysname    = N'ServerB';
DECLARE @SubscriberDb sysname  = N'TwojaBazaB';
-- =========================================

IF DB_ID('msdb') IS NULL RAISERROR('Wymagana msdb',16,1);

USE msdb;
IF OBJECT_ID('dbo.ReplLatencyLog','U') IS NULL
BEGIN
  CREATE TABLE dbo.ReplLatencyLog
  (
    id               int IDENTITY(1,1) PRIMARY KEY,
    log_time         datetime2(0) NOT NULL CONSTRAINT DF_ReplLatencyLog_log_time DEFAULT (sysdatetime()),
    publication      sysname NOT NULL,
    publisher        sysname NOT NULL,
    publisher_db     sysname NOT NULL,
    subscriber       sysname NOT NULL,
    subscriber_db    sysname NOT NULL,
    token_id         int NOT NULL,
    overall_latency_ms int NULL,
    publisher_latency_ms int NULL,
    distributor_latency_ms int NULL,
    subscriber_latency_ms int NULL,
    status_desc      nvarchar(60) NULL
  );
END

GO
USE msdb;
IF OBJECT_ID('dbo.usp_ReplLatency_Probe','P') IS NOT NULL DROP PROCEDURE dbo.usp_ReplLatency_Probe;
GO
CREATE PROCEDURE dbo.usp_ReplLatency_Probe
    @Publication sysname,
    @Publisher sysname,
    @PublisherDb sysname,
    @Subscriber sysname,
    @SubscriberDb sysname
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @token_id int;

    -- Wstaw token
    EXEC sp_posttracertoken @publication = @Publication;
    -- Odczytaj ostatni token_id dla tej publikacji
    ;WITH t AS (
      SELECT TOP 1 tr.token_id
      FROM distribution.dbo.mspublications p
      JOIN distribution.dbo.mstracer_tokens tr ON tr.publication_id = p.publication_id
      WHERE p.publication = @Publication
      ORDER BY tr.tracer_id DESC
    )
    SELECT @token_id = token_id FROM t;

    -- Poczekaj krótko, aby dystrybutor odczytał status (opcjonalne)
    WAITFOR DELAY '00:00:02';

    -- Historia tokena
    DECLARE @lat TABLE (
      tracer_id int,
      publication_id int,
      publisher_commit datetime,
      distributor_commit datetime,
      subscriber_commit datetime,
      overall_latency int,
      publisher_latency int,
      distributor_latency int,
      subscriber_latency int
    );

    INSERT INTO @lat
    EXEC sp_helptracertokenhistory @publication = @Publication, @tracer_id = @token_id;

    DECLARE @overall int = NULL, @pub int=NULL, @dist int=NULL, @sub int=NULL, @status nvarchar(60) = N'Unknown';

    SELECT TOP 1
      @overall = overall_latency,
      @pub     = publisher_latency,
      @dist    = distributor_latency,
      @sub     = subscriber_latency
    FROM @lat
    WHERE subscriber_commit IS NOT NULL
    ORDER BY subscriber_commit DESC;

    IF @overall IS NULL SET @status = N'In-Transit'; ELSE SET @status = N'Arrived';

    INSERT INTO msdb.dbo.ReplLatencyLog
      (publication, publisher, publisher_db, subscriber, subscriber_db, token_id,
       overall_latency_ms, publisher_latency_ms, distributor_latency_ms, subscriber_latency_ms, status_desc)
    VALUES
      (@Publication, @Publisher, @PublisherDb, @Subscriber, @SubscriberDb, @token_id,
       @overall, @pub, @dist, @sub, @status);
END
GO

-- Przykład uruchomienia ręcznego:
-- EXEC msdb.dbo.usp_ReplLatency_Probe @Publication=@Publication, @Publisher=@Publisher, @PublisherDb=@PublisherDb, @Subscriber=@Subscriber, @SubscriberDb=@SubscriberDb;
