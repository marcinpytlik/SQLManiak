using System.Data;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface ISqlConnectionFactory
{
    IDbConnection Create(ServerProfile profile);
}