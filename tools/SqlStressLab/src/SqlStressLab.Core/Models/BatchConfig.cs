namespace SqlStressLab.Core.Models;

public sealed class BatchConfig
{
    public bool Enabled { get; set; } = false;
    public List<string> ProfileFiles { get; set; } = new();
}