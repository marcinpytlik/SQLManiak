namespace StockFlow.LeastPrivilege.ConsoleDemo.Models;

public class Product
{
    public int Id { get; set; }
    public string Sku { get; set; } = null!;
    public string Name { get; set; } = null!;
    public int QuantityOnHand { get; set; }
    public DateTime LastUpdatedUtc { get; set; }
}
