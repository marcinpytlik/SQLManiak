namespace SqlStressLab.Core.Automation;

public sealed class ResumeOptions
{
    public bool Enabled { get; set; } = true;
    public bool SkipSucceededSteps { get; set; } = true;
    public bool RetryFailedSteps { get; set; } = true;
}