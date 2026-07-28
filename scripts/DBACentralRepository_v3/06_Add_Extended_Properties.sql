USE DBACentralRepository;
GO

DECLARE @D TABLE
(
    SchemaName sysname,
    ObjectName sysname,
    ObjectType varchar(20),
    Description nvarchar(4000)
);

INSERT @D VALUES
(N'dbo',N'Environment','TABLE',N'Słownik środowisk używany przez wszystkie moduły.'),
(N'dbo',N'ScanRun','TABLE',N'Nagłówek każdego uruchomienia kolektora.'),
(N'dbo',N'Instance','TABLE',N'Centralny rejestr instancji SQL Server.'),
(N'dbo',N'ScanError','TABLE',N'Błędy powstałe podczas skanowania.'),
(N'job',N'JobSnapshot','TABLE',N'Historyczne migawki konfiguracji jobów SQL Server Agent.'),
(N'job',N'JobStepSnapshot','TABLE',N'Historyczne migawki kroków jobów.'),
(N'job',N'JobScheduleSnapshot','TABLE',N'Historyczne migawki harmonogramów jobów.'),
(N'job',N'JobExecution','TABLE',N'Historia wykonań jobów z msdb.'),
(N'job',N'OperatorSnapshot','TABLE',N'Historyczne migawki operatorów SQL Server Agent.'),
(N'db',N'DatabaseSnapshot','TABLE',N'Historyczne migawki konfiguracji i rozmiaru baz.'),
(N'db',N'DatabaseFileSnapshot','TABLE',N'Historyczne migawki plików baz.'),
(N'backup',N'BackupHistory','TABLE',N'Historia backupów FULL, DIFF i LOG wraz z LSN i checksum.'),
(N'backup',N'RestoreTest','TABLE',N'Rejestr rzeczywistych testów restore i CHECKDB.'),
(N'capacity',N'VolumeSnapshot','TABLE',N'Historia pojemności wolumenów SQL Server.'),
(N'ha',N'DatabaseReplicaSnapshot','TABLE',N'Historia stanu baz w Availability Groups.'),
(N'maintenance',N'CheckDbExecution','TABLE',N'Historia wykonań DBCC CHECKDB.'),
(N'patch',N'InstanceBuildHistory','TABLE',N'Historia buildów zainstalowanych na instancjach.'),
(N'config',N'ServerConfigurationSnapshot','TABLE',N'Historia ustawień sys.configurations.'),
(N'security',N'ServerPrincipalSnapshot','TABLE',N'Historia loginów i principals serwerowych.'),
(N'security',N'ProxySnapshot','TABLE',N'Historia proxy SQL Server Agent.'),
(N'security',N'CredentialSnapshot','TABLE',N'Historia credentials bez przechowywania haseł.'),
(N'report',N'vCurrentInstances','VIEW',N'Aktualny stan instancji.'),
(N'report',N'vCurrentJobs','VIEW',N'Aktualna konfiguracja jobów.'),
(N'report',N'vCurrentDatabases','VIEW',N'Aktualna konfiguracja baz.'),
(N'report',N'vCurrentVolumes','VIEW',N'Aktualny stan wolumenów.'),
(N'report',N'vCurrentAgDatabases','VIEW',N'Aktualny stan baz w AG.');

DECLARE @SchemaName sysname,@ObjectName sysname,@ObjectType varchar(20),@Description nvarchar(4000);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
SELECT SchemaName,ObjectName,ObjectType,Description FROM @D;

OPEN c;
FETCH NEXT FROM c INTO @SchemaName,@ObjectName,@ObjectType,@Description;

WHILE @@FETCH_STATUS=0
BEGIN
    EXEC dbo.usp_SetDescription
        @SchemaName=@SchemaName,
        @ObjectName=@ObjectName,
        @ObjectType=@ObjectType,
        @Description=@Description;

    FETCH NEXT FROM c INTO @SchemaName,@ObjectName,@ObjectType,@Description;
END;

CLOSE c;
DEALLOCATE c;
GO
