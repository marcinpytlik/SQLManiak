namespace SqlStressLab.Core.Models;

public sealed class ExecutionSample
{
    public int WorkerId { get; set; }
    public int Iteration { get; set; }
    public DateTime StartedAtUtc { get; set; }
    public long DurationMs { get; set; }
    public bool Success { get; set; }
    public int RetryAttempt { get; set; }
    public string? ErrorCategory { get; set; }
    public string? ErrorMessage { get; set; }
    public int? SqlErrorNumber { get; set; }
    public string? ScalarValue { get; set; }
    public int? ReaderRowCount { get; set; }
    public string? ReaderPreviewJson { get; set; }

    public int? Spid { get; set; }
    public string? HostName { get; set; }
    public string? AppName { get; set; }
    public string? LoginName { get; set; }
    public string? DatabaseName { get; set; }
}