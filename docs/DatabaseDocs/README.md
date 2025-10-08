# Database Documentation – SQL Server 

Celem paczki jest **zautomatyzować dokumentowanie baz danych**: słownik danych (tabele/kolumny/opisy), widoki,
procedury, indeksy i klucze obce, a także wypluć gotowe pliki **CSV i Markdown** do repo Git.

## Co tu jest
- `Scripts/` – T‑SQL (raporty metadanych, walidacja opisów, eksport ERD→GraphViz DOT)
- `PowerShell/Generate-DbDocs.ps1` – generator CSV + Markdown (Invoke‑Sqlcmd, bez SSMS)
- `Templates/Markdown_Header.md` – nagłówek do plików dokumentacji
- `Docs/` – katalog wyjściowy (per baza powstaną podfoldery)
- `.vscode/tasks.json` – zadanie do uruchomienia generatora z VS Code

## Szybki start
1. Upewnij się, że masz moduł **SqlServer** w PowerShell (`Install-Module SqlServer`).
2. Otwórz folder w VS Code i uruchom task **Docs: Generate (CSV+MD)**.
3. Wyniki znajdziesz w `Docs/<DatabaseName>/`:
   - `DataDictionary.md` – przegląd i spis treści
   - `01_Tables.md`, `02_Views.md`, `03_Procedures.md`, `04_Constraints.md`
   - CSV: `Tables.csv`, `Columns.csv`, `Views.csv`, `Procedures.csv`, `ForeignKeys.csv`
   - `ERD.dot` – plik GraphViz (opcjonalne renderowanie do PNG/SVG poza repo)

## Standard opisów (extended properties)
W całym projekcie zakładamy użycie `MS_Description` dla baz/tabel/kolumn/widoków. Skrypty w `Scripts/` pomogą:
- dodać lub zaktualizować opisy,
- zwalidować brakujące opisy (`Validate_Missing_MS_Description.sql`).

## Integracja z CI/CD
- Możesz dodać job (GitHub Actions / Azure DevOps) uruchamiający `Generate-DbDocs.ps1` cyklicznie.
- Walidacja: build faile’uje, jeśli `Validate_Missing_MS_Description.sql` zwróci braki.

