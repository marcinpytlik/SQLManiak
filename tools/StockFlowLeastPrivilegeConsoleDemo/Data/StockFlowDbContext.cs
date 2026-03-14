using Microsoft.EntityFrameworkCore;
using StockFlow.LeastPrivilege.ConsoleDemo.Models;

namespace StockFlow.LeastPrivilege.ConsoleDemo.Data;

public class StockFlowDbContext : DbContext
{
    public StockFlowDbContext(DbContextOptions<StockFlowDbContext> options) : base(options)
    {
    }

    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("app");

        modelBuilder.Entity<Product>(e =>
        {
            e.ToTable("Products");
            e.HasKey(x => x.Id);

            e.Property(x => x.Sku)
                .HasMaxLength(50)
                .IsRequired();

            e.Property(x => x.Name)
                .HasMaxLength(200)
                .IsRequired();

            e.Property(x => x.LastUpdatedUtc)
                .HasColumnType("datetime2");

            e.HasIndex(x => x.Sku)
                .IsUnique();
        });
    }
}
