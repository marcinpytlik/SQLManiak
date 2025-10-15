/* 02_PBM.sql
   PBM Condition + Policy + Job do cyklicznej oceny (co 5 minut)
*/

USE msdb;
GO

/* 1) CONDITION dla facetu Database */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_conditions WHERE name = N'DB_Options_Compliance')
BEGIN
    EXEC msdb.dbo.sp_syspolicy_create_condition
        @name = N'DB_Options_Compliance',
        @facet = N'Database',
        @expression = N'<Operator>
  <TypeClass>Bool</TypeClass>
  <OpType>AND</OpType>
  <Count>4</Count>
  <Operator>
    <TypeClass>Bool</TypeClass>
    <OpType>EQ</OpType>
    <Count>2</Count>
    <Attribute>
      <TypeClass>Numeric</TypeClass>
      <Name>PageVerify</Name>
    </Attribute>
    <Constant>
      <TypeClass>Numeric</TypeClass>
      <ObjType>System.Int32</ObjType>
      <Value>2</Value> <!-- CHECKSUM -->
    </Constant>
  </Operator>
  <Operator>
    <TypeClass>Bool</TypeClass>
    <OpType>EQ</OpType>
    <Count>2</Count>
    <Attribute>
      <TypeClass>Bool</TypeClass>
      <Name>AutoClose</Name>
    </Attribute>
    <Constant>
      <TypeClass>Bool</TypeClass>
      <Value>False</Value>
    </Constant>
  </Operator>
  <Operator>
    <TypeClass>Bool</TypeClass>
    <OpType>EQ</OpType>
    <Count>2</Count>
    <Attribute>
      <TypeClass>Bool</TypeClass>
      <Name>AutoShrink</Name>
    </Attribute>
    <Constant>
      <TypeClass>Bool</TypeClass>
      <Value>False</Value>
    </Constant>
  </Operator>
  <Operator>
    <TypeClass>Bool</TypeClass>
    <OpType>EQ</OpType>
    <Count>2</Count>
    <Attribute>
      <TypeClass>Numeric</TypeClass>
      <Name>RecoveryModel</Name>
    </Attribute>
    <Constant>
      <TypeClass>Numeric</TypeClass>
      <ObjType>System.Int32</ObjType>
      <Value>1</Value> <!-- FULL -->
    </Constant>
  </Operator>
</Operator>',
        @description = N'Pilnuje: CHECKSUM, AUTO_CLOSE OFF, AUTO_SHRINK OFF, RECOVERY FULL',
        @is_name_condition = 0;
END
GO

/* 2) POLITYKA: oceniaj wszystkie bazy, loguj naruszenia */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_policies WHERE name = N'Policy_DB_Options_Compliance')
BEGIN
    EXEC msdb.dbo.sp_syspolicy_create_policy
        @name = N'Policy_DB_Options_Compliance',
        @condition_name = N'DB_Options_Compliance',
        @policy_category = N'DriftControl',
        @root_condition_name = NULL,
        @target_set = N'<TargetSet>
  <TargetType>
    <TypeAlias>Database</TypeAlias>
    <Enabled>True</Enabled>
  </TargetType>
</TargetSet>',
        @description = N'Wykrywa dryf ustawień DB',
        @execution_mode = 2, -- On Schedule (Log Only)
        @is_enabled = 1;
END
GO

/* 3) JOB: ocena polityki co 5 min */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'PBM Evaluate: Policy_DB_Options_Compliance')
BEGIN
    EXEC dbo.sp_add_job
        @job_name = N'PBM Evaluate: Policy_DB_Options_Compliance',
        @enabled = 1;

    EXEC dbo.sp_add_jobstep
        @job_name = N'PBM Evaluate: Policy_DB_Options_Compliance',
        @step_name = N'Evaluate Policy',
        @subsystem = N'TSQL',
        @database_name = N'msdb',
        @command = N'EXEC msdb.dbo.sp_syspolicy_execute_policy @policy_name = N''Policy_DB_Options_Compliance'';';

    EXEC dbo.sp_add_schedule
        @schedule_name = N'Every_5_Min',
        @freq_type = 4,              -- daily
        @freq_interval = 1,
        @freq_subday_type = 4,       -- minutes
        @freq_subday_interval = 5,
        @active_start_time = 000000;

    EXEC dbo.sp_attach_schedule
        @job_name = N'PBM Evaluate: Policy_DB_Options_Compliance',
        @schedule_name = N'Every_5_Min';

    EXEC dbo.sp_add_jobserver @job_name = N'PBM Evaluate: Policy_DB_Options_Compliance';
END
GO

PRINT 'PBM gotowe. Polityka + Job aktywne.';
