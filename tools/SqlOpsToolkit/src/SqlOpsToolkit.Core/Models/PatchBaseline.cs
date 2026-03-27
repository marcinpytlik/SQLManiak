namespace SqlOpsToolkit.Core.Models;

public sealed class PatchBaseline
{
    public IReadOnlyList<PatchBaselineEntry> Entries { get; init; } = Array.Empty<PatchBaselineEntry>();
}