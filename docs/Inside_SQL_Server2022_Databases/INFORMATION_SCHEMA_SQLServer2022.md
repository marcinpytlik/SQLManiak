# INFORMATION_SCHEMA w SQL Server 2022 – kompletny przewodnik

> Stan na: 2025-09-19 21:25

Ten dokument zbiera **wszystkie widoki `INFORMATION_SCHEMA` dostępne w SQL Server 2022**, z opisem, najważniejszymi kolumnami, typowymi zastosowaniami, pułapkami oraz gotowymi przykładami zapytań.
Widoki `INFORMATION_SCHEMA` są częścią standardu SQL i zapewniają relatywnie przenośny sposób introspekcji schematu – jednak **nie ujawniają pełni możliwości SQL Server** (do szczegółów służą widoki w schemacie `sys.*`).

**Zakres i ograniczenia**
- Dotyczą **bieżącej bazy danych** – przełączaj się `USE <db>;`.
- Nie obejmują rozszerzeń specyficznych dla SQL Server (np. wielu opcji indeksów, kolumn `rowversion`, memory-optimized itp.).
- Niektóre widoki mogą zwracać **puste zbiory** (np. *DOMAIN\**), ponieważ SQL Server **nie implementuje „DOMAINs”** ze standardu.
- `ROUTINES.ROUTINE_DEFINITION` może być **ucięte** (fragment tekstu). Do pełnej definicji użyj `sys.sql_modules`.

---

## Spis widoków

- `INFORMATION_SCHEMA.CHECK_CONSTRAINTS`
- `INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE`
- `INFORMATION_SCHEMA.COLUMN_PRIVILEGES`
- `INFORMATION_SCHEMA.COLUMNS`
- `INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE`
- `INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE`
- `INFORMATION_SCHEMA.DOMAIN_CONSTRAINTS`
- `INFORMATION_SCHEMA.DOMAINS`
- `INFORMATION_SCHEMA.KEY_COLUMN_USAGE`
- `INFORMATION_SCHEMA.PARAMETERS`
- `INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS`
- `INFORMATION_SCHEMA.ROUTINES`
- `INFORMATION_SCHEMA.SCHEMATA`
- `INFORMATION_SCHEMA.TABLE_CONSTRAINTS`
- `INFORMATION_SCHEMA.TABLE_PRIVILEGES`
- `INFORMATION_SCHEMA.TABLES`
- `INFORMATION_SCHEMA.VIEW_COLUMN_USAGE`
- `INFORMATION_SCHEMA.VIEW_TABLE_USAGE`
- `INFORMATION_SCHEMA.VIEWS`

---

## `INFORMATION_SCHEMA.CHECK_CONSTRAINTS`

**Zastosowanie:** Definicje ograniczeń CHECK z poziomu tabel.

**Kluczowe kolumny:**

- `CONSTRAINT_CATALOG / SCHEMA / NAME` – Identyfikacja ograniczenia.
- `CHECK_CLAUSE` – Wyrażenie logiczne z definicji CHECK.
**Typowe użycia:**

- Audyt warunków biznesowych wymuszanych przez CHECK.
- Wyszukiwanie niepoprawnych lub zbyt ogólnych ograniczeń.
**Pułapki / ograniczenia:**

- Brak informacji o statusie ON/OFF czy NOCHECK – do tego użyj `sys.check_constraints`.
**Przykład:**

```sql
-- Wszystkie CHECK w schemacie dbo
SELECT CONSTRAINT_NAME, CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
  ON cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.TABLE_SCHEMA = 'dbo' AND tc.CONSTRAINT_TYPE = 'CHECK';
```

---

## `INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE`

**Zastosowanie:** Kolumny powiązane z DOMAIN (standard SQL).

**Kluczowe kolumny:**

- `DOMAIN_CATALOG / SCHEMA / NAME` – Domena (typ użytkownika).
- `TABLE_SCHEMA / NAME / COLUMN_NAME` – Miejsce użycia domeny.
**Typowe użycia:**

- Portabilny wgląd w użycie domen – **w SQL Server zwykle pusto**.
**Pułapki / ograniczenia:**

- SQL Server nie wspiera standardowych DOMAIN – używaj `sys.types` dla aliasów typów.
**Przykład:**

```sql
-- Prawdopodobnie zwróci 0 wierszy w SQL Server
SELECT * FROM INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE;
```

---

## `INFORMATION_SCHEMA.COLUMN_PRIVILEGES`

