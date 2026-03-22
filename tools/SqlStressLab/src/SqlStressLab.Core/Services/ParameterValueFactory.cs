using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class ParameterValueFactory
{
    public static SqlParameter Create(SqlParameterDefinition definition, int workerId, int iteration)
    {
        object value = definition.Mode switch
        {
            "Fixed" => ParseValue(definition.Type, definition.Value),
            "Sequence" => ParseSequence(definition.Type, iteration),
            "RandomIntRange" => Random.Shared.Next(definition.Min ?? 1, (definition.Max ?? 100) + 1),
            "RandomGuid" => Guid.NewGuid(),
            _ => throw new InvalidOperationException($"Nieobsługiwany tryb parametru: {definition.Mode}")
        };

        return new SqlParameter(definition.Name, value ?? DBNull.Value);
    }

    private static object ParseSequence(string type, int iteration)
    {
        return type.ToUpperInvariant() switch
        {
            "INT" => iteration,
            "BIGINT" => (long)iteration,
            "STRING" => iteration.ToString(),
            _ => iteration
        };
    }

    private static object ParseValue(string type, string? value)
    {
        return type.ToUpperInvariant() switch
        {
            "INT" => int.Parse(value ?? "0"),
            "BIGINT" => long.Parse(value ?? "0"),
            "UNIQUEIDENTIFIER" => Guid.Parse(value ?? Guid.Empty.ToString()),
            "BIT" => bool.Parse(value ?? "false"),
            "DATETIME" => DateTime.Parse(value ?? DateTime.UtcNow.ToString("O")),
            _ => value ?? string.Empty
        };
    }
}