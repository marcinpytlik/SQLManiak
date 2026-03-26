namespace SqlOpsLogParser.Core.Models;

public sealed class SqlLogEntry
{
    public DateTime LogDate { get; set; }
    public string ProcessInfo { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
}