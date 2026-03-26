namespace SqlOpsLogParser.Core.Enums;

public enum JobExecutionStatus
{
    Unknown = 0,
    Succeeded = 1,
    Failed = 2,
    Retry = 3,
    Cancelled = 4,
    InProgress = 5
}