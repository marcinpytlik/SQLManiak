using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class ConnectionStringFactory
{
    public static string Build(SqlAuthOptions options)
    {
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = options.Server,
            InitialCatalog = options.Database,
            Encrypt = options.Encrypt,
            TrustServerCertificate = options.TrustServerCertificate,
            ApplicationName = options.ApplicationName,
            MultipleActiveResultSets = false,
            ConnectTimeout = 15
        };

        if (string.Equals(options.Authentication, "Integrated", StringComparison.OrdinalIgnoreCase))
        {
            builder.IntegratedSecurity = true;
        }
        else
        {
            builder.IntegratedSecurity = false;
            builder.UserID = options.UserName ?? throw new InvalidOperationException("Brak UserName.");
            builder.Password = options.Password ?? throw new InvalidOperationException("Brak Password.");
        }

        return builder.ConnectionString;
    }
}