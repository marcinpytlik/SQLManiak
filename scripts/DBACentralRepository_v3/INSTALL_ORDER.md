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
15_Create_Database_Report_Views.sql
16_Create_Database_Documentation_Lifecycle.sql
17_Create_Database_Schema_Change_Tracking.sql
18_Create_Database_Documentation_Agent_Job.sql
19_Create_Patch_Audit_Lifecycle.sql
20_Create_Perf_Module.sql
21_Create_Perf_Retention.sql
22_Create_Grafana_Views.sql
23_Create_Perf_Agent_Job.sql
24_Create_Table_Usage_Module.sql
25_Create_Table_Usage_Agent_Job.sql
98_Verify_Installation.sql
99_Useful_Queries.sql
```

## Zasady

- Pliki `00–25` tworzą lub aktualizują obiekty.
- `20–21` dodają historyczny moduł `perf`.
- `22` jest stabilną warstwą prezentacji dla Grafany (`report.vGrafana*`).
- `23` tworzy niezależny job collectora wydajności, domyślnie co 5 minut.
- `24` dodaje moduł TABLE USAGE: snapshoty `sys.dm_db_index_usage_stats`, konfigurację SQL Audit oraz raport technical vs other.
- `25` tworzy opcjonalny job collectora TABLE USAGE, domyślnie co 5 minut.
- `14` i `18` pozostają bez zmian, więc istniejąca automatyzacja Confluence nadal działa. Można ją wyłączyć później, po zaakceptowaniu dashboardów Grafana.
- `98_Verify_Installation.sql` służy do kontroli instalacji.
- `99_Useful_Queries.sql` zawiera tylko zapytania kontrolne i raportowe.
- Tabele i indeksy są chronione testami istnienia, a procedury i widoki korzystają z `CREATE OR ALTER` tam, gdzie jest to możliwe.
- Nazwy obiektów są zapisywane w konwencji `[schemat].[Obiekt]`.
- Przed uruchomieniem `14`, `18`, `23` i `25` ustaw ścieżki, konto właściciela i nazwę instancji repozytorium.
