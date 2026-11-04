using System.Collections.Concurrent;
using System.Diagnostics;
using System.Globalization;
using System.Reflection;
using Microsoft.Data.SqlClient;

// Switch MUST be set before SqlClient initializes. Compare V1/V2 in separate processes.
var options = Options.Parse(args);
AppContext.SetSwitch("Switch.Microsoft.Data.SqlClient.UseConnectionPoolV2", options.Pool == "v2");

var rawConnectionString = Environment.GetEnvironmentVariable("SQLCLIENT_BENCH_CS");
if (string.IsNullOrWhiteSpace(rawConnectionString))
{
    Console.Error.WriteLine("Set SQLCLIENT_BENCH_CS environment variable first (do not put secrets in command-line args).");
    return 2;
}

var builder = new SqlConnectionStringBuilder(rawConnectionString)
{
    Pooling = true,
    MinPoolSize = 0,
    MaxPoolSize = options.MaxPoolSize
};
var connectionString = builder.ConnectionString;
Directory.CreateDirectory(options.Output);
var outputFile = Path.Combine(options.Output, $"raw-{options.Pool}-{DateTime.UtcNow:yyyyMMdd-HHmmss}-{Environment.ProcessId}.csv");
var records = new List<Measurement>();

Console.WriteLine($"SQLManiak SqlClient Pool Benchmark | Pool {options.Pool.ToUpperInvariant()} | {Assembly.GetAssembly(typeof(SqlConnection))?.GetName().Version} | .NET {Environment.Version}");
Console.WriteLine($"Target: {builder.DataSource} / {builder.InitialCatalog}; max pool={builder.MaxPoolSize}; repetitions={options.Repetitions}");
Console.WriteLine("Connection string password is not printed. No SQL statements are executed.");

// Connectivity check is deliberately outside measured intervals.
try
{
    await using var check = new SqlConnection(connectionString);
    await check.OpenAsync();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Connectivity check failed: {ex.GetType().Name}: {ex.Message}");
    return 3;
}
SqlConnection.ClearAllPools();

foreach (var mode in options.Modes)
{
    foreach (var concurrency in options.Concurrencies)
    {
        for (var iteration = 1; iteration <= options.Repetitions; iteration++)
        {
            SqlConnection.ClearAllPools();
            var measurement = await RunRound(connectionString, options.Pool, mode, concurrency, iteration);
            records.Add(measurement);
            Console.WriteLine($"{mode,-5} N={concurrency,3} run={iteration,2}: open={measurement.TotalMs,9:F2} ms | setup={measurement.WorkerSetupMs:F2} ms | cpu={measurement.ProcessCpuMs:F0} ms | threads={measurement.PeakThreads} | failed={measurement.Failed}");
            if (measurement.Failed > 0) Console.Error.WriteLine($"Round failed: {measurement.ErrorSummary}");
        }
    }
}

await File.WriteAllLinesAsync(outputFile, new[]
{
    "pool,mode,concurrency,iteration,total_ms,open_p50_ms,open_p95_ms,open_max_ms,succeeded,failed,error,worker_setup_ms,process_cpu_ms,peak_threads,peak_threadpool_pending,min_threadpool_available,gc0,gc1,gc2,allocated_bytes"
}.Concat(records.Select(m => string.Join(",", m.Pool, m.Mode, m.Concurrency, m.Iteration,
    F(m.TotalMs), F(m.OpenP50Ms), F(m.OpenP95Ms), F(m.OpenMaxMs), m.Succeeded, m.Failed, Csv(m.ErrorSummary), F(m.WorkerSetupMs), F(m.ProcessCpuMs), m.PeakThreads, m.PeakThreadPoolPending, m.MinThreadPoolAvailable, m.Gc0, m.Gc1, m.Gc2, m.AllocatedBytes))));