**Zastosowanie:** Przywileje (GRANT/REVOKE) na poziomie kolumn.

**Kluczowe kolumny:**

- `GRANTEE / GRANTOR` – Podmiot i nadawca uprawnienia.
- `TABLE_SCHEMA / NAME / COLUMN_NAME` – Zakres obiektu.
- `PRIVILEGE_TYPE` – SELECT/INSERT/UPDATE/REFERENCES.
- `IS_GRANTABLE` – Czy można przekazać dalej (WITH GRANT OPTION).
**Typowe użycia:**

- Audyt uprawnień na kolumnach, np. PII.
**Pułapki / ograniczenia:**

- Nie pokazuje ról serwerowych ani pośrednich efektów ról – patrz `sys.database_permissions`.
**Przykład:**

```sql
-- Kto ma SELECT na kolumnach tabeli dbo.Osoby?
SELECT GRANTEE, COLUMN_NAME, PRIVILEGE_TYPE
FROM INFORMATION_SCHEMA.COLUMN_PRIVILEGES
WHERE TABLE_SCHEMA='dbo' AND TABLE_NAME='Osoby' AND PRIVILEGE_TYPE='SELECT';
```

---

## `INFORMATION_SCHEMA.COLUMNS`

**Zastosowanie:** Metadane kolumn tabel i widoków.

**Kluczowe kolumny:**

- `TABLE_SCHEMA / NAME / COLUMN_NAME` – Identyfikacja.
- `ORDINAL_POSITION` – Pozycja kolumny.
- `DATA_TYPE` – Nazwa typu (portabilna).
- `CHARACTER_MAXIMUM_LENGTH / NUMERIC_PRECISION / SCALE` – Parametry typu.
- `IS_NULLABLE` – YES/NO.
- `COLUMN_DEFAULT` – Domyślna wartość (tekst).
**Typowe użycia:**

- Szybki, przenośny przegląd schematu tabel.
- Generowanie dokumentacji tabel.
**Pułapki / ograniczenia:**

- `DATA_TYPE` bywa ogólne; szczegóły w `sys.columns`, `sys.types`.
- Brak info o tożsamości, kompresji, sparse, maskowaniu – szukaj w `sys.*`.
**Przykład:**

```sql
-- Kolumny nvarchar w schemacie dbo
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='dbo' AND DATA_TYPE IN ('varchar','nvarchar');
```

---

## `INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE`

**Zastosowanie:** Które kolumny są użyte przez nazwane ograniczenia (PK, FK, UNIQUE, CHECK).

**Kluczowe kolumny:**

- `CONSTRAINT_NAME` – Nazwa ograniczenia.
- `TABLE_SCHEMA / NAME / COLUMN_NAME` – Lokalizacja kolumny.
**Typowe użycia:**

- Mapowanie kolumn do ograniczeń.
**Pułapki / ograniczenia:**

- Nie pokazuje atrybutów indeksów stojących za UNIQUE/PK – użyj `sys.indexes`/`sys.index_columns`.
**Przykład:**

```sql
-- Kolumny uczestniczące w kluczach obcych
SELECT *
FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
WHERE CONSTRAINT_NAME IN (
  SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE CONSTRAINT_TYPE='FOREIGN KEY'
);
```

---

## `INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE`

**Zastosowanie:** Które tabele są użyte przez nazwane ograniczenia.

**Kluczowe kolumny:**

- `CONSTRAINT_NAME` – Nazwa ograniczenia.
- `TABLE_SCHEMA / NAME` – Tabela docelowa.
**Typowe użycia:**

- Spis wszystkich tabel objętych ograniczeniami.
**Pułapki / ograniczenia:**

- Brak typu ograniczenia – dołącz `INFORMATION_SCHEMA.TABLE_CONSTRAINTS`.
**Przykład:**

```sql
-- Tabele mające ograniczenia
SELECT DISTINCT ctu.TABLE_SCHEMA, ctu.TABLE_NAME, tc.CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE ctu
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
  ON tc.CONSTRAINT_NAME = ctu.CONSTRAINT_NAME
ORDER BY ctu.TABLE_SCHEMA, ctu.TABLE_NAME;
```

---

## `INFORMATION_SCHEMA.DOMAIN_CONSTRAINTS`

**Zastosowanie:** Ograniczenia domen (standard SQL).

**Kluczowe kolumny:**

