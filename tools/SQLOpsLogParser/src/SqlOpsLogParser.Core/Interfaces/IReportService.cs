using SqlOpsLogParser.Core.Models;
//using SqlOpsLogParser.Core.Interfaces;
namespace SqlOpsLogParser.Core.Interfaces;

public interface IReportService
{
    Task WriteAsync<T>(
        IReadOnlyList<T> data,
        ReportRequest request,
        CancellationToken cancellationToken = default);
}