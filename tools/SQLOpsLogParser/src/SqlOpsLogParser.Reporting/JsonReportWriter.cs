using System.Text.Json;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Reporting;

public sealed class JsonReportWriter : IReportWriter
{
    public ReportFormat Format => ReportFormat.Json;

    public async Task WriteAsync<T>(
        IReadOnlyList<T> data,
        ReportRequest request,
        CancellationToken cancellationToken = default)
    {
        var payload = new
        {
            request.Title,
            request.Metadata,
            GeneratedAt = DateTime.Now,
            Data = data
        };

        var directory = Path.GetDirectoryName(request.OutputPath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var json = JsonSerializer.Serialize(
            payload,
            new JsonSerializerOptions
            {
                WriteIndented = true
            });

        await File.WriteAllTextAsync(
            request.OutputPath,
            json,
            cancellationToken);
    }
}