- `DOMAIN_SCHEMA / NAME` – Domena.
- `CONSTRAINT_NAME` – Ograniczenie domeny.
**Typowe użycia:**

- Portabilny przegląd ograniczeń domen – **w SQL Server zwykle pusto**.
**Pułapki / ograniczenia:**

- Brak implementacji DOMAIN w SQL Server – zwykle 0 wierszy.
**Przykład:**

```sql
SELECT * FROM INFORMATION_SCHEMA.DOMAIN_CONSTRAINTS;
```

---

## `INFORMATION_SCHEMA.DOMAINS`

**Zastosowanie:** Listuje domeny (standard SQL – brak w SQL Server).

**Kluczowe kolumny:**

- `DOMAIN_SCHEMA / NAME` – Identyfikacja.
- `DATA_TYPE / LENGTH / PRECISION` – Parametry domeny.
**Typowe użycia:**

- Przenośność wobec systemów z DOMAIN – **w SQL Server zwykle pusto**.
**Pułapki / ograniczenia:**

- W SQL Server brak domen – to nie to samo co `CREATE TYPE AS TABLE` lub aliasy typów.
**Przykład:**

```sql
SELECT * FROM INFORMATION_SCHEMA.DOMAINS;
```

---

## `INFORMATION_SCHEMA.KEY_COLUMN_USAGE`

**Zastosowanie:** Kolumny uczestniczące w PK/UNIQUE/FK.

**Kluczowe kolumny:**

- `CONSTRAINT_NAME` – Nazwa ograniczenia.
- `TABLE_SCHEMA / NAME / COLUMN_NAME` – Kolumna.
- `ORDINAL_POSITION` – Kolejność w kluczu złożonym.
**Typowe użycia:**

- Eksport mapy kluczy głównych, unikalnych i obcych.
**Pułapki / ograniczenia:**

- Nie pokazuje sort order (ASC/DESC) ani INCLUDE – patrz `sys.index_columns`.
**Przykład:**

```sql
-- Kolumny w kluczach głównych
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE k
JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
  ON k.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_TYPE='PRIMARY KEY'
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
```

---

## `INFORMATION_SCHEMA.PARAMETERS`

**Zastosowanie:** Parametry procedur i funkcji.

**Kluczowe kolumny:**

- `SPECIFIC_SCHEMA / NAME` – Schemat/nazwa obiektu rutyny.
- `PARAMETER_NAME` – Nazwa parametru.
- `ORDINAL_POSITION` – Kolejność.
- `DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION` – Typ i parametry.
- `PARAMETER_MODE` – IN/OUT/INOUT (dla SQL Server głównie IN).
**Typowe użycia:**

- Generowanie nagłówków procedur/funkcji.
- Walidacja zgodności kontraktów API DB.
**Pułapki / ograniczenia:**

- Typy złożone (np. TVP) w `INFORMATION_SCHEMA` są uproszczone – sprawdzaj `sys.table_types`.
**Przykład:**

```sql
-- Parametry wszystkich procedur w dbo
SELECT SPECIFIC_NAME, PARAMETER_NAME, DATA_TYPE, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE SPECIFIC_SCHEMA='dbo'
ORDER BY SPECIFIC_NAME, ORDINAL_POSITION;
```

---

## `INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS`

**Zastosowanie:** Relacje kluczy obcych (FK) – powiązanie między ograniczeniami.

**Kluczowe kolumny:**

- `CONSTRAINT_NAME` – Nazwa FK.
- `UNIQUE_CONSTRAINT_NAME` – Powiązany PK/UNIQUE po drugiej stronie.
- `MATCH_OPTION / UPDATE_RULE / DELETE_RULE` – Zachowania referencyjne.
**Typowe użycia:**

- Mapa relacji FK (kaskady, ograniczenia).
**Pułapki / ograniczenia:**

- Brak listy kolumn – dołącz `KEY_COLUMN_USAGE`.
**Przykład:**

```sql
-- FK + reguły kasowania/aktualizacji
SELECT CONSTRAINT_NAME, UNIQUE_CONSTRAINT_NAME, UPDATE_RULE, DELETE_RULE
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS;
```

---

## `INFORMATION_SCHEMA.ROUTINES`

**Zastosowanie:** Procedury i funkcje skalarne/tabelaryczne.

**Kluczowe kolumny:**

