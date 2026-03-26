using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IProfileProvider
{
    IReadOnlyList<ServerProfile> GetAll();
    ServerProfile? GetByName(string name);
}