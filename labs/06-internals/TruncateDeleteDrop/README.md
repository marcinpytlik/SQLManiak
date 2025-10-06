#  DELETE, TRUNCATE, DROP, blokady i wersjonowanie (SQL Server 2022)

Zestaw krótkich laboratoriów „light” + ściągi, repo‑ready pod VS Code. Wszystko operuje na `tempdb` lub na osobnej bazie demo, więc jest bezpieczne dla produkcji, ale **uruchamiaj tylko na środowisku testowym**.

## Spis treści
1. **01_DeleteVsTruncate** – mechanika, ghost records, logowanie, odzyskiwanie po TRUNCATE.
2. **02_TruncateVsDrop** – „czyszczenie” vs „wysadzenie” (struktura vs metadane).
3. **03_CheatSheet** – porównanie DELETE vs TRUNCATE vs DROP w jednej tabeli.
4. **04_LocksTransactions** – blokady i transakcje (Sch-M vs RID/KEY/PAGE/TAB), eskalacja, rollback.
5. **05_RCSI_vs_SI** – wersjonowanie stron: READ_COMMITTED_SNAPSHOT vs SNAPSHOT ISOLATION, wpływ na DELETE/TRUNCATE i waity.

## Wymagania
- SQL Server 2022 (Developer/Express/Standard/Enterprise) – testowane pod 2022.
- Windows / Linux z `sqlcmd` w PATH (lub uruchamiaj pliki `.sql` z poziomu VS Code / SQLTools).
- Uprawnienia `db_owner` w `tempdb` oraz do tworzenia własnej bazy demo.

## Szybki start w VS Code
- Otwórz folder repo w VS Code.
- Użyj tasku **Run current SQL with sqlcmd** (Ctrl+Shift+B → wybierz task), aby odpalić aktualnie otwarty plik `.sql`.
- Domyślnie task łączy się do `localhost` z uwierzytelnieniem Windows (`-E`). Zmień w `.vscode/tasks.json` jeśli potrzebujesz.
