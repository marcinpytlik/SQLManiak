namespace SqlStressLab.Core.Validation;

public sealed class ValidationIssue
{
    public string Severity { get; set; } = "Error"; // Error / Warning / Info
    public string Code { get; set; } = "";
    public string Message { get; set; } = "";
    public string? Path { get; set; }
}