namespace SqlStressLab.Core.Cli;

public sealed class CommandContext
{
    public string WorkingDirectory { get; set; } = Directory.GetCurrentDirectory();
    public CancellationToken CancellationToken { get; set; }
}