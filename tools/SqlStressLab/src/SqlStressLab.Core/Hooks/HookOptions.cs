namespace SqlStressLab.Core.Hooks;

public sealed class HookOptions
{
    public bool Enabled { get; set; } = false;
    public List<HookDefinition> Hooks { get; set; } = new();
}