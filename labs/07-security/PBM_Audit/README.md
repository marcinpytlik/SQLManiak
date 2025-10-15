# PBM + Audit — Mini Repo (SQL Server 2022)

Minimalny zestaw, aby monitorować **kto/co/kiedy** (Audit) oraz **co odjechało** w konfiguracji (PBM).  
Gotowe pod VS Code / GitHub.

## Struktura
- `docs/Guide.md` — krótki przewodnik wdrożeniowy.
- `sql/01_Audit.sql` — tworzy Server Audit + Server Audit Specification.
- `sql/02_PBM.sql` — tworzy Condition + Policy + Job do oceny co 5 minut.
- `sql/03_Reports.sql` — przykład raportów: Audit, PBM oraz korelacja.
- `.vscode/tasks.json` — prosty task do uruchamiania T-SQL (komentarz jak użyć).

## Wymagania
- SQL Server 2022 (Developer/Enterprise).
- Uprawnienia sysadmin do tworzenia audytu i PBM.
- Katalog dla plików audytu (np. `E:\SQLAudit\`) — **na FCI użyj dysku współdzielonego**.

## Szybki start
1. Otwórz repo w VS Code.
2. Zaadaptuj ścieżkę audytu w `sql/01_Audit.sql`.
3. Uruchom kolejno: `01_Audit.sql`, `02_PBM.sql`.
4. Zweryfikuj wyniki w `03_Reports.sql`.
