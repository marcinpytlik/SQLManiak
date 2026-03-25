namespace SqlStressLab.Core.Models;

public sealed class RunStateInfo
{
    public string RunId { get; set; } = "";
    public string Status { get; set; } = "Created"; // Created / Running / Finished / Failed / Cancelled
    public DateTime UpdatedAtUtc { get; set; }
    public string? Message { get; set; }
}