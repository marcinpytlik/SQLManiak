using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;

var mode = args.FirstOrDefault() ?? "baseline";
if (mode is not ("baseline" or "exhaustion" or "transaction" or "blocking" or "rollback"))
    throw new ArgumentException("Use baseline, exhaustion, transaction, blocking or rollback");
var password = Environment.GetEnvironmentVariable("LAB_PASSWORD") ?? throw new InvalidOperationException("Set LAB_PASSWORD");
var cs = new SqlConnectionStringBuilder { DataSource = "127.0.0.1,15468", InitialCatalog = "tempdb", UserID = "sa", Password = password, TrustServerCertificate = true, ApplicationName = "SQLManiak.Lab68", MaxPoolSize = 3, ConnectTimeout = 5, ConnectRetryCount = 0, Pooling = true }.ConnectionString;
var options = new DbContextOptionsBuilder<LabContext>().UseSqlServer(cs).Options;
Console.WriteLine($"PID={Environment.ProcessId}; SqlClient={typeof(SqlConnection).Assembly.GetName().Version}; mode={mode}");
async Task Probe(bool expectFailure = false)
{
    await using var db = new LabContext(options);
    var sw = Stopwatch.StartNew();
    if (expectFailure)
    {
        // Only classify an exception from opening the fourth connection
        // in the controlled saturation experiment, not from executing SQL.
        try
        {
            await db.Database.OpenConnectionAsync();
        }
        catch (InvalidOperationException ex) when (sw.Elapsed >= TimeSpan.FromSeconds(4))
        {
            Console.WriteLine($"{DateTime.UtcNow:O} EXPECTED TIMEOUT elapsed={sw.ElapsedMilliseconds}ms: {ex.Message}");
            return;
        }
        throw new Exception("Expected pool exhaustion but opening the fourth connection succeeded");
    }
    var spid = await db.Database.SqlQueryRaw<int>("SELECT CAST(@@SPID AS int) AS Value").SingleAsync();
    Console.WriteLine($"{DateTime.UtcNow:O} SUCCESS SPID={spid} elapsed={sw.ElapsedMilliseconds}ms");
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
    Console.WriteLine($"{DateTime.UtcNow:O} Held connections released; recovery probe");
    await Probe();
    await Task.Delay(10000);
}
else if (mode == "transaction")
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
else
{
    // Private disposable table; independent observer pool and same owner pool.
    var table = "dbo.Lab68_" + Guid.NewGuid().ToString("N");
    var observerCs = new SqlConnectionStringBuilder(cs) { Pooling = false, ApplicationName = "SQLManiak.Lab68.Observer" }.ConnectionString;
    await using var observer = new SqlConnection(observerCs);
    await observer.OpenAsync();
    async Task<object?> Execute(SqlConnection conn, string sql, SqlTransaction? tx = null)
    {
        await using var cmd = conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = sql;
        cmd.CommandTimeout = 45;
        return await cmd.ExecuteScalarAsync();
    }
    await Execute(observer, $"CREATE TABLE {table} (Id int PRIMARY KEY, V int NOT NULL); INSERT {table} VALUES (1, 0);");
    try
    {
        int ownerSpid;
        await using (var owner = new SqlConnection(cs))
        {
            await owner.OpenAsync();
            ownerSpid = Convert.ToInt32(await Execute(owner, "SELECT @@SPID"));
            if (mode == "blocking")
                await Execute(owner, $"BEGIN TRANSACTION; UPDATE {table} SET V = 1 WHERE Id = 1;");
            else
            {
                await using var tx = (SqlTransaction)await owner.BeginTransactionAsync();
                await Execute(owner, $"UPDATE {table} SET V = 1 WHERE Id = 1;", tx);
                await tx.RollbackAsync();
                Console.WriteLine($"{DateTime.UtcNow:O} EXPLICIT ROLLBACK");
            }
        }
        Console.WriteLine($"{DateTime.UtcNow:O} OWNER DISPOSED SPID={ownerSpid}");
        Console.WriteLine($"OBSERVER SPID={await Execute(observer, "SELECT @@SPID")}");
        // Force locking read regardless of database RCSI configuration.
        var sw = Stopwatch.StartNew();
        async Task<(int Value, long ElapsedMs)> MeasureObserver()
        {
            var timer = Stopwatch.StartNew();
            var value = Convert.ToInt32(await Execute(observer, $"SELECT V FROM {table} WITH (READCOMMITTEDLOCK) WHERE Id = 1"));
            return (value, timer.ElapsedMilliseconds);
        }
        var pending = MeasureObserver();
        await Task.Delay(TimeSpan.FromSeconds(10));
        bool blocked = !pending.IsCompleted;
        Console.WriteLine($"{DateTime.UtcNow:O} OBSERVER PENDING AFTER 10s={blocked}");
        await using (var owner = new SqlConnection(cs))
        {
            await owner.OpenAsync();
            await using var cmd = owner.CreateCommand();
            cmd.CommandText = "SELECT @@SPID, @@TRANCOUNT";
            await using var reader = await cmd.ExecuteReaderAsync();
            await reader.ReadAsync();
            Console.WriteLine($"{DateTime.UtcNow:O} REUSE SPID={Convert.ToInt32(reader.GetValue(0))} TRANCOUNT={reader.GetInt32(1)}");
        }
        var (value, selectElapsedMs) = await pending;
        Console.WriteLine($"{DateTime.UtcNow:O} OBSERVER VALUE={value} selectElapsed={selectElapsedMs}ms observationElapsed={sw.ElapsedMilliseconds}ms");
        if (blocked != (mode == "blocking") || value != 0)
            throw new Exception("Unexpected experiment outcome; inspect DMV and provider behavior");
        await Task.Delay(5000);
    }
    finally
    {
        // Release any remaining owner session before dropping the lab table.
        SqlConnection.ClearAllPools();
        await Execute(observer, $"DROP TABLE IF EXISTS {table}");
    }
}
SqlConnection.ClearAllPools();
sealed class LabContext(DbContextOptions<LabContext> options) : DbContext(options) { }
