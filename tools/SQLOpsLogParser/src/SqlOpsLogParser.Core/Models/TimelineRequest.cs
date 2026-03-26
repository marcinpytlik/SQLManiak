using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Models;

public sealed class TimelineRequest
{
    public required ServerProfile Profile { get; set; }

    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
    public int? Hours { get; set; }

    public TimelineSourceType? SourceFilter { get; set; }
    public bool OnlyErrors { get; set; }

    public string? ContainsText { get; set; }
    public int? Top { get; set; }
}