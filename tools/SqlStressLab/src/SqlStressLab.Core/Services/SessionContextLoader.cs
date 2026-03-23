using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class SessionContextLoader
{
    public static async Task<SessionInfo> LoadAsync(
        SqlConnection connection,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            @@SPID AS Spid,
            HOST_NAME() AS HostName,
            APP_NAME() AS AppName,
            SUSER_SNAME() AS LoginName,
            DB_NAME() AS DatabaseName;
        """;

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (await reader.ReadAsync(cancellationToken))
        {
            return new SessionInfo
            {
                Spid = reader["Spid"] as int? ?? Convert.ToInt32(reader["Spid"]),
                HostName = reader["HostName"]?.ToString(),
                AppName = reader["AppName"]?.ToString(),
                LoginName = reader["LoginName"]?.ToString(),
                DatabaseName = reader["DatabaseName"]?.ToString()
            };
        }

        return new SessionInfo();
    }
}