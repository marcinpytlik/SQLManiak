# Kolejność instalacji SQL

Uruchamiaj pliki rosnąco według numeru:

```text
00_Create_Database_And_Schemas.sql
01_Create_Core_Objects.sql
02_Create_Job_And_Database_Modules.sql
03_Create_Stage1_Modules.sql
04_Create_Stage2_Modules.sql
05_Create_Report_Objects.sql
06_Add_Extended_Properties.sql
07_Create_Audit_Compliance.sql
08_Create_Job_Category_Views.sql
09_Create_Job_Change_Views.sql
10_Create_Job_Audit_Compliance_Views.sql
11_Create_Job_Operational_Report_Procedures.sql
12_Create_Job_Documentation_Lifecycle.sql
13_Create_SSRS_Job_Mapping.sql
14_Create_Agent_Jobs.sql
99_Useful_Queries.sql
```

## Zasady

- Pliki `00–14` tworzą lub aktualizują obiekty.
- `99_Useful_Queries.sql` zawiera tylko zapytania kontrolne i raportowe.
- Wszystkie skrypty można uruchomić ponownie. Tabele i indeksy są chronione przez test istnienia, a procedury i widoki korzystają z `CREATE OR ALTER`.
- Nazwy obiektów są zapisywane w konwencji `[schemat].[Obiekt]`, np. `[backup].[BackupHistory]`.
- `14_Create_Agent_Jobs.sql` uruchom po skopiowaniu skryptów PowerShell na serwer i ustawieniu ścieżek.
