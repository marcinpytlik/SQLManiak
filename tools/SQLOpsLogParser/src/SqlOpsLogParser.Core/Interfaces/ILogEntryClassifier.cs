using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface ILogEntryClassifier
{
    void Classify(SqlLogEntry entry);
}