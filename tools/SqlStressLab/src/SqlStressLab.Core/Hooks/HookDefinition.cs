namespace SqlStressLab.Core.Hooks;

public sealed class HookDefinition
{
    public string Name { get; set; } = "";
    public string Trigger { get; set; } = ""; // BeforeRun / AfterRun / OnError
    public string Type { get; set; } = "PowerShell"; // PowerShell / Cmd / SqlScript
    public string CommandOrFile { get; set; } = "";
    public bool ContinueOnError { get; set; } = true;
}