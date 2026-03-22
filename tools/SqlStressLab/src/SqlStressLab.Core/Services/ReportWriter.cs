using System.Text;
using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class ReportWriter
{
    public static async Task WriteJsonAsync(string directory, StressSummary summary, List<ExecutionSample> samples)
    {
        Directory.CreateDirectory(directory);

        var filePath = Path.Combine(directory, $"run_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");

        var payload = new
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = summary,
            Samples = samples
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        await File.WriteAllTextAsync(filePath, json);
    }

    public static async Task WriteCsvAsync(string directory, List<ExecutionSample> samples)
    {
        Directory.CreateDirectory(directory);

        var filePath = Path.Combine(directory, $"run_{DateTime.UtcNow:yyyyMMdd_HHmmss}.csv");
        var sb = new StringBuilder();

        sb.AppendLine("WorkerId,Iteration,StartedAtUtc,DurationMs,Success,ErrorCategory,SqlErrorNumber,ScalarValue,ReaderRowCount,ErrorMessage");

        foreach (var s in samples)
        {
            sb.AppendLine(
                $"{s.WorkerId},{s.Iteration},{s.StartedAtUtc:O},{s.DurationMs},{s.Success}," +
                $"\"{Escape(s.ErrorCategory)}\",{s.SqlErrorNumber},\"{Escape(s.ScalarValue)}\",{s.ReaderRowCount},\"{Escape(s.ErrorMessage)}\"");
        }

        await File.WriteAllTextAsync(filePath, sb.ToString(), Encoding.UTF8);
    }

    public static async Task WriteReaderPreviewAsync(string directory, List<ExecutionSample> samples)
    {
        Directory.CreateDirectory(directory);

        var previews = samples
            .Where(x => !string.IsNullOrWhiteSpace(x.ReaderPreviewJson))
            .Select(x => new
            {
                x.WorkerId,
                x.Iteration,
                x.ReaderRowCount,
                x.ReaderPreviewJson
            })
            .ToList();

        if (previews.Count == 0)
            return;

        var filePath = Path.Combine(directory, $"reader_preview_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");
        var json = JsonSerializer.Serialize(previews, new JsonSerializerOptions { WriteIndented = true });

        await File.WriteAllTextAsync(filePath, json);
    }

    private static string Escape(string? input)
        => (input ?? string.Empty).Replace("\"", "\"\"");
}