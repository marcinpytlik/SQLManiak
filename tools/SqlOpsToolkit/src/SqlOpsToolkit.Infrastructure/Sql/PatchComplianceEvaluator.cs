using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Enums;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Sql;

public sealed class PatchComplianceEvaluator : IPatchComplianceEvaluator
{
    public PatchComplianceResult Evaluate(SqlServerInstanceMetadata metadata, PatchBaseline baseline)
    {
        ArgumentNullException.ThrowIfNull(metadata);
        ArgumentNullException.ThrowIfNull(baseline);

        var detectedParts = SqlVersionParser.Parse(metadata.ProductVersion);

        var entry = baseline.Entries.FirstOrDefault(x => x.MajorVersion == metadata.MajorVersion);

        if (entry is null)
        {
            return new PatchComplianceResult
            {
                ProfileName = metadata.ProfileName,
                ServerName = metadata.ServerName,
                DetectedVersion = metadata.ProductVersion,
                DetectedMajorVersion = metadata.MajorVersion,
                DetectedBuild = detectedParts.Build,
                Status = ComplianceStatus.Unsupported,
                Message = $"Brak wpisu baseline dla MajorVersion={metadata.MajorVersion}."
            };
        }

        if (!entry.Supported)
        {
            return new PatchComplianceResult
            {
                ProfileName = metadata.ProfileName,
                ServerName = metadata.ServerName,
                DetectedVersion = metadata.ProductVersion,
                DetectedMajorVersion = metadata.MajorVersion,
                DetectedBuild = detectedParts.Build,
                RecommendedBuild = entry.RecommendedBuild,
                RecommendedLabel = entry.RecommendedLabel,
                RecommendedReleased = entry.RecommendedReleased,
                ProductName = entry.ProductName,
                SupportState = entry.SupportState,
                Notes = entry.Notes,
                Status = ComplianceStatus.Unsupported,
                Message = "Wersja znajduje się poza wspieranym baseline."
            };
        }

        var comparison = SqlVersionComparer.Compare(metadata.ProductVersion, entry.RecommendedBuild);

        var status = comparison < 0
            ? ComplianceStatus.Outdated
            : ComplianceStatus.Compliant;

        var message = status switch
        {
            ComplianceStatus.Compliant => "Instancja spełnia wymagany baseline.",
            ComplianceStatus.Outdated => "Instancja jest poniżej rekomendowanego baseline.",
            _ => "Nieznany status."
        };

        return new PatchComplianceResult
        {
            ProfileName = metadata.ProfileName,
            ServerName = metadata.ServerName,
            DetectedVersion = metadata.ProductVersion,
            DetectedMajorVersion = metadata.MajorVersion,
            DetectedBuild = detectedParts.Build,
            RecommendedBuild = entry.RecommendedBuild,
            RecommendedLabel = entry.RecommendedLabel,
            RecommendedReleased = entry.RecommendedReleased,
            ProductName = entry.ProductName,
            SupportState = entry.SupportState,
            Notes = entry.Notes,
            Status = status,
            Message = message
        };
    }
}