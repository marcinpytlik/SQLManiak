using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class RetryPolicy
{
    public static bool ShouldRetry(SqlException ex, RetryOptions options, int currentAttempt)
    {
        if (!options.Enabled)
            return false;

        if (currentAttempt >= options.MaxRetries)
            return false;

        return options.RetryableSqlErrorNumbers.Contains(ex.Number);
    }
}