Console.WriteLine("\nSUMMARY (success-only rounds):");
foreach (var g in records.GroupBy(x => (x.Mode, x.Concurrency)))
{
    var valid = g.Where(m => m.Failed == 0).Select(m => m.TotalMs).Order().ToArray();
    Console.WriteLine($"{g.Key.Mode,-5} N={g.Key.Concurrency,3}: valid={valid.Length}/{g.Count()}, mean={(valid.Length > 0 ? valid.Average() : double.NaN):F2} ms, median={Percentile(valid, .50):F2} ms, p95={Percentile(valid, .95):F2} ms");
}
Console.WriteLine($"Raw results: {outputFile}");
return records.Any(x => x.Failed > 0) ? 4 : 0;

static async Task<Measurement> RunRound(string cs, string pool, string mode, int n, int iteration)
{
    var ready = new CountdownEvent(n);
    var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
    var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
    var openings = new TaskCompletionSource<OpenOutcome>[n];
    var workers = new Task[n];
    using var process = Process.GetCurrentProcess();
    var cpuBefore = process.TotalProcessorTime;
    var gc0Before = GC.CollectionCount(0);
    var gc1Before = GC.CollectionCount(1);
    var gc2Before = GC.CollectionCount(2);
    var allocBefore = GC.GetTotalAllocatedBytes(precise: false);
    var prepWatch = Stopwatch.StartNew();

    for (var i = 0; i < n; i++)
    {
        var opened = new TaskCompletionSource<OpenOutcome>(TaskCreationOptions.RunContinuationsAsynchronously);
        openings[i] = opened;
        if (mode == "async")
            workers[i] = AsyncWorker(cs, ready, start.Task, release.Task, opened);
        else
            workers[i] = Task.Factory.StartNew(() => SyncWorker(cs, ready, start.Task, release.Task, opened),
                CancellationToken.None, TaskCreationOptions.LongRunning, TaskScheduler.Default);
    }

    if (!ready.Wait(TimeSpan.FromSeconds(45)))
    {
        start.TrySetResult();
        release.TrySetResult();
        throw new TimeoutException($"Only {n - ready.CurrentCount}/{n} workers ready after 45s");
    }
    prepWatch.Stop();
    var setupMs = prepWatch.Elapsed.TotalMilliseconds;

    var peakThreads = process.Threads.Count;
    long peakPending = ThreadPool.PendingWorkItemCount;
    ThreadPool.GetAvailableThreads(out var minAvailableWorker, out _);
    using var stopSample = new ManualResetEventSlim(false);
    var sampler = new Thread(() =>
    {
        while (!stopSample.IsSet)
        {
            try
            {
                peakThreads = Math.Max(peakThreads, process.Threads.Count);
                peakPending = Math.Max(peakPending, ThreadPool.PendingWorkItemCount);
                ThreadPool.GetAvailableThreads(out var currentAvailable, out _);
                minAvailableWorker = Math.Min(minAvailableWorker, currentAvailable);
            }
            catch (InvalidOperationException) { break; }
            Thread.Sleep(5);
        }
    }) { IsBackground = true, Name = "SQLManiak-benchmark-sampler" };
    sampler.Start();

    var watch = Stopwatch.StartNew();
    start.SetResult();
    OpenOutcome[] outcomes;
    double completionMs;
    try
    {
        outcomes = await Task.WhenAll(openings.Select(o => o.Task));
        watch.Stop();
        completionMs = watch.Elapsed.TotalMilliseconds;
    }
    finally
    {
        stopSample.Set();
        sampler.Join();
        release.TrySetResult();
        await Task.WhenAll(workers);
    }

    var cpuMs = (process.TotalProcessorTime - cpuBefore).TotalMilliseconds;
    var successful = outcomes.Where(o => o.Error is null).Select(o => o.OpenMs).Order().ToArray();
    var errors = outcomes.Where(o => o.Error is not null).Select(o => o.Error!).Distinct().Take(2);
    return new Measurement(pool, mode, n, iteration, completionMs,
        Percentile(successful, .50), Percentile(successful, .95),
        successful.Length > 0 ? successful[^1] : double.NaN,
        successful.Length, n - successful.Length, string.Join(" | ", errors),
        setupMs, cpuMs, peakThreads, peakPending, minAvailableWorker,
        GC.CollectionCount(0) - gc0Before,
        GC.CollectionCount(1) - gc1Before,
        GC.CollectionCount(2) - gc2Before,
        GC.GetTotalAllocatedBytes(precise: false) - allocBefore);
}

