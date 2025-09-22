# INFORMATION_SCHEMA vs SQL Server 2022 – zgodność ze standardem

> Wygenerowano: 2025-09-19 21:37

## Wprowadzenie
`INFORMATION_SCHEMA` jest częścią standardu SQL (od SQL-92, rozwinięty w SQL:1999 i kolejnych).  
SQL Server 2022 implementuje tylko **część** tego standardu.  
Microsoft utrzymuje te widoki głównie dla **zgodności i przenośności**, ale nie rozwija ich o nowe funkcje.

---

## Porównanie widoków

| Widok standardowy              | Status w SQL Server 2022       | Odpowiednik w `sys.*` / inne źródło |
|--------------------------------|--------------------------------|-------------------------------------|
| **TABLES**                     | ✅ Implementowany              | `sys.tables`, `sys.views` |
| **COLUMNS**                    | ✅ Implementowany              | `sys.columns`, `sys.types` |
| **SCHEMATA**                   | ✅ Implementowany              | `sys.schemas`, `sys.database_principals` |
| **TABLE_CONSTRAINTS**          | ✅ Implementowany              | `sys.key_constraints`, `sys.check_constraints`, `sys.foreign_keys` |
| **KEY_COLUMN_USAGE**           | ✅ Implementowany              | `sys.index_columns`, `sys.key_constraints`, `sys.foreign_keys` |
| **REFERENTIAL_CONSTRAINTS**    | ✅ Implementowany              | `sys.foreign_keys`, `sys.foreign_key_columns` |
| **CHECK_CONSTRAINTS**          | ✅ Implementowany              | `sys.check_constraints` |
| **CONSTRAINT_COLUMN_USAGE**    | ✅ Implementowany              | `sys.key_constraints`, `sys.foreign_keys` |
| **CONSTRAINT_TABLE_USAGE**     | ✅ Implementowany              | `sys.tables`, `sys.key_constraints`, `sys.foreign_keys` |
| **ROUTINES**                   | ✅ Implementowany              | `sys.objects` (procedures/functions), `sys.sql_modules` |
| **PARAMETERS**                 | ✅ Implementowany              | `sys.parameters` |
| **VIEWS**                      | ✅ Implementowany              | `sys.views`, `sys.sql_modules` |
| **VIEW_TABLE_USAGE**           | ✅ Implementowany              | `sys.sql_expression_dependencies` |
| **VIEW_COLUMN_USAGE**          | ✅ Implementowany              | `sys.sql_expression_dependencies` |
| **COLUMN_PRIVILEGES**          | ✅ Implementowany              | `sys.database_permissions`, `sys.database_principals` |
| **TABLE_PRIVILEGES**           | ✅ Implementowany              | `sys.database_permissions`, `sys.database_principals` |
| **DOMAINS**                    | ⚠️ Obecny, pusty              | brak (SQL Server nie wspiera `DOMAIN`) |
| **DOMAIN_CONSTRAINTS**         | ⚠️ Obecny, pusty              | brak |
| **COLUMN_DOMAIN_USAGE**        | ⚠️ Obecny, pusty              | brak |
| **TRIGGERS**                   | ❌ Brak                       | `sys.triggers`, `sys.trigger_events` |
| **SEQUENCES**                  | ❌ Brak                       | `sys.sequences` |
| **CHARACTER_SETS**             | ❌ Brak                       | `sys.syslanguages` (częściowo), `sys.fn_helpcollations()` |
| **COLLATIONS**                 | ❌ Brak                       | `sys.fn_helpcollations()` |
| **TRANSLATIONS**               | ❌ Brak                       | brak |
| **ROUTINE_COLUMNS**            | ❌ Brak                       | `sys.columns` + `sys.objects` (dla funkcji tabelarycznych) |
| **USER_DEFINED_TYPES**         | ❌ Brak                       | `sys.types` (dla aliasów i UDT) |
| **ELEMENT_TYPES**              | ❌ Brak                       | brak |
| **ATTRIBUTES**                 | ❌ Brak                       | `sys.types`, `sys.assembly_types` (dla CLR UDT) |
| **MODULES**                    | ❌ Brak                       | `sys.sql_modules` |
| **MODULE_CONSTRAINTS**         | ❌ Brak                       | brak |
| **ASSERTIONS**                 | ❌ Brak                       | brak (SQL Server w ogóle nie wspiera `ASSERTION`) |

---

## Kluczowe wnioski
- SQL Server implementuje **rdzeń INFORMATION_SCHEMA** – głównie wokół tabel, kolumn, constraints, widoków i procedur.  
- Widoki związane z **domenami** są obecne, ale zawsze puste.  
- Nowoczesne obiekty SQL Server (`SEQUENCE`, `TRIGGER`, `UDT`, `temporal tables`, `memory-optimized`, `masking`, `row-level security`) **nie są widoczne w INFORMATION_SCHEMA**.  
- Do podstawowej, przenośnej dokumentacji – używaj `INFORMATION_SCHEMA`.  
- Do pełnej administracji i analizy – zawsze sięgaj po **`sys.*`** i DMV.  

---
