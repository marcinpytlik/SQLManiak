using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Models;

public sealed class JobExecution
{
    public Guid JobId { get; set; }
    public string JobName { get; set; } = string.Empty;

    public DateTime? RunDateTime { get; set; }
    public int RunDurationSeconds { get; set; }

    public JobExecutionStatus Status { get; set; } = JobExecutionStatus.Unknown;

    public int SqlMessageId { get; set; }
    public int SqlSeverity { get; set; }
    public string Message { get; set; } = string.Empty;
}