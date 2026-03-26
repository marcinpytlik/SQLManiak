using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Models;

public sealed class ErrorLogReadRequest
{
    public required ServerProfile Profile { get; set; }
    public int LogNumber { get; set; } = 0;
    public string? ContainsText { get; set; }
    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
    public int? Top { get; set; }

    public EventSeverity? SeverityFilter { get; set; }
    public EventCategory? CategoryFilter { get; set; }
}