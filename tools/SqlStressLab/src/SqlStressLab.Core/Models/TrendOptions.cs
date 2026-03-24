namespace SqlStressLab.Core.Models;

public sealed class TrendOptions
{
    public bool Enabled { get; set; } = false;
    public int Top { get; set; } = 10;
}