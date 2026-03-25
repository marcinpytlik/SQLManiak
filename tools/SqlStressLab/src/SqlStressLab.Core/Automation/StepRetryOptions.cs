namespace SqlStressLab.Core.Automation;

public sealed class StepRetryOptions
{
    public bool Enabled { get; set; } = true;
    public int MaxRetries { get; set; } = 1;
    public int DelayMs { get; set; } = 1000;
    public List<string> RetryableStepTypes { get; set; } = new();
}