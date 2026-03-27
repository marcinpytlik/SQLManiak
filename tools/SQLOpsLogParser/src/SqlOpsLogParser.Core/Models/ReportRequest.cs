using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Models;

public sealed class ReportRequest
{
    public required string OutputPath { get; set; }
    public required ReportFormat Format { get; set; }
    public required string Title { get; set; }
    public Dictionary<string, string> Metadata { get; set; } = [];
}