- `ROUTINE_SCHEMA / NAME / TYPE` – Identyfikacja i typ (PROCEDURE/FUNCTION).
- `DATA_TYPE` – Typ zwracany (dla funkcji).
- `ROUTINE_DEFINITION` – Fragment definicji (może być ucięty).
**Typowe użycia:**

- Szyborys rutyn w bazie.
- Automatyczny spis API DB.
**Pułapki / ograniczenia:**

- `ROUTINE_DEFINITION` bywa niepełne – pełny tekst pobierzesz z `sys.sql_modules`.
**Przykład:**

```sql
-- Lista procedur/funkcji w dbo
SELECT ROUTINE_NAME, ROUTINE_TYPE, DATA_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA='dbo'
ORDER BY ROUTINE_TYPE, ROUTINE_NAME;
```

---

## `INFORMATION_SCHEMA.SCHEMATA`

**Zastosowanie:** Lista schematów w bazie.

**Kluczowe kolumny:**

- `CATALOG_NAME / SCHEMA_NAME` – Baza i schemat.
- `SCHEMA_OWNER` – Właściciel schematu.
**Typowe użycia:**

- Audyt i porządkowanie przestrzeni nazw.
**Pułapki / ograniczenia:**

- Zmiany własności i mapowania użytkowników czy ról śledź w `sys.schemas` i `sys.database_principals`.
**Przykład:**

```sql
SELECT * FROM INFORMATION_SCHEMA.SCHEMATA;
```

---

## `INFORMATION_SCHEMA.TABLE_CONSTRAINTS`

**Zastosowanie:** Ograniczenia tabel: PRIMARY KEY, UNIQUE, FOREIGN KEY, CHECK.

**Kluczowe kolumny:**

- `CONSTRAINT_NAME / TYPE` – Typ ograniczenia.
- `TABLE_SCHEMA / NAME` – Obiekt docelowy.
**Typowe użycia:**

- Szybka lista ograniczeń i ich typów.
**Pułapki / ograniczenia:**

- Brak szczegółów (kolumny, atrybuty indeksu) – dołącz `KEY_COLUMN_USAGE` i `sys.*`.
**Przykład:**

```sql
-- Wszystkie PK/UNIQUE w dbo
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA='dbo' AND CONSTRAINT_TYPE IN ('PRIMARY KEY','UNIQUE')
ORDER BY TABLE_NAME;
```

---

## `INFORMATION_SCHEMA.TABLE_PRIVILEGES`

**Zastosowanie:** Przywileje na tabelach/widokach (GRANT/REVOKE).

**Kluczowe kolumny:**

- `GRANTEE / GRANTOR` – Adresaci i nadawcy.
- `TABLE_SCHEMA / NAME` – Obiekt.
- `PRIVILEGE_TYPE` – SELECT/INSERT/UPDATE/DELETE/REFERENCES.
- `IS_GRANTABLE` – Czy z GRANT OPTION.
**Typowe użycia:**

- Audyt uprawnień na obiektach.
**Pułapki / ograniczenia:**

- Nie pokazuje ról pośrednich ani `DENY` wprost – pełny obraz w `sys.database_permissions`.
**Przykład:**

```sql
-- Kto ma SELECT na tabelach dbo
SELECT TABLE_NAME, GRANTEE, PRIVILEGE_TYPE
FROM INFORMATION_SCHEMA.TABLE_PRIVILEGES
WHERE TABLE_SCHEMA='dbo' AND PRIVILEGE_TYPE='SELECT'
ORDER BY TABLE_NAME;
```

---

## `INFORMATION_SCHEMA.TABLES`

**Zastosowanie:** Lista tabel i widoków.

**Kluczowe kolumny:**

- `TABLE_SCHEMA / NAME` – Identyfikacja.
- `TABLE_TYPE` – 'BASE TABLE' lub 'VIEW'.
**Typowe użycia:**

- Spis obiektów do dokumentacji/migracji.
**Pułapki / ograniczenia:**

- Nie odróżnia typów specjalnych (temporal, external, memory-optimized) – patrz `sys.tables`.
**Przykład:**

