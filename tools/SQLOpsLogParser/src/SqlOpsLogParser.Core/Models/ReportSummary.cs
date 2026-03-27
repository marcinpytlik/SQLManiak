namespace SqlOpsLogParser.Core.Models;

public sealed class ReportSummary
{
    public int TotalTimelineEvents { get; set; }
    public int ErrorEvents { get; set; }
    public int CriticalEvents { get; set; }

    public int FailedJobs { get; set; }
    public int FailedSteps { get; set; }

    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
}