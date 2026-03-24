namespace SqlStressLab.Core.Models;

public sealed class PerfCounterOptions
{
    public bool Enabled { get; set; } = false;
    public int SamplingIntervalMs { get; set; } = 1000;
    public List<string> CounterPaths { get; set; } = new();
}