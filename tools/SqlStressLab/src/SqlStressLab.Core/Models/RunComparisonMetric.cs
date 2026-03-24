namespace SqlStressLab.Core.Models;

public sealed class RunComparisonMetric
{
    public string MetricName { get; set; } = "";
    public string Unit { get; set; } = "";
    public double BaselineValue { get; set; }
    public double CurrentValue { get; set; }
    public double DeltaValue { get; set; }
    public double DeltaPercent { get; set; }
}