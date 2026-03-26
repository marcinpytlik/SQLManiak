namespace SqlOpsLogParser.Core.Models;

public sealed class ConnectionTestResult
{
    public bool Success { get; set; }
    public string ServerName { get; set; } = string.Empty;
    public string? ProductVersion { get; set; }
    public string? Edition { get; set; }
    public string? ErrorMessage { get; set; }
    public TimeSpan Duration { get; set; }
}