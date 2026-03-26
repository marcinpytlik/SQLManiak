using System;
using System.Data;
using Microsoft.Data.SqlClient;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Connection;

public sealed class SqlConnectionFactory : ISqlConnectionFactory
{
    public IDbConnection Create(ServerProfile profile)
    {
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = profile.Server,
            InitialCatalog = profile.Database,
            Encrypt = profile.Encrypt,
            TrustServerCertificate = profile.TrustServerCertificate,
            ConnectTimeout = profile.ConnectTimeoutSeconds
        };

        if (string.Equals(profile.Authentication, "Windows", StringComparison.OrdinalIgnoreCase))
        {
            builder.IntegratedSecurity = true;
        }
        else
        {
            builder.IntegratedSecurity = false;
            builder.UserID = profile.UserName;
            builder.Password = profile.Password;
        }

        return new SqlConnection(builder.ConnectionString);
    }
}