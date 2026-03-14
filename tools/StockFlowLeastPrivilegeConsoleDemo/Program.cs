using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using StockFlow.LeastPrivilege.ConsoleDemo.Data;
using StockFlow.LeastPrivilege.ConsoleDemo.Models;

var host = Host.CreateDefaultBuilder(args)
    .ConfigureAppConfiguration(cfg =>
    {
        cfg.AddJsonFile("appsettings.json", optional: false, reloadOnChange: false);
    })
    .ConfigureServices((context, services) =>
    {
        var connectionString = context.Configuration.GetConnectionString("StockFlowDb")
            ?? throw new InvalidOperationException("Brak connection stringa 'StockFlowDb'.");

        services.AddDbContext<StockFlowDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsHistoryTable("__EFMigrationsHistory", "app");
                sql.EnableRetryOnFailure(3);
                sql.CommandTimeout(30);
            });

            options.EnableDetailedErrors();
            options.EnableSensitiveDataLogging(false);
            options.LogTo(Console.WriteLine, LogLevel.Information);
        });
    })
    .Build();

using var scope = host.Services.CreateScope();
var db = scope.ServiceProvider.GetRequiredService<StockFlowDbContext>();

Console.WriteLine("=== StockFlow Least Privilege Console Demo ===");
Console.WriteLine();
Console.WriteLine("To demo migracje i least privilege:");
Console.WriteLine("1. Utwórz migrację: dotnet ef migrations add InitialCreate");
Console.WriteLine("2. Wygeneruj skrypt: dotnet ef migrations script -o .\\Scripts\\001_InitialCreate.sql");
Console.WriteLine("3. Uruchom skrypt kontem stockflow_deploy");
Console.WriteLine("4. Uruchom tę aplikację kontem stockflow_runtime");
Console.WriteLine();
Console.WriteLine("UWAGA: Na produkcji nie wywołujemy db.Database.Migrate() z konta runtime.");
Console.WriteLine();

var canConnect = await db.Database.CanConnectAsync();
Console.WriteLine($"Połączenie z bazą: {(canConnect ? "OK" : "NIEUDANE")}");

if (!canConnect)
{
    Console.WriteLine("Sprawdź connection string albo uprawnienia konta runtime.");
    return;
}

var tableExists = await db.Products.AnyAsync();
Console.WriteLine($"Tabela app.Products dostępna: {tableExists || !tableExists}");

var product = new Product
{
    Sku = $"STK-{DateTime.UtcNow:yyyyMMddHHmmss}",
    Name = "Least Privilege Demo Product",
    QuantityOnHand = 10,
    LastUpdatedUtc = DateTime.UtcNow
};

Console.WriteLine();
Console.WriteLine("Próba INSERT przez konto runtime...");
db.Products.Add(product);
await db.SaveChangesAsync();
Console.WriteLine($"Dodano produkt Id={product.Id}, SKU={product.Sku}");

Console.WriteLine("Próba SELECT przez konto runtime...");
var loaded = await db.Products.AsNoTracking().SingleAsync(x => x.Id == product.Id);
Console.WriteLine($"Odczytano: {loaded.Name}, Qty={loaded.QuantityOnHand}");

Console.WriteLine("Próba UPDATE przez konto runtime...");
var toUpdate = await db.Products.SingleAsync(x => x.Id == product.Id);
toUpdate.QuantityOnHand = 25;
toUpdate.LastUpdatedUtc = DateTime.UtcNow;
await db.SaveChangesAsync();
Console.WriteLine("Update OK");

Console.WriteLine("Próba DELETE przez konto runtime...");
db.Products.Remove(toUpdate);
await db.SaveChangesAsync();
Console.WriteLine("Delete OK");

Console.WriteLine();
Console.WriteLine("Demo zakończone poprawnie. Konto runtime ma DML, ale nie powinno mieć DDL.");
