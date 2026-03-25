namespace SqlStressLab.Core.Models;

public static class ExitCode
{
    public const int Success = 0;
    public const int ValidationError = 2;
    public const int SelfCheckFailed = 3;
    public const int RunFailed = 4;
    public const int Cancelled = 10;
    public const int UnexpectedError = 99;
}