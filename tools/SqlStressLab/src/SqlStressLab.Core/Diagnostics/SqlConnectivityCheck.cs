using Microsoft.Data.SqlClient;

namespace SqlStressLab.Core.Diagnostics;

public static class SqlConnectivityCheck
{
    public static async Task<bool> CheckAsync(string connectionString, CancellationToken cancellationToken = default)
    {
        await using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand("SELECT 1;", conn);
        var result = await cmd.ExecuteScalarAsync(cancellationToken);

        return Convert.ToInt32(result) == 1;
    }
}