static async Task AsyncWorker(string cs, CountdownEvent ready, Task start, Task release, TaskCompletionSource<OpenOutcome> result)
{
    ready.Signal();
    await start;
    var watch = Stopwatch.StartNew();
    try
    {
        await using var conn = new SqlConnection(cs);
        await conn.OpenAsync();
        watch.Stop();
        result.TrySetResult(new OpenOutcome(watch.Elapsed.TotalMilliseconds, null));
        await release;
    }
    catch (Exception ex)
    {
        result.TrySetResult(new OpenOutcome(watch.Elapsed.TotalMilliseconds, $"{ex.GetType().Name}: {ex.Message}"));
    }
}

static void SyncWorker(string cs, CountdownEvent ready, Task start, Task release, TaskCompletionSource<OpenOutcome> result)
{
    ready.Signal();
    start.GetAwaiter().GetResult();
    var watch = Stopwatch.StartNew();
    try
    {
        using var conn = new SqlConnection(cs);
        conn.Open();
        watch.Stop();
        result.TrySetResult(new OpenOutcome(watch.Elapsed.TotalMilliseconds, null));
        release.GetAwaiter().GetResult();
    }
    catch (Exception ex)
    {
        result.TrySetResult(new OpenOutcome(watch.Elapsed.TotalMilliseconds, $"{ex.GetType().Name}: {ex.Message}"));
    }
}

static double Percentile(double[] sorted, double fraction)
{
    if (sorted.Length == 0) return double.NaN;
    var pos = (sorted.Length - 1) * fraction;
    var lower = (int)Math.Floor(pos);
    var upper = (int)Math.Ceiling(pos);
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (pos - lower);
}
static string F(double d) => d.ToString("F3", CultureInfo.InvariantCulture);
static string Csv(string text) => $"\"{text.Replace("\"", "\"\"")}\"";

record OpenOutcome(double OpenMs, string? Error);
record Measurement(string Pool, string Mode, int Concurrency, int Iteration, double TotalMs,
    double OpenP50Ms, double OpenP95Ms, double OpenMaxMs, int Succeeded, int Failed, string ErrorSummary,
    double WorkerSetupMs, double ProcessCpuMs, int PeakThreads, long PeakThreadPoolPending,
    int MinThreadPoolAvailable, int Gc0, int Gc1, int Gc2, long AllocatedBytes);

sealed record Options(string Pool, string[] Modes, int[] Concurrencies, int Repetitions, int MaxPoolSize, string Output)
{
    public static Options Parse(string[] args)
    {
        var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < args.Length; i++)
        {
            if (!args[i].StartsWith("--") || i + 1 == args.Length) throw new ArgumentException("Arguments must be --name value pairs.");
            dict[args[i][2..]] = args[++i];
        }
        var pool = dict.GetValueOrDefault("pool", "v1").ToLowerInvariant();
        if (pool is not ("v1" or "v2")) throw new ArgumentException("--pool v1|v2");
        var modes = dict.GetValueOrDefault("mode", "both").ToLowerInvariant() switch
        {
            "both" => new[] { "async", "sync" },
            "async" => new[] { "async" },
            "sync" => new[] { "sync" },
            _ => throw new ArgumentException("--mode both|async|sync")
        };
        var levels = dict.GetValueOrDefault("concurrency", "10,25,50,100").Split(',').Select(int.Parse).ToArray();
        int repeats = int.Parse(dict.GetValueOrDefault("repetitions", "5"));
        int maxPool = int.Parse(dict.GetValueOrDefault("max-pool", "200"));
        if (repeats < 1 || repeats > 100 || levels.Length == 0 || levels.Any(v => v < 1 || v > 1000) || maxPool < levels.Max())
            throw new ArgumentException("Require repetitions 1..100 and max-pool >= concurrency (concurrency <= 1000).");
        return new Options(pool, modes, levels, repeats, maxPool, dict.GetValueOrDefault("output", "results"));
    }
}