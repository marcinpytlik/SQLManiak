using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IReportWriter
{
    ReportFormat Format { get; }

    Task WriteAsync<T>(
        IReadOnlyList<T> data,
        ReportRequest request,
        CancellationToken cancellationToken = default);
}