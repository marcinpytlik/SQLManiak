using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Reporting;

public sealed class ReportService(IReportWriterFactory writerFactory) : IReportService
{
    public async Task WriteAsync<T>(
        IReadOnlyList<T> data,
        ReportRequest request,
        CancellationToken cancellationToken = default)
    {
        var writer = writerFactory.GetWriter(request.Format);
        await writer.WriteAsync(data, request, cancellationToken);
    }
}