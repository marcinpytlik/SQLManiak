using System.Globalization;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class ParameterValueFactory
{
    public static SqlParameter Create(SqlParameterDefinition definition, int workerId, int iteration)
    {
        var parameterName = definition.Name.StartsWith("@", StringComparison.Ordinal)
            ? definition.Name
            : "@" + definition.Name;

        object? value = ResolveValue(definition, workerId, iteration);

        return new SqlParameter(parameterName, value ?? DBNull.Value);
    }

    public static object? ResolveValue(SqlParameterDefinition definition, int workerId, int iteration)
    {
        var mode = definition.Mode?.Trim().ToLowerInvariant() ?? "fixed";

        return mode switch
        {
            "fixed" => ConvertValue(definition.Type, definition.Value),

            "workerid" => ConvertValue(definition.Type, workerId.ToString(CultureInfo.InvariantCulture)),

            "iteration" => ConvertValue(definition.Type, iteration.ToString(CultureInfo.InvariantCulture)),

            "randomintrange" => Random.Shared.Next(
                int.Parse(definition.Min ?? "1", CultureInfo.InvariantCulture),
                int.Parse(definition.Max ?? "100", CultureInfo.InvariantCulture) + 1),

            "sequence" => ConvertValue(
                definition.Type,
                (
                    int.Parse(definition.Start ?? "1", CultureInfo.InvariantCulture) +
                    ((iteration - 1) * int.Parse(definition.Increment ?? "1", CultureInfo.InvariantCulture))
                ).ToString(CultureInfo.InvariantCulture)),

            "randomguid" => Guid.NewGuid(),

            _ => throw new InvalidOperationException($"Nieznany parameter mode: {definition.Mode}")
        };
    }

    private static object? ConvertValue(string type, string? value)
    {
        if (value is null)
            return null;

        return type.Trim().ToUpperInvariant() switch
        {
            "INT" => int.Parse(value, CultureInfo.InvariantCulture),
            "BIGINT" => long.Parse(value, CultureInfo.InvariantCulture),
            "BIT" => bool.Parse(value),
            "DECIMAL" => decimal.Parse(value, CultureInfo.InvariantCulture),
            "NUMERIC" => decimal.Parse(value, CultureInfo.InvariantCulture),
            "FLOAT" => double.Parse(value, CultureInfo.InvariantCulture),
            "UNIQUEIDENTIFIER" => Guid.Parse(value),
            "DATETIME" => DateTime.Parse(value, CultureInfo.InvariantCulture),
            "DATETIME2" => DateTime.Parse(value, CultureInfo.InvariantCulture),
            "NVARCHAR" => value,
            "VARCHAR" => value,
            "NCHAR" => value,
            "CHAR" => value,
            "TEXT" => value,
            "NTEXT" => value,
            "STRING" => value,
            _ => value
        };
    }
}