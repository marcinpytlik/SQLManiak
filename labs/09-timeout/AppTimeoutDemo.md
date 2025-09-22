# AppTimeoutDemo – Symulacja timeoutów po stronie aplikacji

## Cel
Pokazanie scenariuszy, w których aplikacja zgłasza timeouty, a po stronie SQL Server nic się nie dzieje.

## Scenariusze
1. **Exhaustion puli połączeń (Connection Pool)** – aplikacja wyczerpuje pulę połączeń i zgłasza timeouty jeszcze zanim wyśle zapytanie do SQL Server.
2. **Starvation ThreadPool** – aplikacja blokuje workery .NET ThreadPool, co powoduje wzrost czasów odpowiedzi i timeouty, bez faktycznych zapytań do SQL.

---

## Instalacja i konfiguracja

### Tworzenie projektu
```bash
mkdir AppTimeoutDemo && cd AppTimeoutDemo
dotnet new web -n AppTimeoutDemo
cd AppTimeoutDemo
dotnet add package Microsoft.Data.SqlClient
```

### appsettings.json
```json
{
  "ConnectionStrings": {
    "Sql": "Server=localhost,1433;Database=master;User ID=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;Max Pool Size=3;Connect Timeout=5"
  },
  "Demo": {
    "HoldCount": 3,
    "HoldLifespanSeconds": 300
  }
}
```

### Program.cs
```csharp
using System.Collections.Concurrent;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var connStr = builder.Configuration.GetConnectionString("Sql")!;
var holdCount = builder.Configuration.GetValue<int>("Demo:HoldCount", 3);
var holdLifespan = TimeSpan.FromSeconds(builder.Configuration.GetValue<int>("Demo:HoldLifespanSeconds", 300));

static readonly ConcurrentBag<SqlConnection> _leaked = new();

app.MapPost("/leak", async ctx =>
{
    var opened = 0;
    while (opened < holdCount)
    {
        var c = new SqlConnection(connStr);
        await c.OpenAsync();
        _leaked.Add(c);
        opened++;
    }

    _ = Task.Run(async () =>
    {
        await Task.Delay(holdLifespan);
        while (_leaked.TryTake(out var x)) { try { x.Dispose(); } catch { } }
    });

    await ctx.Response.WriteAsJsonAsync(new { status = "leaked", count = opened });
});

app.MapGet("/query", async ctx =>
{
    try
    {
        await using var c = new SqlConnection(connStr);
        await c.OpenAsync();
        await using var cmd = c.CreateCommand();
        cmd.CommandText = "SELECT 1";
        var result = await cmd.ExecuteScalarAsync();
        await ctx.Response.WriteAsJsonAsync(new { ok = true, result });
    }
    catch (Exception ex)
    {
        ctx.Response.StatusCode = 500;
        await ctx.Response.WriteAsJsonAsync(new { ok = false, error = ex.Message });
    }
});

app.MapGet("/starve", async ctx =>
{
    var tcs = new TaskCompletionSource();
    ThreadPool.QueueUserWorkItem(_ =>
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < 50) { }
        Thread.Sleep(5000);
        tcs.SetResult();
    });
    await tcs.Task;
    await ctx.Response.WriteAsJsonAsync(new { ok = true, note = "Starved for ~5s" });
});

app.MapPost("/reset", async ctx =>
{
    var n = 0;
    while (_leaked.TryTake(out var c)) { try { c.Dispose(); n++; } catch { } }
    await ctx.Response.WriteAsJsonAsync(new { released = n });
});

app.Run();
```

---

## Testowanie

### Scenariusz A – Exhaustion puli
```powershell
Invoke-RestMethod -Method Post http://localhost:5000/leak | ConvertTo-Json

1..20 | ForEach-Object {
  Start-Job -ScriptBlock {
    try { Invoke-RestMethod http://localhost:5000/query }
    catch { $_.Exception.Message }
  }
}
Get-Job | Receive-Job
```

Sprzątanie:
```powershell
Invoke-RestMethod -Method Post http://localhost:5000/reset | ConvertTo-Json
```

### Scenariusz B – Starvation ThreadPool
```powershell
1..100 | ForEach-Object {
  Start-Job -ScriptBlock {
    try { Invoke-RestMethod http://localhost:5000/starve }
    catch { $_.Exception.Message }
  }
}
Get-Job | Receive-Job
```

---

## Weryfikacja po stronie SQL
```sql
SELECT * 
FROM sys.dm_exec_requests
WHERE session_id <> @@SPID;

SELECT s.session_id, s.login_name, s.status, c.connect_time
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE s.is_user_process = 1
ORDER BY c.connect_time DESC;
```

---

## Podsumowanie
- Timeouty mogą wystąpić **zanim SQL otrzyma jakiekolwiek zapytanie**.
- Główne przyczyny to wyczerpanie puli połączeń lub brak wolnych workerów w ThreadPool.
- Po stronie SQL nic się nie dzieje – problem leży w aplikacji.
- Max Pool Size=3 specjalnie wycięte, aby zasymulować problemy, domyś;na wartość to 100
