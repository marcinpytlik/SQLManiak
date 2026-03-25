namespace SqlStressLab.Core.Models;

public sealed class PerfCountersOptions
{
    public bool Enabled { get; set; } = false;

    public int SampleIntervalMs { get; set; } = 1000;

    public List<string> CounterPaths { get; set; } = new();
}