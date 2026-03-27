using SqlOpsToolkit.Core.Enums;

namespace SqlOpsToolkit.Core.Results;

public sealed class OperationResult
{
    public ExecutionStatus Status { get; init; }
    public string Message { get; init; } = string.Empty;

    public static OperationResult Ok(string message) =>
        new() { Status = ExecutionStatus.Success, Message = message };

    public static OperationResult Warning(string message) =>
        new() { Status = ExecutionStatus.Warning, Message = message };

    public static OperationResult Error(string message) =>
        new() { Status = ExecutionStatus.Error, Message = message };
}