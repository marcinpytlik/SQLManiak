namespace SqlOpsToolkit.Core.Models;

public sealed class SqlServerInstanceMetadata
{
    public string ProfileName { get; init; } = string.Empty;

    public string ServerName { get; init; } = string.Empty;
    public string MachineName { get; init; } = string.Empty;
    public string? InstanceName { get; init; }

    public string Edition { get; init; } = string.Empty;
    public string ProductVersion { get; init; } = string.Empty;
    public string ProductLevel { get; init; } = string.Empty;
    public string ProductUpdateLevel { get; init; } = string.Empty;
    public string ProductUpdateReference { get; init; } = string.Empty;

    public int? EngineEdition { get; init; }
    public int? MajorVersion { get; init; }

    public int? VersionMajor { get; init; }
    public int? VersionMinor { get; init; }
    public int? VersionBuild { get; init; }
    public int? VersionRevision { get; init; }

    public DateTime CollectedAtUtc { get; init; } = DateTime.UtcNow;
}