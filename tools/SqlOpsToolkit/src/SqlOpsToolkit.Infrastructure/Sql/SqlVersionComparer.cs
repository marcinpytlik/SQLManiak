using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Sql;

public static class SqlVersionComparer
{
    public static int Compare(string? leftVersion, string? rightVersion)
    {
        var left = SqlVersionParser.Parse(leftVersion);
        var right = SqlVersionParser.Parse(rightVersion);

        return Compare(left, right);
    }

    public static int Compare(SqlVersionParts left, SqlVersionParts right)
    {
        var leftParts = new[] { left.Major ?? -1, left.Minor ?? -1, left.Build ?? -1, left.Revision ?? -1 };
        var rightParts = new[] { right.Major ?? -1, right.Minor ?? -1, right.Build ?? -1, right.Revision ?? -1 };

        for (var i = 0; i < 4; i++)
        {
            if (leftParts[i] < rightParts[i]) return -1;
            if (leftParts[i] > rightParts[i]) return 1;
        }

        return 0;
    }
}