namespace SqlStressLab.Core.Models;

public sealed class PerfCounterSample
{
    public string RunId { get; set; } = "";
    public DateTime CollectedAtUtc { get; set; }
    public string CounterPath { get; set; } = "";
    public double Value { get; set; }
}