namespace SqlStressLab.Core.Hooks;

public sealed class HookExecutionContext
{
    public string? RunId { get; set; }
    public string? ProfileName { get; set; }
    public string? ScenarioName { get; set; }
    public string? OutputDirectory { get; set; }
}