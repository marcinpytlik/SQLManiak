namespace SqlStressLab.Core.Cli;

public static class ArgumentReader
{
    public static ParsedCommand Parse(string[] args)
    {
        if (args.Length == 0)
            throw new InvalidOperationException("Brak komendy.");

        var parsed = new ParsedCommand
        {
            CommandName = args[0]
        };

        for (int i = 1; i < args.Length; i++)
        {
            var arg = args[i];

            if (arg.StartsWith("--"))
            {
                var key = arg[2..];

                if (i + 1 < args.Length && !args[i + 1].StartsWith("--"))
                {
                    parsed.Options[key] = args[i + 1];
                    i++;
                }
                else
                {
                    parsed.Flags.Add(key);
                }
            }
        }

        return parsed;
    }
}