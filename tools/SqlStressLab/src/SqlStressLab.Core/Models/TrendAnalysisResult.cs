namespace SqlStressLab.Core.Models;

public sealed class TrendAnalysisResult
{
    public string ProfileName { get; set; } = "";
    public int RequestedTop { get; set; }

    public List<TrendPoint> Points { get; set; } = new();

    public string AvgDurationTrendDirection { get; set; } = "";
    public string P95DurationTrendDirection { get; set; } = "";
    public string ThroughputTrendDirection { get; set; } = "";
    public string ErrorTrendDirection { get; set; } = "";
public string SummaryText { get; set; } = "";
    public string SummaryVerdict { get; set; } = "";
}