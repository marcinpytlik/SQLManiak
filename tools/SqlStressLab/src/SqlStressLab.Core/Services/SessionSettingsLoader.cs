using System.Text;

namespace SqlStressLab.Core.Services;

public static class SessionSettingsLoader
{
    public static IReadOnlyList<string> LoadStatements(string? filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath))
            return Array.Empty<string>();

        if (!File.Exists(filePath))
            throw new FileNotFoundException($"Nie znaleziono pliku ustawień sesji: {filePath}");

        var lines = File.ReadAllLines(filePath);
        var builder = new StringBuilder();
        var statements = new List<string>();

        foreach (var raw in lines)
        {
            var line = raw.Trim();

            if (string.IsNullOrWhiteSpace(line))
                continue;

            if (line.StartsWith("--"))
                continue;

            builder.AppendLine(line);

            if (line.EndsWith(";"))
            {
                var stmt = builder.ToString().Trim();
                if (!string.IsNullOrWhiteSpace(stmt))
                {
                    statements.Add(stmt);
                }

                builder.Clear();
            }
        }

        var rest = builder.ToString().Trim();
        if (!string.IsNullOrWhiteSpace(rest))
        {
            statements.Add(rest);
        }

        return statements;
    }
}