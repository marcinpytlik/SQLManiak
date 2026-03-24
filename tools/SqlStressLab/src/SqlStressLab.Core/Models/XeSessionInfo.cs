namespace SqlStressLab.Core.Models;

public sealed class XeSessionInfo
{
    public string SessionName { get; set; } = "";
    public bool Exists { get; set; }
    public bool IsRunning { get; set; }
    public string? TargetType { get; set; }
    public string? TargetFile { get; set; }
    public DateTime CollectedAtUtc { get; set; }
}