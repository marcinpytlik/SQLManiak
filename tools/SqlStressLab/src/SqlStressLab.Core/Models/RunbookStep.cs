namespace SqlStressLab.Core.Models;

public sealed class RunbookStep
{
    public string Name { get; set; } = "";
    public string Command { get; set; } = "run";
    public string ProfilePath { get; set; } = "";
    public bool ContinueOnError { get; set; } = false;
}