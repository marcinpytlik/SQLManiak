using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Sql;

public static class SqlVersionParser
{
    public static SqlVersionParts Parse(string? productVersion)
    {
        if (string.IsNullOrWhiteSpace(productVersion))
            return new SqlVersionParts();

        var parts = productVersion.Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (parts.Length != 4)
            return new SqlVersionParts();

        var parsed = new int?[4];

        for (var i = 0; i < 4; i++)
        {
            if (int.TryParse(parts[i], out var value))
            {
                parsed[i] = value;
            }
            else
            {
                return new SqlVersionParts();
            }
        }

        return new SqlVersionParts
        {
            Major = parsed[0],
            Minor = parsed[1],
            Build = parsed[2],
            Revision = parsed[3]
        };
    }
}