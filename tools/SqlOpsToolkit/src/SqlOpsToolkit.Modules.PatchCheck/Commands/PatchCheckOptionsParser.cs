namespace SqlOpsToolkit.Modules.PatchCheck.Commands;

public static class PatchCheckOptionsParser
{
    public static PatchCheckOptions Parse(string[] args)
    {
        var profilesFile = @".\profiles\sample-profiles.json";
        string? profileName = null;
        string? tag = null;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];

            if (string.Equals(arg, "--profiles-file", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                profilesFile = args[++i];
                continue;
            }

            if (string.Equals(arg, "--profile", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                profileName = args[++i];
                continue;
            }

            if (string.Equals(arg, "--tag", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                tag = args[++i];
                continue;
            }
        }

        return new PatchCheckOptions
        {
            ProfilesFile = profilesFile,
            ProfileName = profileName,
            Tag = tag
        };
    }
}