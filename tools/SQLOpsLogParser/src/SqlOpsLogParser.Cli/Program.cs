using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;
using SqlOpsLogParser.Cli;
using SqlOpsLogParser.Cli.Composition;

Directory.CreateDirectory("logs");
Directory.CreateDirectory("profiles");
Directory.CreateDirectory("reports");

var builder = Host.CreateApplicationBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false)
    .AddJsonFile(Path.Combine("profiles", "profiles.json"), optional: true, reloadOnChange: false);

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.File(
        path: Path.Combine("logs", "sqlopslogparser-.log"),
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 14,
        shared: true)
    .CreateLogger();

builder.Services.AddSerilog();
builder.Services.AddApplicationServices(builder.Configuration);

using var host = builder.Build();

try
{
    Log.Information("Application starting");
    var app = host.Services.GetRequiredService<CliApplication>();
    return await app.RunAsync(args);
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
    Console.Error.WriteLine($"FATAL: {ex.Message}");
    Console.Error.WriteLine(ex.ToString());
    return 1;

   // Log.Fatal(ex, "Application terminated unexpectedly");
   // return 1;
}
finally
{
    Log.Information("Application stopping");
    await Log.CloseAndFlushAsync();
}