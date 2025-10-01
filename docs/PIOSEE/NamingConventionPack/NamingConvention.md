# Naming Convention — SQL Server (ASCII-only dla nazw obiektów)

**Cel:** spójne, czytelne nazewnictwo obiektów SQL Server oraz automatyczne wykrywanie i naprawa odchyleń.

## Zasady ogólne
- ASCII, bez spacji/PL znaków; separator `_` lub PascalCase (poniżej: PascalCase dla obiektów + `_` w indeksach/constraintach).
- Pojedyncza liczba: `Customer`, nie `Customers`.
- Regex nazw: `^[A-Za-z][A-Za-z0-9_]*$`.
- Unikamy słów zastrzeżonych.
- Środowiska w nazwie bazy: `App_ENV` (`DEV`/`UAT`/`PROD`).

## Bazy i schematy
- **Baza:** `Erp_PROD`, `Erp_DEV`.
- **Schematy:** funkcjonalne: `app`, `ref`, `cfg`, `sec`, `stg`, `ods`, `dw`.

## Obiekty
- **Tabela:** `Schema.TableName` → `app.Order`.
- **Widok:** `Schema.vw_Name` → `app.vw_OrderSummary`.
- **Procedura:** `Schema.usp_VerbNoun` → `app.usp_OrderUpsert` (unikamy `sp_`).
- **Funkcja scalar:** `Schema.ufn_Name` → `app.ufn_CalculateTax`.
- **Funkcja TVF:** `Schema.utvf_Name` → `app.utvf_SplitString`.
- **Trigger:** `Schema.trg_Table_Action` → `app.trg_Order_IU` (I/U/D).
- **Synonim:** `Schema.syn_Target` → `app.syn_ReportingDb_dbo_FactSales`.
- **Sekwencja:** `Schema.seq_Table_Column` → `app.seq_Order_OrderId`.

## Kolumny
- PK: `Id` lub `{TableName}Id` (konsekwentnie jeden styl).
- FK: `{RefTable}Id` → `CustomerId`.
- Audyt: `CreatedAt`, `CreatedBy`, `ModifiedAt`, `ModifiedBy`, `DeletedAt`, `IsDeleted`, `RowVersion`.

## Constrainty i indeksy
- **PK:** `PK_{Schema}_{Table}` → `PK_app_Order`.
- **FK:** `FK_{Schema}_{Child}__{Schema}_{Parent}` → `FK_app_Order__ref_Customer`.
- **UNIQUE:** `UQ_{Schema}_{Table}_{Cols}` → `UQ_app_User_Email`.
- **CHECK:** `CK_{Schema}_{Table}_{Col}[_Rule]` → `CK_app_Order_Amount_gt0`.
- **DEFAULT:** `DF_{Schema}_{Table}_{Col}` → `DF_app_Order_Status`.
- **Indeks NonClustered:** `IX_{Schema}_{Table}_{Cols}[_INC_{IncCols}]`.
- **Indeks Unique:** `IXU_{Schema}_{Table}_{Cols}`.

## SQL Agent
- **Job:** `JOB_{System}_{Area}_{Action}` → `JOB_ERP_Orders_DailyLoad`.
- **Step:** `STEP_{nn}_{Verb}` → `STEP_10_Extract`.
- **Schedule:** `SCH_{Job}_{Freq}` → `SCH_ERP_Orders_Daily_0200`.

## VS Code – uruchamianie audytów i refaktoryzacji
- Otwórz folder w VS Code.
- W `Run Task…` wybierz:
  - **Audit naming (read‑only)** – wykrywa odchylenia.
  - **Preview renames (PRINT only)** – generuje polecenia `sp_rename`, ale tylko je wypisuje.
  - **Apply renames** – wykonuje rename (upewnij się na DEV!).

---

## FAQ
**Czy `sp_rename` jest bezpieczne?** Zmienia nazwę obiektu; nie zmienia zależności w kodzie (np. t‑SQL, SSIS). Używaj na DEV i miej testy.
**Jak weryfikować długość nazwy?** Skrypty tną do 128 znaków i zastępują znaki poza `A‑Z0‑9_`.
