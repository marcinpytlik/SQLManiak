using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace StockFlow.LeastPrivilege.ConsoleDemo.Data;

public class StockFlowDbContextFactory : IDesignTimeDbContextFactory<StockFlowDbContext>
{
    public StockFlowDbContext CreateDbContext(string[] args)
    {
        var configuration = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: false)
            .Build();

        var connectionString = configuration.GetConnectionString("StockFlowDb")
            ?? throw new InvalidOperationException("Brak connection stringa 'StockFlowDb'.");

        var optionsBuilder = new DbContextOptionsBuilder<StockFlowDbContext>();
        optionsBuilder.UseSqlServer(connectionString, sql =>
        {
            sql.MigrationsHistoryTable("__EFMigrationsHistory", "app");
            sql.EnableRetryOnFailure(3);
            sql.CommandTimeout(30);
        });

        return new StockFlowDbContext(optionsBuilder.Options);
    }
}
