namespace SqlStressLab.Core.Models;

public sealed class RunArtifactInfo
{
    public string? JsonPath { get; set; }
    public string? CsvPath { get; set; }
    public string? MarkdownPath { get; set; }
    public string? HtmlPath { get; set; }
}