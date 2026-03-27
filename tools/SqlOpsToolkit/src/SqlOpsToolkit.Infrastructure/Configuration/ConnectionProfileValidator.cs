using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Enums;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Configuration;

public sealed class ConnectionProfileValidator : IConnectionProfileValidator
{
    public IReadOnlyList<string> Validate(ConnectionProfile profile)
    {
        var errors = new List<string>();

        if (profile is null)
        {
            errors.Add("Profil nie może być null.");
            return errors;
        }

        if (string.IsNullOrWhiteSpace(profile.Name))
            errors.Add("Pole 'Name' jest wymagane.");

        if (string.IsNullOrWhiteSpace(profile.Server))
            errors.Add("Pole 'Server' jest wymagane.");

        if (profile.Port <= 0 || profile.Port > 65535)
            errors.Add("Pole 'Port' musi być w zakresie 1-65535.");

        if (string.IsNullOrWhiteSpace(profile.Database))
            errors.Add("Pole 'Database' jest wymagane.");

        if (profile.AuthenticationMode == AuthenticationMode.Sql)
        {
            if (string.IsNullOrWhiteSpace(profile.User))
                errors.Add("Dla AuthenticationMode=Sql pole 'User' jest wymagane.");

            if (string.IsNullOrWhiteSpace(profile.Password))
                errors.Add("Dla AuthenticationMode=Sql pole 'Password' jest wymagane.");
        }

        return errors;
    }
}