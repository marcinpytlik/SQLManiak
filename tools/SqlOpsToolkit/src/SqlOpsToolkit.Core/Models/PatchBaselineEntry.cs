namespace SqlOpsToolkit.Core.Models;

public sealed class PatchBaselineEntry
{
    public int MajorVersion { get; init; }
    public string ProductName { get; init; } = string.Empty;
    public bool Supported { get; init; }

    public string RecommendedBuild { get; init; } = string.Empty;
    public string RecommendedLabel { get; init; } = string.Empty;
    public string RecommendedReleased { get; init; } = string.Empty;

    public string MinimumSupportedBuild { get; init; } = string.Empty;
    public string SupportState { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;
}