# Resource Governor – presety (LAB noisy vs PROD friendly) + A/B test

Repo zawiera komplet skryptów do wdrożenia dwóch presetów Resource Governor oraz wygodne uruchamianie z VS Code.

**Presety:**

- **LAB_NOISY** – CAP_CPU=30, MAX_DOP=1, REQUEST_MAX_MEMORY_GRANT_PERCENT=10, MAX_IOPS_PER_VOLUME=800, MIN_IOPS_PER_VOLUME=0
- **PROD_FRIENDLY** – CAP_CPU=30, MAX_DOP=2, REQUEST_MAX_MEMORY_GRANT_PERCENT=15, MAX_IOPS_PER_VOLUME=1500, MIN_IOPS_PER_VOLUME=300

**Klasyfikacja:** najpierw po **grupach AD**, fallback po **Application Name** (`%LAB%` / `%PROD%`). Dodatkowy warunek: domyślna baza logowania = `$(DbName)`.

> Wymagania: SQL Server 2019+ dla `CAP_CPU_PERCENT`. Ograniczanie I/O (`MIN/MAX_IOPS_PER_VOLUME`) wymaga **Enterprise Edition**.

## Struktura

```
scripts/
  00_prereqs.sql      -- sanity check + helpery
  10_presets_ab.sql   -- tworzenie/aktualizacja pooli i grup + classifier
  20_verify.sql       -- szybka weryfikacja przypisań i limitów
  90_cleanup.sql      -- bezpieczny rollback
.vscode/
  tasks.json          -- uruchamianie skryptów z VS Code (sqlcmd)
sqlcmdvars.example.env -- przykładowe wartości zmiennych (do podglądu)
run.ps1               -- alternatywny launcher PowerShell (opcjonalny)
```

## Szybki start (VS Code)

1. Otwórz folder w VS Code.
2. Naciśnij `Ctrl+Shift+P` → **Tasks: Run Task** → wybierz jedną z:
   - **RG: Deploy presets (A/B)** – wdraża 00 + 10 + RECONFIGURE.
   - **RG: Verify** – odpala 20_verify.sql.
   - **RG: Cleanup** – przywraca stan sprzed wdrożenia.
3. Task poprosi o dane: serwer, sposób uwierzytelnienia, nazwy grup AD, wzorce `Application Name`, nazwę bazy itd.

> Uwierzytelnianie: domyślnie **Windows (SSPI)**. Aby użyć loginu SQL, wybierz `SQL` i podaj `User` + `Password` (hasło nie jest zapisywane w plikach).

## Ustawienia zmiennych (sqlcmd)

Skrypty używają zmiennych `sqlcmd` poprzez `:setvar` parametrów przekazywanych z `tasks.json` / PowerShell.
Najważniejsze:

- `DbName` – nazwa bazy, której dotyczy klasyfikacja (sprawdzana jako domyślna DB podczas logowania).
- `AdGroupLab`, `AdGroupProd` – grupy AD. **Uwaga na backslash:** zapisuj jako `DOMENA\NazwaGrupy`.
- `AppNameLabPattern`, `AppNameProdPattern` – fallback po Application Name (np. `%LAB%`, `%PROD%`).

## Ścieżka testowa

- Ustaw w connection string `Application Name=TwojaApp-LAB` (lub `TwojaApp-PROD`).
- Zaloguj się ponownie (klasyfikacja działa **przy logowaniu**).
- Odpal task **RG: Verify** i sprawdź przypisania.

## Bezpieczeństwo i praktyka

- Nie mieszaj tempdb i logu na tym samym woluminie, jeśli limitujesz I/O dla LAB – limity liczą się **per wolumin**.
- Suma `MIN_IOPS_PER_VOLUME` w wielu poolach nie powinna przekraczać realnej wydajności macierzy.
- `MAX_DOP=1` w LAB skutecznie gasi zapędy OLAP – dla PROD rozważ 2–4.
- `REQUEST_MAX_MEMORY_GRANT_PERCENT` dostrajaj obserwując `RESOURCE_SEMAPHORE`.


---

## Demo APP_NAME()

Jeśli nie możesz klasyfikować po grupach AD, możesz użyć wyłącznie `APP_NAME()`:

- **Skrypt:** `scripts/15_classifier_appname_only.sql` – przełącza classifier tak, aby kierował ruch na podstawie `Application Name` (`%LAB%` / `%PROD%`).  
- **PowerShell demo:** `demo_appname.ps1` – otwiera dwie sesje: `Application Name=TwojaApp-LAB` oraz `TwojaApp-PROD` i pokazuje, do których grup wpadły.

### Jak uruchomić demo

1. Upewnij się, że masz wdrożone presety (task **RG: Deploy presets (A/B)**).  
2. Uruchom `scripts/15_classifier_appname_only.sql` (np. przez `sqlcmd` albo SSMS).  
3. W PowerShell:
   ```powershell
   ./demo_appname.ps1 -Server "localhost" -Auth Windows -DbName "TwojaBaza"
   # lub przy SQL logonie:
   ./demo_appname.ps1 -Server "localhost" -Auth SQL -User "sa" -Password "..."
   ```
4. Zobaczysz dwie tabelki z `workload_group` i `pool_name` dla obu sesji.

> W SSMS możesz też ręcznie ustawić `Application Name` w oknie połączenia → **Dodatkowe parametry połączenia**:  
> wklej `Application Name=TwojaApp-LAB` i zaloguj się ponownie.


---

## ADO.NET (C#) – gotowy przykład

Folder: `samples/csharp`

Uruchom demo (wymaga .NET 9 SDK):
```bash
dotnet run --project samples/csharp/AppNameDemo.csproj -- --server localhost --db TwojaBaza
# lub z logowaniem SQL:
dotnet run --project samples/csharp/AppNameDemo.csproj -- --server localhost --db TwojaBaza --user sa --password "P@ssw0rd"
```
Program otwiera dwie sesje z `Application Name=TwojaApp-LAB` oraz `TwojaApp-PROD` i wypisuje `workload_group` oraz `pool_name` dla każdej z nich.

## SSMS – ustawienie Application Name

W oknie logowania → **Opcje** → zakładka **Dodatkowe parametry połączenia** → wklej:
```
Application Name=TwojaApp-LAB
```
Zaloguj się i sprawdź przypisanie (skrypt `scripts/20_verify.sql`). Zmień na `TwojaApp-PROD`, zaloguj się ponownie i porównaj.

## sqlcmd – uwagi

Klasyczny `sqlcmd` ustawia `APP_NAME()` na wartość domyślną (`SQLCMD`) i **nie daje oficjalnej opcji** nadpisania `Application Name` parametrem wiersza poleceń. Do testów **APP_NAME()** używaj:
- SSMS (jak wyżej),
- PowerShell (`demo_appname.ps1`),
- aplikacji klienckich ADO.NET (C# demo powyżej).

*(Jeśli używasz nowszego `go-sqlcmd`, sprawdź dokumentację swojej wersji – składnia opcji może się różnić.)*


---

## VS Code Tasks dla C# demo

- **C#: Build APP_NAME demo** – buduje projekt `samples/csharp`.
- **C#: Run APP_NAME demo (Windows auth)** – uruchamia z `Integrated Security=true`.
- **C#: Run APP_NAME demo (SQL auth)** – uruchamia z `User/Password` podanymi z inputów.

## EF Core – gotowe connection strings

Zajrzyj do `samples/efcore/appsettings.json` i `samples/efcore/README.md`. Ustawiaj `Application Name` na `TwojaApp-LAB` / `TwojaApp-PROD` i steruj klasyfikatorem bez zmian w kodzie.
