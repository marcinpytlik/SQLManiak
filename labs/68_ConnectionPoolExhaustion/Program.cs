using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;

var mode = args.FirstOrDefault() ?? "baseline";
if (mode is not ("baseline" or "exhaustion" or "transaction"))
    throw new ArgumentException("Use baseline, exhaustion or transaction");
var password = Environment.GetEnvironmentVariable("LAB_PASSWORD") ?? throw new InvalidOperationException("Set LAB_PASSWORD");
var cs = new SqlConnectionStringBuilder { DataSource = "127.0.0.1,15468", InitialCatalog = "tempdb", UserID = "sa", Password = password, TrustServerCertificate = true, ApplicationName = "SQLManiak.Lab68", MaxPoolSize = 3, ConnectTimeout = 5, ConnectRetryCount = 0, Pooling = true }.ConnectionString;
var options = new DbContextOptionsBuilder<LabContext>().UseSqlServer(cs).Options;
Console.WriteLine($"PID={Environment.ProcessId}; SqlClient={typeof(SqlConnection).Assembly.GetName().Version}; mode={mode}");
async Task Probe(bool expectFailure = false)
{
    await using var db = new LabContext(options);
    var sw = Stopwatch.StartNew();
    try
    {
        var spid = await db.Database.SqlQueryRaw<int>("SELECT CAST(@@SPID AS int) AS Value").SingleAsync();
        Console.WriteLine($"{DateTime.UtcNow:O} SUCCESS SPID={spid} elapsed={sw.ElapsedMilliseconds}ms");
        if (expectFailure) throw new Exception("Expected pool exhaustion but probe succeeded");
    }
    catch (InvalidOperationException ex) when (expectFailure && ex.Message.Contains("pool", StringComparison.OrdinalIgnoreCase))
    { Console.WriteLine($"{DateTime.UtcNow:O} EXPECTED TIMEOUT elapsed={sw.ElapsedMilliseconds}ms: {ex.Message}"); }
}
if (mode == "baseline")
{
    for (int i = 0; i < 10; i++) await Probe();
    Console.WriteLine("Observe idle pooled session for 30 seconds");
    await Task.Delay(30000);
}
else if (mode == "exhaustion")
{
    var held = new List<LabContext>();
    try
    {
        for (int i = 0; i < 3; i++)
        {
            var db = new LabContext(options); held.Add(db);
            await db.Database.OpenConnectionAsync();
            Console.WriteLine($"Held SPID={await db.Database.SqlQueryRaw<int>("SELECT CAST(@@SPID AS int) AS Value").SingleAsync()}");
        }
        Console.WriteLine("Pool full; observe DMV/counters for 30 seconds");
        await Task.Delay(30000);
        await Probe(true);
        await Task.Delay(15000);
    }
    finally { foreach (var db in held) await db.DisposeAsync(); }
    await Probe();
}
else
{
    await using (var c = new SqlConnection(cs))
    {
        await c.OpenAsync();
        await using var cmd = c.CreateCommand();
        cmd.CommandText = "BEGIN TRANSACTION; SELECT @@SPID;";
        Console.WriteLine($"TSQL transaction SPID={await cmd.ExecuteScalarAsync()}");
    }
    Console.WriteLine("Disposed; observe transaction state for 30 seconds (result depends on provider)");
    await Task.Delay(30000);
    await Probe();
    await Task.Delay(15000);
}
SqlConnection.ClearAllPools();
sealed class LabContext(DbContextOptions<LabContext> options) : DbContext(options) { }
