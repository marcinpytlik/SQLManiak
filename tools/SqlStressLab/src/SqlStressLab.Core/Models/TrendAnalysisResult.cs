namespace SqlStressLab.Core.Models;

public sealed class TrendAnalysisResult
{
    public string ProfileName { get; set; } = "";
    public int RequestedTop { get; set; }
    public List<TrendPoint> Points { get; set; } = new();

    public string AvgDurationTrendDirection { get; set; } = "Stable";
    public string P95DurationTrendDirection { get; set; } = "Stable";
    public string ThroughputTrendDirection { get; set; } = "Stable";
    public string ErrorTrendDirection { get; set; } = "Stable";

    public string SummaryVerdict { get; set; } = "Neutral";
}