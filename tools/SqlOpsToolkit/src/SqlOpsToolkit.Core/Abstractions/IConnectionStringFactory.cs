using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface IConnectionStringFactory
{
    string Create(ConnectionProfile profile);
}