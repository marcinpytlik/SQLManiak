namespace SqlStressLab.Core.Logging;

public sealed class AppLogEntry
{
    public DateTime TimestampUtc { get; set; }
    public string Level { get; set; } = "Info";
    public string EventName { get; set; } = "";
    public string Message { get; set; } = "";
    public Dictionary<string, string>? Properties { get; set; }
}