namespace SqlStressLab.Core.Models;

public sealed class OutputOptions
{
    public bool WriteJson { get; set; } = true;
    public bool WriteCsv { get; set; } = true;
    public bool WriteReaderPreview { get; set; } = true;
    public string Directory { get; set; } = "outputs";
}