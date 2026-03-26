using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Models;

public sealed class SqlLogEntry
{
    public DateTime LogDate { get; set; }
    public string ProcessInfo { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;

    public EventSeverity Severity { get; set; } = EventSeverity.Unknown;
    public EventCategory Category { get; set; } = EventCategory.General;
}