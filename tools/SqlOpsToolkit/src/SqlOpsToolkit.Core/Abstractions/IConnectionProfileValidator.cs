using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface IConnectionProfileValidator
{
    IReadOnlyList<string> Validate(ConnectionProfile profile);
}