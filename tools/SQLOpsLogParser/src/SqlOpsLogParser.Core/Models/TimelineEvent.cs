using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Models;

public sealed class TimelineEvent
{
    public DateTime EventTime { get; set; }

    public TimelineSourceType Source { get; set; }

    public EventSeverity Severity { get; set; } = EventSeverity.Unknown;
    public EventCategory Category { get; set; } = EventCategory.General;

    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;

    public string? JobName { get; set; }
    public string? StepName { get; set; }

    public string? ProcessInfo { get; set; }
}