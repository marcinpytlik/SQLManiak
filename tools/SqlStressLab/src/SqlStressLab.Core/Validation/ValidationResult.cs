namespace SqlStressLab.Core.Validation;

public sealed class ValidationResult
{
    public List<ValidationIssue> Issues { get; set; } = new();

    public bool HasErrors => Issues.Any(x => x.Severity == "Error");
    public bool HasWarnings => Issues.Any(x => x.Severity == "Warning");
}