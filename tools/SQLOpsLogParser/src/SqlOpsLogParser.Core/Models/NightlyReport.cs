namespace SqlOpsLogParser.Core.Models;

public sealed class NightlyReport
{
    public string ProfileName { get; set; } = string.Empty;
    public ReportSummary Summary { get; set; } = new();

    public List<TimelineEvent> TimelineEvents { get; set; } = [];
    public List<JobExecution> FailedJobs { get; set; } = [];
    public List<JobStepExecution> FailedSteps { get; set; } = [];
}