# EF Core – Connection Strings z APP_NAME()

W tym folderze masz przykładowy `appsettings.json` z czterema connection stringami:
- `Lab_Windows` / `Prod_Windows` – Windows Auth
- `Lab_SQL` / `Prod_SQL` – SQL Auth

Każdy z nich ustawia inne `Application Name`, co pozwala klasyfikatorowi RG przypiąć sesję do odpowiedniej grupy.

## Szybka konfiguracja w `Program.cs` (ASP.NET Core / Worker)

```csharp
var builder = WebApplication.CreateBuilder(args);

// wybór presetu przez zmienną środowiskową RG_PRESET = lab|prod
var preset = Environment.GetEnvironmentVariable("RG_PRESET")?.ToLowerInvariant() ?? "lab";
var auth = Environment.GetEnvironmentVariable("RG_AUTH")?.ToLowerInvariant() ?? "windows"; // windows|sql

string name = (preset, auth) switch
{
    ("lab","windows") => "Lab_Windows",
    ("lab","sql")     => "Lab_SQL",
    ("prod","windows")=> "Prod_Windows",
    ("prod","sql")    => "Prod_SQL",
    _ => "Lab_Windows"
};

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString(name)));

var app = builder.Build();
app.Run();
```

> Przełączanie między presetami na produkcji? Ustal `RG_PRESET=prod` w zmiennych środowiskowych – **bez rekompilacji**.
