using System.Text;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Reporting;

public sealed class CsvReportWriter : IReportWriter
{
    public ReportFormat Format => ReportFormat.Csv;

    public async Task WriteAsync<T>(
        IReadOnlyList<T> data,
        ReportRequest request,
        CancellationToken cancellationToken = default)
    {
        var sb = new StringBuilder();
        var properties = typeof(T).GetProperties();

        sb.AppendLine(string.Join(",", properties.Select(p => Escape(p.Name))));

        foreach (var row in data)
        {
            var values = properties
                .Select(p => Escape(p.GetValue(row)?.ToString() ?? string.Empty));

            sb.AppendLine(string.Join(",", values));
        }

        var directory = Path.GetDirectoryName(request.OutputPath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await File.WriteAllTextAsync(
            request.OutputPath,
            sb.ToString(),
            Encoding.UTF8,
            cancellationToken);
    }

    private static string Escape(string value)
    {
        var escaped = value.Replace("\"", "\"\"");
        return $"\"{escaped}\"";
    }
}