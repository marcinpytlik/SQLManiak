using Microsoft.Data.SqlClient;
using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Enums;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Sql;

public sealed class SqlConnectionStringFactory : IConnectionStringFactory
{
    public string Create(ConnectionProfile profile)
    {
        ArgumentNullException.ThrowIfNull(profile);

        var builder = new SqlConnectionStringBuilder
        {
            DataSource = $"{profile.Server},{profile.Port}",
            InitialCatalog = profile.Database,
            Encrypt = profile.Encrypt,
            TrustServerCertificate = profile.TrustServerCertificate,
            ConnectTimeout = 5
        };

        if (profile.AuthenticationMode == AuthenticationMode.Windows)
        {
            builder.IntegratedSecurity = true;
        }
        else
        {
            builder.IntegratedSecurity = false;
            builder.UserID = profile.User;
            builder.Password = profile.Password;
        }

        return builder.ConnectionString;
    }
}