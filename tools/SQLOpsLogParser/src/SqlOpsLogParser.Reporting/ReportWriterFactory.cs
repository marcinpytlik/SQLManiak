using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;

namespace SqlOpsLogParser.Reporting;

public sealed class ReportWriterFactory(IEnumerable<IReportWriter> writers) : IReportWriterFactory
{
    private readonly IReadOnlyList<IReportWriter> _writers = writers.ToList();

    public IReportWriter GetWriter(ReportFormat format)
    {
        var writer = _writers.FirstOrDefault(x => x.Format == format);

        if (writer is null)
        {
            throw new InvalidOperationException($"No writer registered for format: {format}");
        }

        return writer;
    }
}