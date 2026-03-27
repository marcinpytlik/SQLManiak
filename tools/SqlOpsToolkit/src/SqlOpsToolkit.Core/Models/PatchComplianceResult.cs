using SqlOpsToolkit.Core.Enums;

namespace SqlOpsToolkit.Core.Models;

public sealed class PatchComplianceResult
{
    public string ProfileName { get; init; } = string.Empty;
    public string ServerName { get; init; } = string.Empty;

    public string DetectedVersion { get; init; } = string.Empty;
    public int? DetectedMajorVersion { get; init; }
    public int? DetectedBuild { get; init; }

    public string RecommendedBuild { get; init; } = string.Empty;
    public string RecommendedLabel { get; init; } = string.Empty;
    public string RecommendedReleased { get; init; } = string.Empty;

    public string ProductName { get; init; } = string.Empty;
    public string SupportState { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;

    public ComplianceStatus Status { get; init; } = ComplianceStatus.Unknown;
    public string Message { get; init; } = string.Empty;

    public DateTime EvaluatedAtUtc { get; init; } = DateTime.UtcNow;
}