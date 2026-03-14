# StockFlow Least Privilege Console Demo

To jest mała aplikacja konsolowa pokazująca, jak zbudować demo **EF Core + SQL Server 2022** w modelu **least privilege**.

## Co pokazuje demo

- mapowanie EF Core do schematu `app`
- przygotowanie migracji EF Core
- wygenerowanie skryptu SQL zamiast `Database.Migrate()` na produkcji
- uruchomienie aplikacji na koncie `stockflow_runtime`
- wykonanie CRUD przez konto runtime
- rozdzielenie konta `stockflow_deploy` i `stockflow_runtime`

## Struktura projektu

- `Program.cs` — główny program demo
- `Data/StockFlowDbContext.cs` — `DbContext`
- `Data/StockFlowDbContextFactory.cs` — factory dla `dotnet ef`
- `Models/Product.cs` — prosta encja
- `appsettings.json` — connection string
- `Scripts/` — miejsce na wygenerowane skrypty migracyjne

## Pakiety NuGet

Projekt używa:

- `Microsoft.EntityFrameworkCore`
- `Microsoft.EntityFrameworkCore.SqlServer`
- `Microsoft.EntityFrameworkCore.Design`
- `Microsoft.Extensions.Hosting`
- `Microsoft.Extensions.Configuration.Json`
- `Microsoft.Extensions.Logging.Console`

## 1. Przygotowanie narzędzia EF Core

W PowerShell:

```powershell
dotnet tool install --global dotnet-ef
```

Jeśli już masz:

```powershell
dotnet tool update --global dotnet-ef
```

## 2. Przywrócenie pakietów

```powershell
dotnet restore
```

## 3. Utworzenie pierwszej migracji

```powershell
dotnet ef migrations add InitialCreate
```

Po tym kroku pojawi się folder `Migrations` z klasami migracji.

## 4. Wygenerowanie skryptu SQL

Wariant podstawowy:

```powershell
dotnet ef migrations script
```

Wariant praktyczny do pliku:

```powershell
dotnet ef migrations script -o .\Scripts\001_InitialCreate.sql
```

Wariant od zera do konkretnej migracji:

```powershell
dotnet ef migrations script 0 InitialCreate -o .\Scripts\001_InitialCreate.sql
```

## 5. Jak to wdrożyć bezpiecznie

### Konto `stockflow_deploy`

To konto:
- wykonuje skrypt migracyjny
- ma prawa DDL tylko do tej bazy i schematów
- nie jest kontem runtime aplikacji

### Konto `stockflow_runtime`

To konto:
- uruchamia aplikację
- ma tylko `SELECT`, `INSERT`, `UPDATE`, `DELETE` na schemacie `app`
- nie wykonuje migracji
- nie ma `db_owner`
- nie ma `sysadmin`

## 6. Konfiguracja connection string

W `appsettings.json` wpisz runtime:

```json
{
  "ConnectionStrings": {
    "StockFlowDb": "Server=SQL01;Database=StockFlowDb;User Id=stockflow_runtime;Password=TwojeHaslo;TrustServerCertificate=True"
  }
}
```

## 7. Uruchomienie aplikacji

```powershell
dotnet run
```

Program wykona:

- test połączenia
- INSERT
- SELECT
- UPDATE
- DELETE

na tabeli `app.Products`.

## 8. Co pokazać na demo live

### Scenariusz prezentacji

1. Pokaż `DbContext` z `HasDefaultSchema("app")`
2. Pokaż encję `Product`
3. Uruchom:

```powershell
dotnet ef migrations add InitialCreate
```

4. Pokaż folder `Migrations`
5. Uruchom:

```powershell
dotnet ef migrations script -o .\Scripts\001_InitialCreate.sql
```

6. Otwórz wygenerowany skrypt SQL
7. Powiedz, że ten skrypt uruchamia konto `stockflow_deploy`
8. Uruchom aplikację na `stockflow_runtime`
9. Pokaż, że CRUD działa
10. Pokaż, że konto runtime nie powinno mieć praw do DDL

## 9. Czego nie robić

Nie rób tego na produkcji:

```csharp
await db.Database.MigrateAsync();
```

pod kontem runtime.

To łamie model least privilege, bo konto aplikacji musiałoby mieć prawa do zmian schematu.

## 10. Weryfikacja

### To ma działać
- `dotnet ef migrations add InitialCreate`
- `dotnet ef migrations script`
- `dotnet run` po wdrożeniu tabel
- CRUD przez konto runtime

### To ma się wywalić
- próba `CREATE TABLE` przez konto runtime
- próba `ALTER SCHEMA` przez konto runtime
- próba uruchamiania migracji produkcyjnych z konta runtime

## 11. Najkrótsza filozofia

Runtime ma robić biznes.
Deployment ma robić DDL.
Admin ma zarządzać środowiskiem.

Nie mieszamy tych ról, bo potem kończy się to wielką przygodą z hasłem `sysadmin` i małym pożarem organizacyjnym.
