namespace SqlStressLab.Core.Models;

public sealed class RetryOptions
{
    public bool Enabled { get; set; } = false;
    public int MaxRetries { get; set; } = 0;
    public int DelayMs { get; set; } = 250;
    public List<int> RetryableSqlErrorNumbers { get; set; } = new() { -2, 1205 };
}