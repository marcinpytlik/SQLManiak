using SqlOpsLogParser.Core.Enums;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IReportWriterFactory
{
    IReportWriter GetWriter(ReportFormat format);
}