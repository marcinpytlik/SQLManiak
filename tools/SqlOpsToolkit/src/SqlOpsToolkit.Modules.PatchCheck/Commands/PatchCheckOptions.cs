namespace SqlOpsToolkit.Modules.PatchCheck.Commands;

public sealed class PatchCheckOptions
{
    public string ProfilesFile { get; init; } = @".\profiles\sample-profiles.json";
    public string? ProfileName { get; init; }
    public string? Tag { get; init; }
}