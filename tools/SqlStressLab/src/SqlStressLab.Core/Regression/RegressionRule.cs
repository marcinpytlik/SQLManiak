namespace SqlStressLab.Core.Regression;

public sealed class RegressionRule
{
    public string MetricName { get; set; } = ""; // AvgDurationMs / P95DurationMs / ThroughputPerSecond / ErrorCount
    public string Operator { get; set; } = "";   // IncreasePercent / DecreasePercent / GreaterThan / GreaterThanZero
    public double Threshold { get; set; }
    public string Severity { get; set; } = "Warn"; // Warn / Fail
}