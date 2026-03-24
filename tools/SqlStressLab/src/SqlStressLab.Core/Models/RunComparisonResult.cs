namespace SqlStressLab.Core.Models;

public sealed class RunComparisonResult
{
    public string CurrentRunId { get; set; } = "";
    public string BaselineRunId { get; set; } = "";
    public List<RunComparisonMetric> Metrics { get; set; } = new();
    public string SummaryText { get; set; } = "";
}