using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Services;

public sealed class LogEntryClassifier : ILogEntryClassifier
{
    public void Classify(SqlLogEntry entry)
    {
        var text = entry.Text ?? string.Empty;
        var processInfo = entry.ProcessInfo ?? string.Empty;

        var combined = $"{processInfo} {text}".ToLowerInvariant();

        entry.Severity = ClassifySeverity(combined);
        entry.Category = ClassifyCategory(combined);
    }

    private static EventSeverity ClassifySeverity(string text)
    {
        if (ContainsAny(text,
                "stack dump",
                "corruption",
                "suspect pages",
                "fatal",
                "i/o requests taking longer",
                "operating system error"))
        {
            return EventSeverity.Critical;
        }

        if (ContainsAny(text,
                "error:",
                "severity:",
                "login failed",
                "failed",
                "could not",
                "cannot",
                "denied",
                "exception"))
        {
            return EventSeverity.Error;
        }

        if (ContainsAny(text,
                "warning",
                "taking longer than",
                "autogrow",
                "retry",
                "may need to"))
        {
            return EventSeverity.Warning;
        }

        return EventSeverity.Info;
    }

    private static EventCategory ClassifyCategory(string text)
    {
        if (ContainsAny(text, "login failed", "login", "authentication", "security"))
        {
            return EventCategory.Security;
        }

        if (ContainsAny(text, "backup", "backed up", "backup database"))
        {
            return EventCategory.Backup;
        }

        if (ContainsAny(text, "restore", "restoring", "recovered"))
        {
            return EventCategory.Restore;
        }

        if (ContainsAny(text, "recovery", "recovering", "redo", "undo"))
        {
            return EventCategory.Recovery;
        }

        if (ContainsAny(text, "always on", "availability replica", "availability group"))
        {
            return EventCategory.Availability;
        }

        if (ContainsAny(text, "i/o", "operating system error", "823", "824", "825"))
        {
            return EventCategory.IO;
        }

        if (ContainsAny(text, "memory", "resource monitor", "insufficient system memory"))
        {
            return EventCategory.Memory;
        }

        if (ContainsAny(text, "deadlock"))
        {
            return EventCategory.Deadlock;
        }

        if (ContainsAny(text, "sqlagent", "agent"))
        {
            return EventCategory.Agent;
        }

        if (ContainsAny(text, "terminating because of a system shutdown", "shutting down", "shutdown"))
        {
            return EventCategory.Shutdown;
        }

        if (ContainsAny(text, "starting up database", "sql server is starting", "server process id"))
        {
            return EventCategory.Startup;
        }

        if (ContainsAny(text, "sql trace"))
        {
            return EventCategory.Trace;
        }

        if (ContainsAny(text, "xe session", "extended events"))
        {
            return EventCategory.ExtendedEvents;
        }

        if (ContainsAny(text, "corruption", "suspect pages", "dbcc checkdb"))
        {
            return EventCategory.Corruption;
        }

        return EventCategory.General;
    }

    private static bool ContainsAny(string text, params string[] patterns)
    {
        foreach (var pattern in patterns)
        {
            if (text.Contains(pattern, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }
}