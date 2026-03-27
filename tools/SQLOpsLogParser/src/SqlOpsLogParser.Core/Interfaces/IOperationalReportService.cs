using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IOperationalReportService
{
    Task<NightlyReport> BuildNightlyReportAsync(
        ServerProfile profile,
        int hours,
        CancellationToken cancellationToken = default);

    Task<IncidentReport> BuildIncidentReportAsync(
        ServerProfile profile,
        DateTime? from,
        DateTime? to,
        int? hours,
        string? containsText,
        CancellationToken cancellationToken = default);
}