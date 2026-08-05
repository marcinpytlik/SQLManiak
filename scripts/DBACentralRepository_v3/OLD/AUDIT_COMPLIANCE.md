# Audyt i zgodność jobów

Moduł obejmuje:

- właścicieli jobów,
- proxy i credentials,
- harmonogramy,
- operatorów i powiadomienia,
- joby wyłączone,
- joby bez dokumentacji,
- wyjątki od standardu,
- findingi zgodności,
- historię zmian.

Główna procedura:

```sql
DECLARE @ComplianceRunId bigint;

EXEC audit.usp_RunJobComplianceAudit
    @ComplianceRunId=@ComplianceRunId OUTPUT;
```

Raporty:

```sql
EXEC report.usp_JobComplianceSummary;
EXEC report.usp_JobChanges @Days=30;
```
