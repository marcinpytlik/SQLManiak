using System.Text;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Reporting;

public sealed class MarkdownReportWriter : IReportWriter
{
    public ReportFormat Format => ReportFormat.Markdown;

    public async Task WriteAsync<T>(
        IReadOnlyList<T> data,
        ReportRequest request,
        CancellationToken cancellationToken = default)
    {
        var sb = new StringBuilder();

        sb.AppendLine($"# {request.Title}");
        sb.AppendLine();

        if (request.Metadata.Count > 0)
        {
            sb.AppendLine("## Metadata");
            sb.AppendLine();

            foreach (var item in request.Metadata)
            {
                sb.AppendLine($"- **{item.Key}**: {item.Value}");
            }

            sb.AppendLine();
        }

        sb.AppendLine("## Data");
        sb.AppendLine();

        if (data.Count == 0)
        {
            sb.AppendLine("_No data_");
        }
        else
        {
            var properties = typeof(T).GetProperties();

            sb.Append("| ");
            sb.Append(string.Join(" | ", properties.Select(p => p.Name)));
            sb.AppendLine(" |");

            sb.Append("| ");
            sb.Append(string.Join(" | ", properties.Select(_ => "---")));
            sb.AppendLine(" |");

            foreach (var row in data)
            {
                var values = properties
                    .Select(p => FormatMarkdownValue(p.GetValue(row)));

                sb.Append("| ");
                sb.Append(string.Join(" | ", values));
                sb.AppendLine(" |");
            }
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

    private static string FormatMarkdownValue(object? value)
    {
        if (value is null)
        {
            return string.Empty;
        }

        return value.ToString()?
            .Replace("\r", " ")
            .Replace("\n", " ")
            .Replace("|", "\\|") ?? string.Empty;
    }
}