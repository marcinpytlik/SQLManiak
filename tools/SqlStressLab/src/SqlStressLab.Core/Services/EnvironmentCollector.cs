using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class EnvironmentCollector
{
    public static EnvironmentInfo Collect(EnvironmentInfo baseInfo)
    {
        return new EnvironmentInfo
        {
            EnvironmentName = baseInfo.EnvironmentName,
            MachineName = Environment.MachineName,
            UserName = Environment.UserName,
            OsVersion = Environment.OSVersion.ToString(),
            DotNetVersion = Environment.Version.ToString(),
            ApplicationName = baseInfo.ApplicationName
        };
    }
}