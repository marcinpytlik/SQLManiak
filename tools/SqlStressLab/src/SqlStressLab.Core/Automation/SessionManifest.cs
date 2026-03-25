namespace SqlStressLab.Core.Automation;

public sealed class SessionManifest
{
    public string SessionId { get; set; } = "";
    public string ExecutionType { get; set; } = "";
    public string Name { get; set; } = "";
    public DateTime CreatedAtUtc { get; set; }
    public List<string> RunIds { get; set; } = new();
    public string FinalVerdict { get; set; } = "Unknown";
}