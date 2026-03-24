namespace SqlStressLab.Core.Models;

public sealed class XeCaptureOptions
{
    public bool Enabled { get; set; } = false;
    public string? SessionName { get; set; }
}