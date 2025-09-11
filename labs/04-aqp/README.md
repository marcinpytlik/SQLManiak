
# AQP / IQP – Labs (SQL Server 2022)

Zestaw ćwiczeń do **Query Optimizer & Adaptive Query Processing** (PSP, Memory Grant Feedback, Adaptive Joins, Interleaved Execution, Query Store Hints). Docelowo uruchamiasz je z VS Code przez `Tasks` lub pojedynczo w ulubionym kliencie.

## Wymagania
- SQL Server 2022 **Developer** (lokalny lub zdalny).
- Narzędzie `sqlcmd` w PATH (Windows lub cross‑platform).
- Visual Studio Code (opcjonalnie rozszerzenie *MS SQL*).
- Uprawnienia do tworzenia bazy oraz `ALTER DATABASE`.

## Szybki start
1. Otwórz folder `aqp-labs/` w VS Code.
2. Naciśnij **Ctrl+Shift+P → Tasks: Run Task** i wybierz:
   - `SQL: Run ALL labs (Windows Auth)` **lub**
   - `SQL: Run ALL labs (SQL Auth)`
3. Podaj nazwę serwera (np. `localhost` albo `localhost,1433`). Baza labowa utworzy się sama: **AQP_Lab**.
4. Przejdź do sekcji *Weryfikacja* w każdym skrypcie.

> Jeśli PowerShell zablokuje uruchamianie skryptów, odpal w tym oknie:
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

## Co jest w środku
- `sql/00_setup.sql` – tworzy bazę **AQP_Lab**, włącza Query Store (RW) i przełączniki IQP/AQP, zakłada dane `dbo.Skew` z dużym skewem.
- `sql/01_psp.sql` – **Parameter Sensitive Plan**: warianty planu per zakres parametru, weryfikacja w Query Store.
- `sql/02_mgf.sql` – **Memory Grant Feedback** z persystencją (SQL 2022), odczyt `sys.query_store_plan_feedback`.
- `sql/03_adaptive_joins.sql` – **Adaptive Join** w batch‑mode‑on‑rowstore.
- `sql/04_interleaved_exec.sql` – **Interleaved Execution** dla MSTVF (realne kardynalności).
- `sql/05_qs_hints.sql` – **Query Store Hints** bez zmiany kodu.
- `sql/99_cleanup.sql` – sprzątanie (DROP DATABASE AQP_Lab).
- `run_all.ps1` – pomocniczy skrypt uruchamiający wszystkie pliki z `sql/` w kolejności.
- `.vscode/tasks.json` – zadania do uruchamiania skryptów (Windows/SQL Auth).

## Uwaga praktyczna
Niektóre mechanizmy wymagają **poziomu zgodności 160** i **Query Store** w trybie RW (np. PSP, DOP/MGF/CE feedback, QS hints). Skrypty ustawiają to jawnie. Jeśli masz globalnie wyłączony sniffing (np. TF 4136 lub `PARAMETER_SNIFFING = OFF`), test PSP nie zadziała – przywróć domyślne ustawienia na czas labu.

## Kolejność
0️⃣ Setup → 1️⃣ PSP → 2️⃣ MGF → 3️⃣ Adaptive → 4️⃣ Interleaved → 5️⃣ QS Hints → 9️⃣ Sprzątanie.
