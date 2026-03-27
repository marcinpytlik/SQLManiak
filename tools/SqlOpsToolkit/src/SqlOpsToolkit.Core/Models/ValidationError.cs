namespace SqlOpsToolkit.Core.Models;

public sealed class ValidationError
{
    public string Code { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;
}