```sql
-- Tylko tabele użytkownika (bez systemowych)
SELECT * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

---

## `INFORMATION_SCHEMA.VIEW_COLUMN_USAGE`

**Zastosowanie:** Kolumny bazowe użyte w definicjach widoków.

**Kluczowe kolumny:**

- `VIEW_SCHEMA / NAME` – Widok.
- `TABLE_SCHEMA / NAME / COLUMN_NAME` – Kolumna bazowa użyta we widoku.
**Typowe użycia:**

- Analiza wpływu zmian (impact analysis) na kolumny używane przez widoki.
**Pułapki / ograniczenia:**

- Może **nie wykryć** użycia przy `SELECT *`, wyrażeniach, funkcjach – parsowanie jest ograniczone.
**Przykład:**

```sql
-- Jakie kolumny tabel dbo.* są użyte w widokach?
SELECT *
FROM INFORMATION_SCHEMA.VIEW_COLUMN_USAGE
WHERE TABLE_SCHEMA='dbo'
ORDER BY VIEW_NAME, TABLE_NAME, COLUMN_NAME;
```

---

## `INFORMATION_SCHEMA.VIEW_TABLE_USAGE`

**Zastosowanie:** Tabele bazowe użyte w definicjach widoków.

**Kluczowe kolumny:**

- `VIEW_SCHEMA / NAME` – Widok.
- `TABLE_SCHEMA / NAME` – Tabela bazowa.
**Typowe użycia:**

- Impact analysis na poziomie tabel.
**Pułapki / ograniczenia:**

- Analogiczne ograniczenia jak przy `VIEW_COLUMN_USAGE` (SELECT * itd.).
**Przykład:**

```sql
-- Zależności widok → tabela w schemacie dbo
SELECT *
FROM INFORMATION_SCHEMA.VIEW_TABLE_USAGE
WHERE VIEW_SCHEMA='dbo'
ORDER BY VIEW_NAME, TABLE_NAME;
```

---

## `INFORMATION_SCHEMA.VIEWS`

**Zastosowanie:** Lista widoków i ich (częściowych) definicji.

**Kluczowe kolumny:**

- `TABLE_SCHEMA / NAME` – Identyfikacja widoku.
- `CHECK_OPTION / IS_UPDATABLE` – Atrybuty standardowe.
- `VIEW_DEFINITION` – Fragment definicji (może być ucięty).
**Typowe użycia:**

- Szybka lista widoków z podglądem definicji.
**Pułapki / ograniczenia:**

- `VIEW_DEFINITION` może być niepełne – szczegóły w `sys.sql_modules`.
**Przykład:**

```sql
-- Widoki w dbo
SELECT TABLE_NAME, LEFT(VIEW_DEFINITION, 200) AS DEF_SAMPLE
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA='dbo'
ORDER BY TABLE_NAME;
```

---


## Mapowanie na `sys.*` (dla szczegółów specyficznych dla SQL Server)

| INFORMATION_SCHEMA | Typowo odpowiada w `sys.*` |
|---|---|
| CHECK_CONSTRAINTS | `sys.check_constraints`, `sys.objects` |
| COLUMN_PRIVILEGES | `sys.database_permissions`, `sys.database_principals` |
| COLUMNS | `sys.columns`, `sys.types`, `sys.objects` |
| CONSTRAINT_COLUMN_USAGE | `sys.key_constraints`, `sys.foreign_keys`, `sys.index_columns` |
| CONSTRAINT_TABLE_USAGE | `sys.tables`, `sys.key_constraints`, `sys.foreign_keys` |
| KEY_COLUMN_USAGE | `sys.indexes`, `sys.index_columns`, `sys.key_constraints` |
| PARAMETERS | `sys.parameters`, `sys.types` |
| REFERENTIAL_CONSTRAINTS | `sys.foreign_keys`, `sys.foreign_key_columns` |
| ROUTINES | `sys.objects`, `sys.procedures`, `sys.sql_modules`, `sys.objects` (functions) |
| SCHEMATA | `sys.schemas`, `sys.database_principals` |
| TABLE_CONSTRAINTS | `sys.key_constraints`, `sys.objects`, `sys.check_constraints` |
| TABLE_PRIVILEGES | `sys.database_permissions`, `sys.database_principals` |
| TABLES | `sys.tables`, `sys.views` |
| VIEW_COLUMN_USAGE | `sys.sql_expression_dependencies` (dokładniejsze zależności) |
| VIEW_TABLE_USAGE | `sys.sql_expression_dependencies` |
| VIEWS | `sys.views`, `sys.sql_modules` |
| DOMAINS / DOMAIN_CONSTRAINTS / COLUMN_DOMAIN_USAGE | (zwykle puste w SQL Server) |

> Do analizy zależności preferuj `sys.sql_expression_dependencies`, który radzi sobie lepiej z aliasami, `SELECT *` i złożonymi wyrażeniami.
