namespace SqlOpsToolkit.Core.Abstractions;

public interface IToolModule
{
    string Name { get; }
    Task<int> ExecuteAsync(string[] args, CancellationToken cancellationToken = default);
}