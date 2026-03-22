namespace SqlStressLab.Core.Models;

public sealed class ExecutionConfig
{
    public string CommandText { get; set; } = "";
    public string CommandType { get; set; } = "Text";
    public string ExecutionMode { get; set; } = "NonQuery";
    public int Workers { get; set; } = 5;
    public int IterationsPerWorker { get; set; } = 100;
    public int CommandTimeoutSeconds { get; set; } = 30;
    public bool UseTransaction { get; set; }
    public bool WarmupEnabled { get; set; } = false;
    public int WarmupIterationsPerWorker { get; set; } = 0;
    public string? SessionSettingsFile { get; set; }
    public int? DelayBetweenIterationsMs { get; set; }
}