
# 08 – RCSI / Snapshot – wersjonowanie

**Idea:** Przy RCSI/SI wersje wierszy trafiają do tempdb. To zmienia blokady i wpływa na log/truncation.

## Setup
```sql
USE tempdb;
GO
ALTER DATABASE tempdb SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

IF OBJECT_ID('dbo.DemoRCSI') IS NOT NULL DROP TABLE dbo.DemoRCSI;
CREATE TABLE dbo.DemoRCSI (Id INT IDENTITY PRIMARY KEY, Val INT);
INSERT INTO dbo.DemoRCSI(Val) VALUES (1),(2),(3),(4),(5);
GO
```

## Test (2 sesje)
- **Sesja A**
```sql
BEGIN TRAN;
UPDATE dbo.DemoRCSI SET Val = Val + 1 WHERE Id <= 5;
-- Nie commituj od razu
```

- **Sesja B**
```sql
SELECT * FROM dbo.DemoRCSI; -- przy RCSI czyta wersje bez blokowania A
```

## Wnioski
- Mniej blokad czytających, ale dodatkowy koszt wersjonowania (tempdb, log).
- Długie snapshoty mogą trzymać stare wersje i blokować `log truncation`.
