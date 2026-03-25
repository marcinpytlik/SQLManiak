namespace SqlStressLab.Core.Validation;

using SqlStressLab.Core.Models;

public static class RootConfigValidator
{
    public static ValidationResult Validate(RootConfig config)
    {
        var result = new ValidationResult();

        if (string.IsNullOrWhiteSpace(config.Connection.Server))
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "CONN001",
                Path = "connection.server",
                Message = "Brak connection.server."
            });
        }

        if (string.IsNullOrWhiteSpace(config.Connection.Database))
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "CONN002",
                Path = "connection.database",
                Message = "Brak connection.database."
            });
        }

        if (string.Equals(config.Connection.Authentication, "SqlPassword", StringComparison.OrdinalIgnoreCase)
            && string.IsNullOrWhiteSpace(config.Connection.UserName))
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "CONN003",
                Path = "connection.userName",
                Message = "Dla SqlPassword wymagany jest userName."
            });
        }

        if (config.Execution.Workers <= 0)
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "EXEC001",
                Path = "execution.workers",
                Message = "Workers musi być > 0."
            });
        }

        if (config.Execution.IterationsPerWorker <= 0)
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "EXEC002",
                Path = "execution.iterationsPerWorker",
                Message = "IterationsPerWorker musi być > 0."
            });
        }

        if (!string.IsNullOrWhiteSpace(config.Execution.SessionSettingsFile)
            && !File.Exists(config.Execution.SessionSettingsFile))
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "FILE001",
                Path = "execution.sessionSettingsFile",
                Message = $"Nie znaleziono pliku: {config.Execution.SessionSettingsFile}"
            });
        }

        if (config.Lifecycle.SetupEnabled
            && !string.IsNullOrWhiteSpace(config.Lifecycle.SetupScriptFile)
            && !File.Exists(config.Lifecycle.SetupScriptFile))
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "FILE002",
                Path = "lifecycle.setupScriptFile",
                Message = $"Nie znaleziono pliku setup: {config.Lifecycle.SetupScriptFile}"
            });
        }

        if (config.Lifecycle.CleanupEnabled
            && !string.IsNullOrWhiteSpace(config.Lifecycle.CleanupScriptFile)
            && !File.Exists(config.Lifecycle.CleanupScriptFile))
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Error",
                Code = "FILE003",
                Path = "lifecycle.cleanupScriptFile",
                Message = $"Nie znaleziono pliku cleanup: {config.Lifecycle.CleanupScriptFile}"
            });
        }

        if (config.PerfCounters.Enabled && config.PerfCounters.CounterPaths.Count == 0)
        {
            result.Issues.Add(new ValidationIssue
            {
                Severity = "Warning",
                Code = "PERF001",
                Path = "perfCounters.counterPaths",
                Message = "PerfCounters są włączone, ale nie zdefiniowano żadnych counterPaths."
            });
        }

        return result;
    }
}