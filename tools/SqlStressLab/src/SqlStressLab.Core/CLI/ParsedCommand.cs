namespace SqlStressLab.Core.Cli;

public sealed class ParsedCommand
{
    public string CommandName { get; set; } = "";
    public Dictionary<string, string> Options { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public List<string> Flags { get; set; } = new();
}